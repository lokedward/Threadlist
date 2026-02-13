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
    func importFromGmail(timeRange: TimeRange) async throws -> [EmailProductItem] {
        // Validate tier access
        guard canAccessTimeRange(timeRange) else {
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
            let token = try await GmailClient.shared.requestGmailAccess()
            
            // Step 2: Search for order confirmation emails
            await updateProgress(.searching)
            let query = buildGmailQuery(for: timeRange)
            let emails = try await GmailClient.shared.searchOrderEmails(token: token, query: query)
            
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
            try await GmailClient.shared.revokeGmailToken(token)
            
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
    
    func canAccessTimeRange(_ range: TimeRange) -> Bool {
        let currentTier = SubscriptionService.shared.currentTier
        switch (range, currentTier) {
        case (.sixMonths, _):
            return true // Any tier can access 6 months
        case (.twoYears, .boutique), (.twoYears, .atelier), (.custom, .boutique), (.custom, .atelier):
            return true // Premium tiers can access extended ranges
        case (.twoYears, .free), (.custom, .free):
            return false // Free tier cannot access premium ranges
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildGmailQuery(for range: TimeRange) -> String {
        // Broad query to catch order confirmations in various formats
        // Including forwarded emails which may have different subject patterns
        let timeFilter = range.gmailTimeFilter
        
        // Search for common order-related keywords in subject
        // Much broader than before to catch forwarded emails and various retailers
        // Broad query to catch all potential orders, filtering happens in isTransactionalEmail
        let query = """
        subject:(order OR shipped OR delivered OR shipment OR confirmation OR receipt OR invoice OR "thank you for your purchase")
        \(timeFilter)
        """
        
        print("📧 Gmail Query: \(query)")
        return query
    }
    
    // MARK: - Email Parsing Orchestration
    
    private func parseEmails(_ emails: [GmailMessage]) async throws -> [ProductData] {
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
            
            // Validate transactional content (skip marketing blasts)
            // Note: Parser might handle this internally, but good to have a high-level check
            if let html = email.htmlBody, !isTransactionalEmail(html) {
                 await MainActor.run {
                    progress?.detailMessage = "Skipping non-transactional email..."
                }
                continue
            }
            
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
        
        // Global Deduplication (across multiple emails)
        // Sort by score descending first to prioritize high-confidence items
        allProducts.sort { $0.score > $1.score }
        
        var uniqueProducts: [ProductData] = []
        var seenGlobalURLs = Set<URL>()
        
        for product in allProducts {
            if !seenGlobalURLs.contains(product.imageURL) {
                seenGlobalURLs.insert(product.imageURL)
                uniqueProducts.append(product)
            }
        }
        
        return uniqueProducts
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
    
    private func isTransactionalEmail(_ html: String) -> Bool {
        let lower = html.lowercased()
        // Stricter keywords to avoid marketing emails that mention "order" or "total"
        let keywords = [
            "order #", "order number", "order id", 
            "receipt #", "invoice #", 
            "order total", "grand total", "payment method",
            "tracking number", "track your package", "track my package",
            "your order has shipped", "shipment confirmation", 
            "thank you for your purchase", "thanks for your order",
            "order details", "order summary", "purchase details", "transaction details"
        ]
        return keywords.contains(where: { lower.contains($0) })
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
    
    // MARK: - ClothingItem Creation (Optional Utility)
    
    func createClothingItems(from products: [ProductData]) async throws -> [ClothingItem] {
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
    private func updateProgress(_ phase: ImportPhase, totalEmails: Int? = nil) {
        progress?.phase = phase
        if let total = totalEmails {
            progress?.totalEmails = total
        }
    }
}
