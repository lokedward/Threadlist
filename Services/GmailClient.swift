// GmailClient.swift
// Encapsulates Gmail API interactions and OAuth2 authentication

import Foundation
import GoogleSignIn
import UIKit

// MARK: - Gmail Types

// MARK: - Gmail Types
// GmailToken and GmailMessage are defined in EmailTypes.swift

// MARK: - Gmail API Response Types

struct GmailMessageResponse: Codable {
    let id: String
    let payload: Payload
    let internalDate: String?
    
    struct Payload: Codable {
        let headers: [Header]
        let body: Body?
        let parts: [Part]?
    }
    
    struct Header: Codable {
        let name: String
        let value: String
    }
    
    struct Body: Codable {
        let data: String?
    }
    
    struct Part: Codable {
        let mimeType: String?
        let body: Body?
        let parts: [Part]?
    }
}

class GmailClient {
    static let shared = GmailClient()
    private init() {}
    
    // MARK: - Authentication
    
    @MainActor
    func requestGmailAccess() async throws -> GmailToken {
        return try await withCheckedThrowingContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                continuation.resume(throwing: EmailError.authenticationFailed)
                return
            }
            
            // Gmail read-only scope
            let scopes = ["https://www.googleapis.com/auth/gmail.readonly"]
            
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            ) { result, error in
                if let error = error {
                    print("Google Sign-In error: \(error.localizedDescription)")
                    continuation.resume(throwing: EmailError.authenticationFailed)
                    return
                }
                
                guard let user = result?.user else {
                    continuation.resume(throwing: EmailError.authenticationFailed)
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                
                let token = GmailToken(
                    accessToken: accessToken,
                    expiresAt: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                )
                
                continuation.resume(returning: token)
            }
        }
    }
    
    func revokeGmailToken(_ token: GmailToken) async throws {
        // Sign out from Google Sign-In
        await MainActor.run {
            GIDSignIn.sharedInstance.signOut()
        }
        
        // Also revoke server-side
        let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke?token=\(token.accessToken)")!
        var request = URLRequest(url: revokeURL)
        request.httpMethod = "POST"
        
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - API Calls
    
    func searchOrderEmails(token: GmailToken, query: String) async throws -> [GmailMessage] {
        // Step 1: Search for message IDs
        let searchURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&maxResults=50")!
        var searchRequest = URLRequest(url: searchURL)
        searchRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (searchData, searchResponse) = try await URLSession.shared.data(for: searchRequest)
        
        guard let httpResponse = searchResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmailError.apiError("Failed to search emails")
        }
        
        struct SearchResponse: Codable {
            let messages: [MessageRef]?
            struct MessageRef: Codable {
                let id: String
                let threadId: String
            }
        }
        
        let searchResult = try JSONDecoder().decode(SearchResponse.self, from: searchData)
        guard let messageRefs = searchResult.messages else {
            print("📧 No emails found matching query")
            return [] // No messages found
        }
        
        // Deduplicate by threadId to avoid parsing the same order twice
        var uniqueThreadIds = Set<String>()
        var deduplicatedRefs: [SearchResponse.MessageRef] = []
        for ref in messageRefs {
            if !uniqueThreadIds.contains(ref.threadId) {
                uniqueThreadIds.insert(ref.threadId)
                deduplicatedRefs.append(ref)
            }
        }
        
        print("✅ Found \(deduplicatedRefs.count) unique email thread(s) matching query")
        print("📧 Found \(deduplicatedRefs.count) emails matching order confirmations")
        
        // Step 2: Fetch full message details for each ID
        var messages: [GmailMessage] = []
        
        for messageRef in deduplicatedRefs {
            if let message = try? await fetchMessage(id: messageRef.id, token: token) {
                messages.append(message)
                print("📧 Fetched email from: \(message.from), subject: \(message.subject)")
            }
        }
        
        return messages
    }
    
    private func fetchMessage(id: String, token: GmailToken) async throws -> GmailMessage {
        let messageURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
        var messageRequest = URLRequest(url: messageURL)
        messageRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (messageData, _) = try await URLSession.shared.data(for: messageRequest)
        
        let response = try JSONDecoder().decode(GmailMessageResponse.self, from: messageData)
        
        // Extract headers
        let headers = response.payload.headers
        let from = headers.first { $0.name.lowercased() == "from" }?.value ?? "unknown"
        let subject = headers.first { $0.name.lowercased() == "subject" }?.value ?? "No Subject"
        
        // Parse date
        let date: Date
        if let internalDate = response.internalDate, let timestamp = TimeInterval(internalDate) {
            date = Date(timeIntervalSince1970: timestamp / 1000)
        } else {
            date = Date()
        }
        
        // Extract HTML body
        let htmlBody = extractHTMLBody(from: response.payload)
        
        return GmailMessage(
            id: response.id,
            from: from,
            subject: subject,
            date: date,
            htmlBody: htmlBody
        )
    }
    
    private func extractHTMLBody(from payload: GmailMessageResponse.Payload) -> String? {
        // Check body directly
        if let bodyData = payload.body?.data {
            return decodeBase64URL(bodyData)
        }
        
        // Check parts for HTML
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/html", let bodyData = part.body?.data {
                    return decodeBase64URL(bodyData)
                }
                // Recursively check nested parts
                if let nestedParts = part.parts {
                    let nestedPayload = GmailMessageResponse.Payload(headers: [], body: nil, parts: nestedParts)
                    if let html = extractHTMLBody(from: nestedPayload) {
                        return html
                    }
                }
            }
        }
        
        return nil
    }
    
    private func decodeBase64URL(_ string: String) -> String? {
        // Gmail uses URL-safe base64 encoding
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}
