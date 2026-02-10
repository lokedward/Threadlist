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
    /// Returns parsed products for user review (doesn't create ClothingItems yet)
    func importFromGmail(timeRange: TimeRange, userTier: GenerationTier) async throws -> [EmailProductItem] {
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
            // Step 1: Authenticate with Gmail
            let token = try await requestGmailAccess()
            
            // Step 2: Search for order confirmation emails
            await updateProgress(.searching)
            let emails = try await searchOrderEmails(token: token, range: timeRange)
            
            // Step 3: Parse emails and extract products
            await updateProgress(.parsing, totalEmails: emails.count)
            let products = try await parseEmails(emails)
            
            // Step 4: Convert to EmailProductItem for review
            let items = products.map { product in
                EmailProductItem(
                    name: product.name,
                    imageURL: product.imageURL,
                    brand: product.brand,
                    size: product.size,
                    color: product.color
                )
            }
            
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
        
        print("✅ Found \(messageRefs.count) email(s) matching query")
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
        // Broad query to catch order confirmations in various formats
        // Including forwarded emails which may have different subject patterns
        let timeFilter = range.gmailTimeFilter
        
        // Search for common order-related keywords in subject
        // Much broader than before to catch forwarded emails and various retailers
        let query = """
        subject:(order OR shipped OR delivered OR delivery OR shipment OR confirmation OR receipt OR invoice OR "thank you for your purchase")
        \(timeFilter)
        """
        
        print("📧 Gmail Query: \(query)")
        return query
    }
    
    // MARK: - Email Parsing
    
    private func parseEmails(_ emails: [GmailMessage], token: GmailToken) async throws -> [ProductData] {
        var allProducts: [ProductData] = []
        
        for (index, email) in emails.enumerated() {
            // Determine retailer for progress message
            let retailer = detectRetailer(from: email.from)
            
            await MainActor.run {
                progress?.processedEmails = index + 1
                progress?.currentRetailer = retailer
                progress?.detailMessage = "Processing \(retailer) order (\(index + 1) of \(emails.count))..."
            }
            
            // Select parser based on sender
            let parser = selectParser(for: email)
            
            // Extract products
            if let products = try? await parser.extractProducts(from: email) {
                allProducts.append(contentsOf: products)
                
                // Update found items count
                await MainActor.run {
                    progress?.foundItems = allProducts.count
                    if !products.isEmpty {
                        progress?.detailMessage = "Found \(products.count) item\(products.count == 1 ? "" : "s") from \(retailer)"
                    }
                }
                
                // Small delay so user can see the update
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
        }
        
        return allProducts
    }
    
    private func detectRetailer(from email: String) -> String {
        let lowercased = email.lowercased()
        
        if lowercased.contains("amazon") { return "Amazon" }
        if lowercased.contains("nike") { return "Nike" }
        if lowercased.contains("zara") { return "Zara" }
        if lowercased.contains("nordstrom") { return "Nordstrom" }
        if lowercased.contains("macys") { return "Macy's" }
        if lowercased.contains("target") { return "Target" }
        
        return "online store"
    }
    
    private func selectParser(for email: GmailMessage) -> EmailParser {
        let from = email.from.lowercased()
        
        // Detect retailer from sender
        if from.contains("amazon") {
            return AmazonEmailParser()
        } else if from.contains("nike") {
            return NikeEmailParser()
        } else if from.contains("zara") {
            return ZaraEmailParser()
        } else {
            // Generic parser for unknown retailers
            return GenericEmailParser()
        }
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
    var foundItems: Int = 0
    var currentRetailer: String?
    var detailMessage: String?
    
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

// MARK: - Clothing Detection Helper

class ClothingDetector {
    static let clothingKeywords: Set<String> = [
        // Tops
        "shirt", "t-shirt", "tshirt", "tee", "polo", "blouse", "top", "tank", "camisole", "halter",
        "sweater", "pullover", "tunic", "henley", "jersey", "cardigan", "vest", "waistcoat",
        
        // Activewear Tops
        "hoodie", "sweatshirt", "tracksuit", "windbreaker", "fleece", "athletic top",
        
        // Bottoms
        "pants", "jeans", "trousers", "slacks", "chinos", "khakis", "joggers",
        "shorts", "skirt", "leggings", "tights", "capris", "culottes",
        
        // Dresses & Jumpsuits
        "dress", "gown", "sundress", "maxi", "midi", "mini dress", "cocktail dress",
        "jumpsuit", "romper", "playsuit", "overall", "dungaree",
        
        // Outerwear
        "jacket", "coat", "blazer", "parka", "puffer", "bomber", "trench",
        "raincoat", "peacoat", "overcoat", "anorak", "gilet", "poncho", "cape",
        
        // Suits & Formal
        "suit", "tuxedo", "tux", "suit jacket", "suit pants", "dress pants",
        "dress shirt", "bow tie", "cummerbund",
        
        // Shoes
        "shoes", "sneakers", "trainers", "boots", "sandals", "heels", "pumps",
        "loafers", "oxfords", "brogues", "flats", "slides", "flip-flops",
        "slippers", "clogs", "mules", "espadrilles", "wedges", "platforms",
        "ankle boots", "knee boots", "chelsea boots", "combat boots",
        
        // Activewear & Sports
        "athletic", "workout", "gym", "running", "yoga pants", "sports bra",
        "compression", "base layer", "performance", "moisture-wicking",
        
        // Intimates & Loungewear
        "underwear", "boxers", "briefs", "bra", "lingerie", "sleepwear",
        "pajamas", "pyjamas", "nightgown", "robe", "bathrobe", "loungewear",
        
        // Accessories
        "hat", "cap", "beanie", "fedora", "baseball cap", "snapback",
        "scarf", "belt", "tie", "necktie", "gloves", "mittens",
        "socks", "stockings", "hosiery", "bag", "purse", "wallet",
        "watch", "sunglasses", "eyewear", "jewelry", "bracelet", "necklace",
        
        // Materials & Descriptors (strong indicators)
        "denim", "leather", "suede", "cashmere", "wool", "cotton",
        "silk", "velvet", "linen", "chambray", "corduroy"
    ]
    
    static let clothingBrands: Set<String> = [
        // Athletic
        "nike", "adidas", "puma", "under armour", "reebok", "new balance",
        "asics", "saucony", "brooks", "hoka", "on running",
        
        // Fast Fashion
        "zara", "h&m", "hm", "uniqlo", "gap", "old navy", "forever 21",
        "asos", "shein", "fashion nova",
        
        // Department Stores
        "nordstrom", "macy's", "macys", "bloomingdale's", "saks",
        "neiman marcus", "barneys",
        
        // Premium/Designer
        "gucci", "prada", "versace", "burberry", "ralph lauren", "polo",
        "calvin klein", "tommy hilfiger", "lacoste", "hugo boss",
        "michael kors", "kate spade", "coach",
        
        // Denim
        "levi's", "levis", "wrangler", "lee", "diesel", "true religion",
        "7 for all mankind", "ag jeans",
        
        // Outdoor
        "patagonia", "north face", "columbia", "arc'teryx", "rei",
        
        // Streetwear
        "supreme", "off-white", "bape", "stussy", "palace",
        
        // Contemporary
        "allbirds", "everlane", "reformation", "madewell", "j.crew"
    ]
    
    static let blacklistPatterns: Set<String> = [
        // Items that contain clothing keywords but aren't clothing
        "pillow case", "pillowcase", "phone case", "laptop case",
        "shirt hanger", "dress form", "shoe rack", "hat box",
        "belt buckle", "tie clip", "watch band", "bag charm",
        "clothing rack", "garment bag", "shoe cleaner", "fabric softener"
    ]
    
    static func isClothingItem(_ productName: String) -> Bool {
        let lowercased = productName.lowercased()
        
        // Check blacklist first (avoid false positives)
        for pattern in blacklistPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        // Check for clothing keywords
        for keyword in clothingKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }
        
        // Check for clothing brands
        for brand in clothingBrands {
            if lowercased.contains(brand) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Generic Parser (Fallback)

class GenericEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        var products: [ProductData] = []
        
        // Strategy: Find all images with product-like alt text and nearby text for names
        let imagePattern = #"<img[^>]*src=["']([^"']+)["'][^>]*alt=["']([^"']+)["'][^>]*>"#
        let regex = try NSRegularExpression(pattern: imagePattern, options: .caseInsensitive)
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            if match.numberOfRanges >= 3,
               let imageURLRange = Range(match.range(at: 1), in: html),
               let altTextRange = Range(match.range(at: 2), in: html) {
                
                let imageURLString = String(html[imageURLRange])
                let altText = String(html[altTextRange])
                
                // Filter out common non-product images
                guard !altText.lowercased().contains("logo"),
                      !altText.lowercased().contains("banner"),
                      !altText.lowercased().contains("icon"),
                      !imageURLString.contains("spacer"),
                      let imageURL = URL(string: imageURLString) else {
                    continue
                }
                
                // Use alt text as product name (clean it up)
                let productName = cleanProductName(altText)
                
                guard !productName.isEmpty else { continue }
                
                // ✨ Filter to clothing items only
                guard ClothingDetector.isClothingItem(productName) else {
                    continue
                }
                
                products.append(ProductData(
                    name: productName,
                    imageURL: imageURL,
                    brand: nil,
                    size: nil,
                    color: nil,
                    category: nil,
                    tags: []
                ))
            }
        }
        
        return products
    }
    
    func cleanProductName(_ name: String) -> String {
        // Remove HTML entities and clean up
        var cleaned = name
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common noise words
        let noiseWords = ["image", "product", "item"]
        for noise in noiseWords {
            if cleaned.lowercased() == noise {
                return ""
            }
        }
        
        return cleaned
    }
}

// MARK: - Amazon Parser

class AmazonEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        var products: [ProductData] = []
        
        // Amazon uses specific patterns for product images and titles
        // Pattern: Look for product-image class and nearby product-title
        let productPattern = #"<img[^>]*class="[^"]*product-image[^"]*"[^>]*src=["']([^"']+)["'][^>]*>.*?<[^>]*class="[^"]*product.*?title[^"]*"[^>]*>([^<]+)<"#
        
        if let regex = try? NSRegularExpression(pattern: productPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let imageURLRange = Range(match.range(at: 1), in: html),
                   let nameRange = Range(match.range(at: 2), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    let productName = String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let imageURL = URL(string: imageURLString), !productName.isEmpty {
                        // Filter to clothing items only
                        guard ClothingDetector.isClothingItem(productName) else { continue }
                        
                        products.append(ProductData(
                            name: productName,
                            imageURL: imageURL,
                            brand: "Amazon",
                            size: nil,
                            color: nil,
                            category: nil,
                            tags: ["amazon"]
                        ))
                    }
                }
            }
        }
        
        // Fallback to generic parser if Amazon-specific pattern doesn't work
        if products.isEmpty {
            return try await GenericEmailParser().extractProducts(from: email)
        }
        
        return products
    }
}

