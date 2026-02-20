// EmailParsers.swift
// Handles email parsing logic for extracting product information

import Foundation

// MARK: - Parser Protocol

protocol EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData]
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
        
        // Bottoms
        "pant", "pants", "bottoms", "trousers", "slacks", "chinos", "cargos", 
        "joggers", "leggings", "sweatpants", "shorts", "jeans", "denim",
        
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
        "lululemon", "alo", "alo yoga", "vuori", "gymshark", "fabletics", "athleta",
        "rhone", "publish", "outdoor voices",
        
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
        "clothing rack", "garment bag", "shoe cleaner", "fabric softener",
        "shipping", "tax", "total", "subtotal", "discount", "receipt", "order",
        "shop now", "view online", "view in browser", "unsubscribe", "privacy",
        "terms", "returns", "exchange", "gift card", "store locator",
        "free delivery", "percent off", "% off", "sale", "clearance", "limited time",
        "barcode", "qr code", "apple wallet", "apple pay", "google pay", "add to wallet", "wallet",
        "download app", "get the app", "app store", "play store", "social", "follow us",
        "esrb", "rated teen", "rated mature", "rated everyone", "pegi", "rating",
        "chick-fil-a", "chicken", "sandwich", "meal", "food", "beverage", "drink", "fries",
        "series", "season", "episode", "watch now", "stream", "original series"
    ]
    
    static func isBlacklisted(_ name: String) -> Bool {
        let lower = name.lowercased()
        return blacklistPatterns.contains(where: { lower.contains($0) })
    }
    
    static func hasClothingKeyword(_ name: String) -> Bool {
        let lower = name.lowercased()
        return clothingKeywords.contains(where: { lower.contains($0) })
    }
    
    static func isClothingItem(_ productName: String) -> Bool {
        let lowercased = productName.lowercased()
        
        // Check blacklist first
        if isBlacklisted(productName) { return false }
        
        // Check keywords
        if hasClothingKeyword(productName) { return true }
        
        // Check brands
        for brand in clothingBrands {
            if lowercased.contains(brand) { return true }
        }
        
        // Default false (caller might override if context is strong)
        return false
    }
    
    static func isLikelyProductImage(url: String, alt: String?, width: Int? = nil, height: Int? = nil) -> Bool {
        let lowerUrl = url.lowercased()
        
        // 1. Keyword Blocklist
        let urlBlocklist = ["logo", "icon", "social", "footer", "header", "nav", "tracking", "pixel", "button", "arrow", "star", "rating", "spacer"]
        if urlBlocklist.contains(where: { lowerUrl.contains($0) }) { return false }
        
        // 2. Brand Identity Check (The Logo Killer)
        // If alt text is EXACTLY a brand name (e.g. "Madewell"), it is the logo.
        if let altText = alt {
            let cleanAlt = altText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if clothingBrands.contains(cleanAlt) { return false }
        }

        // 3. Dimension Logic (Safe Mode)
        if let w = width {
            // Allow small thumbnails (e.g. 112px)
            if w < 90 { return false }
            
            if let h = height, h > 0 {
                if h < 90 { return false }
                let ratio = Double(w) / Double(h)
                // Reject extremely wide (banners) or tall (spacers)
                if ratio > 2.5 || ratio < 0.33 { return false }
            } else {
                // Missing height? Only reject if it's clearly a massive banner
                if w > 600 { return false }
            }
        }
        
        return true
    }
    
    static func isBrandName(_ name: String) -> Bool {
        return clothingBrands.contains(name.lowercased())
    }
}

// MARK: - Generic Parser (Fallback)

class GenericEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let rawHtml = email.htmlBody else { return [] }
        
        // 1. Strip Forwarded Headers (Robust)
        var processingHtml = rawHtml
        // Match standard Gmail/Outlook forward markers
        let forwardMarkers = ["Begin forwarded message", "Forwarded message", "---------- Original Message ----------"]
        for marker in forwardMarkers {
            if let range = processingHtml.range(of: marker, options: .caseInsensitive) {
                processingHtml = String(processingHtml[range.upperBound...])
                break
            }
        }

        // 2. The "Gold Zone" Crop (Safe Buffer)
        // Locate the "Order" section to avoid picking up the top-level logo
        let startMarkers = ["Order Summary", "Order #", "Order Number", "Your Order", "Item Details"]
        let endMarkers = ["Subtotal", "Order Total", "Total Payment", "Tax", "Shipping"]
        
        var startIndex = processingHtml.startIndex
        var endIndex = processingHtml.endIndex
        
        // Find Start (Earliest occurrence)
        for marker in startMarkers {
            if let range = processingHtml.range(of: marker, options: .caseInsensitive) {
                // Found a marker? Back up 1500 chars to catch any images slightly above the text
                if range.lowerBound < startIndex || startIndex == processingHtml.startIndex {
                    startIndex = processingHtml.index(range.lowerBound, offsetBy: -1500, limitedBy: processingHtml.startIndex) ?? processingHtml.startIndex
                    break
                }
            }
        }
        
        // Find End (Last occurrence)
        for marker in endMarkers {
            if let range = processingHtml.range(of: marker, options: [.caseInsensitive, .backwards]) {
                endIndex = range.upperBound
                break
            }
        }
        
        let html = String(processingHtml[startIndex..<endIndex])
        
        var candidates: [ProductData] = []
        
        // Strategy: Find all images tags and parse attributes
        let imgTagPattern = #"<img\s+([^>]+)>"#
        let regex = try NSRegularExpression(pattern: imgTagPattern, options: .caseInsensitive)
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        var seenURLs = Set<URL>()
        
        for match in matches {
            if match.numberOfRanges >= 2,
               let tagRange = Range(match.range(at: 1), in: html) {
                
                let tagContent = String(html[tagRange])
                
                guard let imageURLString = extractAttribute("src", from: tagContent),
                      let imageURL = URL(string: imageURLString) else { continue }
                
                let altText = extractAttribute("alt", from: tagContent) ?? ""
                let width = Int(extractAttribute("width", from: tagContent) ?? "0")
                let height = Int(extractAttribute("height", from: tagContent) ?? "0")
                
                // Deduplicate by URL immediately
                guard !seenURLs.contains(imageURL) else { continue }
                
                // 1. Structural Filter: Image Validation
                // Must be likely product image (dimension check)
                guard ClothingDetector.isLikelyProductImage(url: imageURLString, alt: altText, width: width == 0 ? nil : width, height: height == 0 ? nil : height) else {
                    continue
                }
                
                // Clean Name - Fallback to context if alt is empty or generic
                var productName = cleanProductName(altText)
                if productName.isEmpty {
                    if let extractedName = extractNameFromContext(context) {
                        productName = extractedName
                    }
                }
                
                let hasPrice = hasPricePattern(context)
                
                if hasPrice {
                    score += 10 // Baseline for valid structure
                }
                
                // Keyword matches
                if ClothingDetector.isClothingItem(productName) {
                    score += 50
                } else if ClothingDetector.isBlacklisted(productName) {
                    score -= 100
                }
                
                // Brand match
                if ClothingDetector.isBrandName(productName) {
                    score += 50
                }
                
                // Size/Qty clues in context (heuristic)
                if context.localizedCaseInsensitiveContains("Qty") || 
                   context.localizedCaseInsensitiveContains("Quantity") ||
                   context.localizedCaseInsensitiveContains("Size:") {
                    score += 20
                }
                
                if score > 0 {
                    seenURLs.insert(imageURL)
                    candidates.append(ProductData(
                        name: productName,
                        imageURL: imageURL,
                        price: extractPrice(from: context), // Extract actual string if possible
                        brand: nil,
                        size: nil,
                        color: nil,
                        category: nil,
                        tags: [],
                        score: score
                    ))
                }
            }
        }
        
        // Sort descending by score
        return candidates.sorted { $0.score > $1.score }
    }
    
    // MARK: - Gold Zone Cropping
    
    private func cropToTransactionalArea(_ html: String) -> String {
        let lower = html.lowercased()
        
        // Markers to identify the start of the receipt/order list
        let startMarkers = ["order", "item", "description", "details"]
        
        // Markers to identify the end of the receipt (totals area)
        let endMarkers = ["subtotal", "total", "tax", "shipping"]
        
        var startIdx: String.Index?
        for marker in startMarkers {
            if let range = lower.range(of: marker) {
                if startIdx == nil || range.lowerBound < startIdx! {
                    startIdx = range.lowerBound
                }
            }
        }
        
        var endIdx: String.Index?
        for marker in endMarkers {
            if let range = lower.range(of: marker, options: .backwards) {
                if endIdx == nil || range.upperBound > endIdx! {
                    endIdx = range.upperBound
                }
            }
        }
        
        // If both found and valid order, crop
        if let start = startIdx, let end = endIdx, start < end {
            // Apply crop
            // We include the markers themselves as they form the boundary
            let safeStart = html.index(start, offsetBy: -50, limitedBy: html.startIndex) ?? html.startIndex
            let safeEnd = html.index(end, offsetBy: 50, limitedBy: html.endIndex) ?? html.endIndex
            
            return String(html[safeStart..<safeEnd])
        }
        
        return html
    }
    
    
    // Helper to extract specific price string (heuristic)
    func extractPrice(from text: String) -> String? {
        let priceRegex = #"\$\d+([.,]\d{2})?"#
        if let range = text.range(of: priceRegex, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
    
    func extractAttribute(_ name: String, from text: String) -> String? {
        let pattern = name + #"=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    func extractNearbyText(from html: String, around range: Range<String.Index>, offset: Int = 300) -> String {
        let startOffset = html.distance(from: html.startIndex, to: range.lowerBound)
        let endOffset = html.distance(from: html.startIndex, to: range.upperBound)
        
        let start = max(0, startOffset - offset)
        let end = min(html.count, endOffset + offset)
        
        let startIndex = html.index(html.startIndex, offsetBy: start)
        let endIndex = html.index(html.startIndex, offsetBy: end)
        
        return String(html[startIndex..<endIndex])
    }
    
    func hasPricePattern(_ text: String) -> Bool {
        let priceRegex = #"\$\d+([.,]\d{2})?|\d+([.,]\d{2})?\s*USD"#
        return text.range(of: priceRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    func cleanProductName(_ name: String) -> String {
        // Remove HTML entities and clean up
        var cleaned = name
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common noise words (exact matches)
        let noiseWords = [
            "image", "product", "item", "cart image", "product image", 
            "picture", "photo", "thumbnail", "clothing", "apparel"
        ]
        
        let lowerCleaned = cleaned.lowercased()
        for noise in noiseWords {
            if lowerCleaned == noise {
                return ""
            }
        }
        
        // If the alt text is ridiculously short (e.g. "1", "a"), it's not a product name
        if cleaned.count <= 2 {
            return ""
        }
        
        return cleaned
    }
    
    func extractNameFromContext(_ context: String) -> String? {
        let linkPattern = #"<a[^>]*>([^<]+)</a>"#
        
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: context, range: NSRange(context.startIndex..., in: context))
            
            for match in matches {
                if match.numberOfRanges >= 2,
                   let range = Range(match.range(at: 1), in: context) {
                    let text = String(context[range])
                    let cleaned = cleanProductName(text)
                    
                    if !cleaned.isEmpty && 
                       !ClothingDetector.isBlacklisted(cleaned) &&
                       !ClothingDetector.isBrandName(cleaned) &&
                       !hasPricePattern(cleaned) &&
                       cleaned.count < 100 {
                        return cleaned
                    }
                }
            }
        }
        return nil
    }
    
    private func removePromotionalContent(_ html: String) -> String {
        let stopPhrases = [
            "you might also like", "recommended for you",
            "customers also bought", "complete the look",
            "related products", "top picks for you",
            "frequently bought together"
        ]
        
        let lowerHtml = html.lowercased()
        var earliestIndex: String.Index? = nil
        
        for phrase in stopPhrases {
            if let range = lowerHtml.range(of: phrase) {
                if earliestIndex == nil || range.lowerBound < earliestIndex! {
                    earliestIndex = range.lowerBound
                }
            }
        }
        
        if let stopIndex = earliestIndex {
             return String(html[..<stopIndex])
        }
        
        return html
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
            
            var seenURLs = Set<URL>()
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let imageURLRange = Range(match.range(at: 1), in: html),
                   let nameRange = Range(match.range(at: 2), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    let productName = String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let imageURL = URL(string: imageURLString),
                       !productName.isEmpty,
                       ClothingDetector.isLikelyProductImage(url: imageURLString, alt: productName) {
                        // Filter to clothing items only
                        guard ClothingDetector.isClothingItem(productName),
                              !ClothingDetector.isBrandName(productName) else { continue }
                        
                        // Deduplicate
                        guard !seenURLs.contains(imageURL) else { continue }
                        seenURLs.insert(imageURL)
                        
                        products.append(ProductData(
                            name: productName,
                            imageURL: imageURL,
                            price: nil,
                            brand: "Amazon",
                            size: nil,
                            color: nil,
                            category: nil,
                            tags: ["amazon"],
                            score: 90 // High confidence for known parser
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
            
            var seenURLs = Set<URL>()
            
            for match in matches {
                if match.numberOfRanges >= 2,
                   let imageURLRange = Range(match.range(at: 1), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    
                    // Extract product name from surrounding context (used for alt text in isLikelyProductImage)
                    let productName = extractNearbyText(from: html, around: match.range, pattern: #"<td[^>]*>([^<]+)</td>"#) ?? "Nike Product"

                    guard ClothingDetector.isLikelyProductImage(url: imageURLString, alt: productName),
                          let imageURL = URL(string: imageURLString) else { continue }
                    
                    // Filter to clothing items only
                    guard ClothingDetector.isClothingItem(productName),
                          !ClothingDetector.isBrandName(productName) else { continue }
                    
                    // Deduplicate
                    guard !seenURLs.contains(imageURL) else { continue }
                    seenURLs.insert(imageURL)
                    
                    products.append(ProductData(
                        name: productName,
                        imageURL: imageURL,
                        price: nil,
                        brand: "Nike",
                        size: nil,
                        color: nil,
                        category: nil,
                        tags: ["nike"],
                        score: 90 // High confidence
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
            
            var seenURLs = Set<URL>()
            
            for match in matches {
                if match.numberOfRanges >= 4,
                   let imageURLRange = Range(match.range(at: 1), in: html),
                   let altTextRange = Range(match.range(at: 3), in: html) {
                    
                    let imageURLString = String(html[imageURLRange])
                    let productName = String(html[altTextRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let imageURL = URL(string: imageURLString),
                       !productName.isEmpty,
                       ClothingDetector.isLikelyProductImage(url: imageURLString, alt: productName) {
                        // Filter to clothing items only
                        guard ClothingDetector.isClothingItem(productName),
                              !ClothingDetector.isBrandName(productName) else { continue }
                        
                        // Deduplicate
                        guard !seenURLs.contains(imageURL) else { continue }
                        seenURLs.insert(imageURL)
                        
                        products.append(ProductData(
                            name: productName,
                            imageURL: imageURL,
                            price: nil,
                            brand: "Zara",
                            size: nil,
                            color: nil,
                            category: nil,
                            tags: ["zara"],
                            score: 90 // High confidence
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

// MARK: - Lululemon Parser

class LululemonEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        let genericParser = GenericEmailParser()
        let products = genericParser.extractProducts(from: html)
        
        // Ensure brand is mapped
        return products.map { product in
            ProductData(
                name: product.name,
                imageURL: product.imageURL,
                price: product.price,
                brand: "Lululemon",
                size: product.size,
                color: product.color,
                category: product.category,
                tags: product.tags,
                score: product.score + 10
            )
        }
    }
}

// MARK: - Adidas Parser

class AdidasEmailParser: EmailParser {
    func extractProducts(from email: GmailMessage) async throws -> [ProductData] {
        guard let html = email.htmlBody else { return [] }
        
        var products: [ProductData] = []
        let genericParser = GenericEmailParser()
        
        // Fallback or explicit adidas pattern
        // It's often easier to leverage Generic parsing since we upgraded it to use context names
        let genericProducts = genericParser.extractProducts(from: html)
        
        // Ensure brand is mapped
        return genericProducts.map { product in
            ProductData(
                name: product.name,
                imageURL: product.imageURL,
                price: product.price,
                brand: "Adidas",
                size: product.size,
                color: product.color,
                category: product.category,
                tags: product.tags,
                score: product.score + 10
            )
        }
    }
}
