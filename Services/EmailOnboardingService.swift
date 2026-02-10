// EmailOnboardingService.swift
// Handles Gmail OAuth2 authentication and email scraping for auto-wardrobe population

import Foundation
import SwiftUI
import GoogleSignIn
internal import Combine

// MARK: - Service

class EmailOnboardingService: ObservableObject {
    static let shared = EmailOnboardingService()
    
    @Published var isProcessing = false
    @Published var progress: ImportProgress?
    @Published var error: EmailError?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Import wardrobe items from Gmail order confirmations
    func importFromGmail(timeRange: TimeRange, userTier: GenerationTier) async throws -> [ClothingItem] {
        // Validate tier access
        guard canAccessTimeRange(timeRange, tier: userTier) else {
            throw EmailError.tierRestriction
        }
        
        await MainActor.run {
            isProcessing = true
            progress = ImportProgress(phase: .authenticating, totalEmails: 0, processedEmails: 0)
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        do {
            // Step 1: OAuth2 authentication
            let token = try await requestGmailAccess()
            
            // Step 2: Search for order emails
            await updateProgress(.searching)
            let emails = try await searchOrderEmails(token: token, range: timeRange)
            
            await MainActor.run {
                progress?.totalEmails = emails.count
            }
            
            // Step 3: Parse emails and extract products
            await updateProgress(.parsing)
            let products = try await parseEmails(emails, token: token)
            
            // Step 4: Download images and create ClothingItems
            await updateProgress(.downloading)
            let items = try await createClothingItems(from: products)
            
            // Step 5: Revoke token
            try await revokeGmailToken(token)
            
            await updateProgress(.complete)
            
            return items
            
        } catch {
            await MainActor.run {
                self.error = error as? EmailError ?? .unknown(error)
            }
            throw error
        }
    }
    
    // MARK: - Tier Validation
    
    func canAccessTimeRange(_ range: TimeRange, tier: GenerationTier) -> Bool {
        switch (range, tier) {
        case (.sixMonths, _):
            return true // Free tier can access 6 months
        case (.twoYears, .premium), (.custom, .premium):
            return true // Premium tier can access extended ranges
        case (.twoYears, .free), (.custom, .free):
            return false // Free tier cannot access premium ranges
        }
    }
    
    // MARK: - Gmail OAuth2
    
    private func requestGmailAccess() async throws -> GmailToken {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
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
    }
    
    private func revokeGmailToken(_ token: GmailToken) async throws {
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
    
    // MARK: - Email Search
    
    private func searchOrderEmails(token: GmailToken, range: TimeRange) async throws -> [GmailMessage] {
        let query = buildGmailQuery(for: range)
        
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
            }
        }
        
        let searchResult = try JSONDecoder().decode(SearchResponse.self, from: searchData)
        guard let messageRefs = searchResult.messages else {
            print("📧 No emails found matching query")
            return [] // No messages found
        }
        
        print("📧 Found \(messageRefs.count) emails matching order confirmations")
        
        // Step 2: Fetch full message details for each ID
        var messages: [GmailMessage] = []
        
        for messageRef in messageRefs {
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
    
    private func buildGmailQuery(for range: TimeRange) -> String {
        let subjectFilter = "subject:(\"order shipped\" OR \"order delivered\" OR \"delivery confirmation\")"
        let timeFilter = range.gmailTimeFilter
        
        return "\(subjectFilter) \(timeFilter)"
    }
    
    // MARK: - Email Parsing
    
    private func parseEmails(_ emails: [GmailMessage], token: GmailToken) async throws -> [ProductData] {
        var allProducts: [ProductData] = []
        
        for (index, email) in emails.enumerated() {
            await MainActor.run {
                progress?.processedEmails = index + 1
            }
            
            // Get full email content
            // TODO: GET /gmail/v1/users/me/messages/{id}?format=full
            
            // Identify retailer from sender
            let parser = selectParser(for: email)
            
            // Extract products
            if let products = try? await parser.extractProducts(from: email) {
                allProducts.append(contentsOf: products)
            }
        }
        
        return allProducts
    }
    
    private func selectParser(for email: GmailMessage) -> EmailParser {
        // TODO: Implement retailer detection
        // For now, use generic parser
        return GenericEmailParser()
    }
    
    // MARK: - ClothingItem Creation
    
    private func createClothingItems(from products: [ProductData]) async throws -> [ClothingItem] {
        var items: [ClothingItem] = []
        
        for product in products {
            // Download product image
            guard let imageData = try? await downloadImage(from: product.imageURL) else {
                continue
            }
            
            // Convert Data to UIImage
            guard let uiImage = UIImage(data: imageData) else {
                continue
            }
            
            // Save image
            let imageID = UUID()
            ImageStorageService.shared.saveImage(uiImage, withID: imageID)
            
            // Create ClothingItem
            let item = ClothingItem(
                name: product.name,
                brand: product.brand,
                size: product.size,
                imageID: imageID,
                tags: product.tags
            )
            
            // TODO: Set category based on product.category
            
            items.append(item)
        }
        
        return items
    }
    
    private func downloadImage(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // MARK: - Progress Updates
    
    @MainActor
    private func updateProgress(_ phase: ImportPhase) {
        progress?.phase = phase
    }
}

// MARK: - Supporting Types

enum TimeRange: Equatable {
    case sixMonths   // Free tier
    case twoYears    // Premium
    case custom(Date) // Premium+
    
    var gmailTimeFilter: String {
        switch self {
        case .sixMonths:
            return "newer_than:6m"
        case .twoYears:
            return "newer_than:2y"
        case .custom(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return "after:\(formatter.string(from: date))"
        }
    }
    
    var displayName: String {
        switch self {
        case .sixMonths:
            return "Last 6 months"
        case .twoYears:
            return "Last 2 years"
        case .custom(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Since \(formatter.string(from: date))"
        }
    }
    
    var isPremium: Bool {
        switch self {
        case .sixMonths:
            return false
        case .twoYears, .custom:
            return true
        }
    }
}

struct ImportProgress {
    var phase: ImportPhase
    var totalEmails: Int
    var processedEmails: Int
    
    var percentComplete: Double {
        guard totalEmails > 0 else { return 0 }
        return Double(processedEmails) / Double(totalEmails)
    }
}

enum ImportPhase {
    case authenticating
    case searching
    case parsing
    case downloading
    case complete
    
    var displayText: String {
        switch self {
        case .authenticating:
            return "Connecting to Gmail..."
        case .searching:
            return "Searching for order emails..."
        case .parsing:
            return "Extracting products..."
        case .downloading:
            return "Downloading images..."
        case .complete:
            return "Complete!"
        }
    }
}

enum EmailError: LocalizedError {
    case tierRestriction
    case authenticationFailed
    case apiError(String)
    case parsingFailed
    case notImplemented
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .tierRestriction:
            return "This time range requires Premium. Upgrade to import from the last 2 years!"
        case .authenticationFailed:
            return "Failed to connect to Gmail. Please try again."
        case .apiError(let message):
            return "Gmail API error: \(message)"
        case .parsingFailed:
            return "Failed to extract products from emails"
        case .notImplemented:
            return "This feature is under development"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Gmail Types (Placeholders)

struct GmailToken {
    let accessToken: String
    let expiresAt: Date
}

struct GmailMessage {
    let id: String
    let from: String
    let subject: String
    let date: Date
    let htmlBody: String?
}

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

// MARK: - Parser Protocol

protocol EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData]
}

struct ProductData {
    let name: String
    let imageURL: URL
    let brand: String?
    let size: String?
    let color: String?
    let category: String?
    let tags: [String]
}

// MARK: - Generic Parser (Fallback)

class GenericEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        // TODO: Implement generic HTML parsing
        // Look for common patterns: <img> tags, product links, etc.
        return []
    }
}