// MARK: - Nike Parser

class NikeEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        var products: [ProductData] = []
        
        // Nike often includes product names in specific divs
        // Look for images with high resolution (typically product photos)
        let imagePattern = #"<img[^>]*src=["']([^"']+(?:nike|product)[^"']+)["'][^>]*>"#
        
        if let regex = try? NSRegularExpression(pattern: imagePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if match.numberOfRanges >= 2,
                   let imageURLRange = Range(match.range(at: 1), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    
                    guard let imageURL = URL(string: imageURLString) else { continue }
                    
                    // Extract product name from surrounding context
                    let productName = extractNearbyText(from: html, around: match.range, pattern: #"<td[^>]*>([^<]+)</td>"#) ?? "Nike Product"
                    
                    // Filter to clothing items only
                    guard ClothingDetector.isClothingItem(productName) else { continue }
                    
                    products.append(ProductData(
                        name: productName,
                        imageURL: imageURL,
                        brand: "Nike",
                        size: nil,
                        color: nil,
                        category: nil,
                        tags: ["nike"]
                    ))
                }
            }
        }
        
        if products.isEmpty {
            return try await GenericEmailParser().extractProducts(from: email)
        }
        
        return products
    }
    
    private func extractNearbyText(from html: String, around range: NSRange, pattern: String) -> String? {
        // Extract text nearby the match using another pattern
        let context = NSRange(location: max(0, range.location - 500), length: min(1000, html.count - max(0, range.location - 500)))
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: context),
           match.numberOfRanges >= 2,
           let textRange = Range(match.range(at: 1), in: html) {
            return String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
}

// MARK: - Zara Parser

class ZaraEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        var products: [ProductData] = []
        
        // Zara typically uses clean product image URLs
        let productPattern = #"<img[^>]*src=["']([^"']*zara[^"']+\.(jpg|jpeg|png))["'][^>]*alt=["']([^"']+)["'][^>]*>"#
        
        if let regex = try? NSRegularExpression(pattern: productPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if match.numberOfRanges >= 4,
                   let imageURLRange = Range(match.range(at: 1), in: html),
                   let altTextRange = Range(match.range(at: 3), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    let productName = String(html[altTextRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let imageURL = URL(string: imageURLString), !productName.isEmpty {
                        // Filter to clothing items only
                        guard ClothingDetector.isClothingItem(productName) else { continue }
                        
                        products.append(ProductData(
                            name: productName,
                            imageURL: imageURL,
                            brand: "Zara",
                            size: nil,
                            color: nil,
                            category: nil,
                            tags: ["zara"]
                        ))
                    }
                }
            }
        }
        
        if products.isEmpty {
            return try await GenericEmailParser().extractProducts(from: email)
        }
        
        return products
    }
}
