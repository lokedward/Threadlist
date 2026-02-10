// StylistService.swift
// AI styling and image generation with multi-provider support

import Foundation
import SwiftUI
internal import Combine 

class StylistService {
    static let shared = StylistService()
    
    private init() {}
    
    // MARK: - Usage Tracking
    
    @AppStorage("monthlyGenerationCount") private var monthlyGenerationCount: Int = 0
    @AppStorage("lastResetDate") private var lastResetDate: String = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"
    
    // MARK: - Testing Override
    @Published var forceProvider: AIProvider? = nil // Set to override tier-based selection
    
    enum AIProvider {
        case sdxl, imagen
    }
    
    var userTier: GenerationTier {
        get { userTierRaw == "premium" ? .premium : .free }
        set { userTierRaw = newValue == .premium ? "premium" : "free" }
    }
    
    var generationsRemaining: Int? {
        guard let limit = userTier.monthlyLimit else { return nil } // unlimited
        resetCountIfNeeded()
        return max(0, limit - monthlyGenerationCount)
    }
    
    private func resetCountIfNeeded() {
        let currentMonth = currentMonthKey()
        if lastResetDate != currentMonth {
            monthlyGenerationCount = 0
            lastResetDate = currentMonth
        }
    }
    
    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    private func incrementGenerationCount() {
        resetCountIfNeeded()
        monthlyGenerationCount += 1
    }
    
    // MARK: - Layering Logic
    
    /// Determines the z-index/order for an item based on its category
    func layeringOrder(for item: ClothingItem) -> Int {
        guard let categoryName = item.category?.name.lowercased() else { return 0 }
        
        // Lower numbers are back, higher are front
        if categoryName.contains("under") || categoryName.contains("base") {
            return 10
        } else if categoryName.contains("pant") || categoryName.contains("skirt") || categoryName.contains("jean") {
            return 20
        } else if categoryName.contains("top") || categoryName.contains("shirt") || categoryName.contains("blouse") {
            return 30
        } else if categoryName.contains("dress") {
            return 35
        } else if categoryName.contains("outer") || categoryName.contains("jacket") || categoryName.contains("coat") {
            return 40
        } else if categoryName.contains("shoe") || categoryName.contains("boot") {
            return 50
        } else if categoryName.contains("access") || categoryName.contains("bag") || categoryName.contains("hat") {
            return 60
        }
        
        return 0
    }
    
    // MARK: - AI Generation
    
    /// Generate a styled model photo with selected clothing items
    func generateModelPhoto(items: [ClothingItem], gender: Gender) async throws -> UIImage {
        guard !items.isEmpty else {
            throw StylistError.noItemsSelected
        }
        
        // Check usage limits
        if let remaining = generationsRemaining, remaining <= 0 {
            throw StylistError.limitReached
        }
        
        // Build the prompt
        let prompt = buildPrompt(for: items, gender: gender)
        
        // Call appropriate API based on forceProvider (testing override) or tier
        let generatedImageData: Data
        if let forced = forceProvider {
            // Override: use manually selected provider
            switch forced {
            case .sdxl:
                generatedImageData = try await callStabilityAPI(prompt: prompt)
            case .imagen:
                generatedImageData = try await callImagenAPI(prompt: prompt)
            }
        } else {
            // Normal flow: use tier-based selection
            switch userTier {
            case .free:
                generatedImageData = try await callStabilityAPI(prompt: prompt)
            case .premium:
                generatedImageData = try await callImagenAPI(prompt: prompt)
            }
        }
        
        guard let image = UIImage(data: generatedImageData) else {
            throw StylistError.invalidImageData
        }
        
        // Increment usage counter
        incrementGenerationCount()
        
        return image
    }
    
    // MARK: - Private Helpers
    
    private func buildPrompt(for items: [ClothingItem], gender: Gender) -> String {
        let genderTerm = gender == .female ? "female" : "male"
        let modelDescription = "Professional fashion photography of a \(genderTerm) model wearing"
        
        // Sort items by layering order for natural description
        let sortedItems = items.sorted { layeringOrder(for: $0) < layeringOrder(for: $1) }
        
        var clothingDescriptions: [String] = []
        
        for item in sortedItems {
            // Extract color from image
            let color = extractColorFromItem(item)
            
            // Build category description
            var categoryName = item.category?.name.lowercased() ?? "garment"
            
            // Enhanced category naming
            categoryName = enhanceCategoryName(categoryName)
            
            // Detect patterns/graphics from name and tags
            let details = extractDetailsFromItem(item)
            
            // Build full description: [color] [details] [category] [brand/name]
            var desc = "\(color)"
            
            // Add pattern/graphic details if found
            if !details.isEmpty {
                desc += " \(details)"
            }
            
            desc += " \(categoryName)"
            
            if let brand = item.brand, !brand.isEmpty {
                desc += " by \(brand)"
            }
            
            // Only add name if it's not redundant with details already captured
            let nameLower = item.name.lowercased()
            if !item.name.isEmpty && !nameLower.contains(categoryName) && !details.lowercased().contains(nameLower) {
                desc += " (\(item.name))"
            }
            
            clothingDescriptions.append(desc)
        }
        
        // Format as bullet list for better SDXL comprehension
        let clothingList = clothingDescriptions.map { "- \($0)" }.joined(separator: "\n")
        
        // Enhanced prompt with detailed photography direction
        return """
        \(modelDescription):
        \(clothingList)
        
        Full body close up portrait, 3/4 angle view, neutral grey studio background, soft key lighting with subtle rim light, editorial fashion photography, photorealistic, sharp focus on clothing details, professional studio quality
        """
    }
    
    private func extractDetailsFromItem(_ item: ClothingItem) -> String {
        var details: [String] = []
        
        // Check name and tags for patterns, graphics, and style details
        let searchText = (item.name + " " + item.tags.joined(separator: " ")).lowercased()
        
        // Graphics/Text
        if searchText.contains("graphic") {
            details.append("graphic print")
        } else if searchText.contains("logo") {
            details.append("logo detail")
        } else if searchText.contains("text") || searchText.contains("slogan") {
            details.append("text print")
        }
        
        // Patterns
        if searchText.contains("stripe") {
            details.append("striped")
        } else if searchText.contains("floral") {
            details.append("floral pattern")
        } else if searchText.contains("dot") || searchText.contains("polka") {
            details.append("polka dot")
        } else if searchText.contains("check") || searchText.contains("plaid") {
            details.append("checkered")
        } else if searchText.contains("animal") || searchText.contains("leopard") || searchText.contains("zebra") {
            details.append("animal print")
        } else if searchText.contains("camo") {
            details.append("camouflage")
        } else if searchText.contains("tie-dye") || searchText.contains("tie dye") {
            details.append("tie-dye")
        }
        
        // Textures/Materials
        if searchText.contains("denim") {
            details.append("denim")
        } else if searchText.contains("leather") {
            details.append("leather")
        } else if searchText.contains("knit") || searchText.contains("sweater") {
            details.append("knitted")
        } else if searchText.contains("silk") || searchText.contains("satin") {
            details.append("silky")
        } else if searchText.contains("velvet") {
            details.append("velvet")
        }
        
        // Fit/Style
        if searchText.contains("oversized") {
            details.append("oversized fit")
        } else if searchText.contains("fitted") || searchText.contains("slim") {
            details.append("fitted")
        } else if searchText.contains("loose") || searchText.contains("relaxed") {
            details.append("relaxed fit")
        } else if searchText.contains("crop") {
            details.append("cropped")
        }
        
        // Distressing/Finish
        if searchText.contains("distress") || searchText.contains("ripped") {
            details.append("distressed")
        } else if searchText.contains("vintage") || searchText.contains("worn") {
            details.append("vintage")
        }
        
        return details.joined(separator: " ")
    }
    
    private func extractColorFromItem(_ item: ClothingItem) -> String {
        // Load the image and extract color
        if let image = ImageStorageService.shared.loadImage(withID: item.imageID) {
            return image.dominantColorName()
        }
        return "neutral" // fallback
    }
    
    private func enhanceCategoryName(_ category: String) -> String {
        // Map generic categories to more specific descriptions
        let lowercased = category.lowercased()
        
        if lowercased.contains("top") || lowercased.contains("shirt") || lowercased == "t-shirt" {
            return "crew neck t-shirt"
        } else if lowercased.contains("jean") || lowercased.contains("denim") {
            return "slim-fit jeans"
        } else if lowercased.contains("jacket") && !lowercased.contains("leather") {
            return "jacket"
        } else if lowercased.contains("dress") {
            return "midi dress"
        } else if lowercased.contains("skirt") {
            return "skirt"
        } else if lowercased.contains("pant") && !lowercased.contains("jean") {
            return "trousers"
        } else if lowercased.contains("shoe") || lowercased.contains("sneaker") {
            return "shoes"
        } else if lowercased.contains("boot") {
            return "boots"
        } else if lowercased.contains("bag") {
            return "handbag"
        } else if lowercased.contains("accessory") || lowercased.contains("hat") {
            return "accessory"
        }
        
        return category // return original if no match
    }
    
    // MARK: - API Calls
    
    private func callStabilityAPI(prompt: String) async throws -> Data {
        guard let url = URL(string: AppConfig.stabilityEndpoint) else {
            throw StylistError.invalidEndpoint
        }
        
        // Build request body for Stability AI (SDXL optimized)
        let requestBody: [String: Any] = [
            "text_prompts": [
                [
                    "text": prompt,
                    "weight": 1
                ],
                [
                    // Enhanced negative prompt for SDXL
                    "text": "blurry, distorted, low quality, cartoon, illustration, deformed body, extra limbs, malformed hands, disconnected clothing, floating garments, incorrect anatomy, unrealistic proportions, oversaturated colors, watermark, text overlay, multiple people, bad lighting, amateur photo",
                    "weight": -1
                ]
            ],
            "cfg_scale": 12,  // Increased from 7 for better prompt adherence
            "height": 1024,
            "width": 768,     // Changed to 3:4 ratio for fashion photography
            "samples": 1,
            "steps": 40       // Increased from 30 for more detail
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw StylistError.invalidRequest
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.stabilityAPIKey, forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StylistError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let artifacts = json["artifacts"] as? [[String: Any]],
              let firstArtifact = artifacts.first,
              let base64Image = firstArtifact["base64"] as? String,
              let imageData = Data(base64Encoded: base64Image) else {
            throw StylistError.invalidResponse
        }
        
        return imageData
    }
    
    private func callImagenAPI(prompt: String) async throws -> Data {
        // Build URL with API key as query parameter
        guard var urlComponents = URLComponents(string: AppConfig.imagenEndpoint) else {
            throw StylistError.invalidEndpoint
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: AppConfig.googleAPIKey)]
        
        guard let url = urlComponents.url else {
            throw StylistError.invalidEndpoint
        }
        
        // Build request body
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "number_of_images": 1,
            "aspect_ratio": "3:4",
            "safety_filter_level": "block_only_high",
            "person_generation": "allow_adult",
            "negative_prompt": "blurry, distorted, low quality, cartoon, illustration, deformed body, extra limbs, malformed hands"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw StylistError.invalidRequest
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StylistError.apiError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StylistError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [[String: Any]],
              let firstImage = images.first,
              let base64Image = firstImage["image"] as? String,
              let imageData = Data(base64Encoded: base64Image) else {
            throw StylistError.invalidImageData
        }
        
        return imageData
    }
    
    /// Get styling advice (legacy method - can be removed or enhanced)
    func getVibeCheck(for items: [ClothingItem]) async -> String {
        guard !items.isEmpty else { return "Select some pieces to get started!" }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let names = items.map { $0.name }
        return "This combination of \(names.joined(separator: " and ")) looks incredibly chic! The palette is giving 'quiet luxury' vibes. Perfect for a gallery opening or a sophisticated brunch."
    }
}

// MARK: - Supporting Types

enum StylistError: LocalizedError {
    case noItemsSelected
    case invalidImageData
    case invalidEndpoint
    case invalidRequest
    case invalidResponse
    case apiError(String)
    case limitReached
    
    var errorDescription: String? {
        switch self {
        case .noItemsSelected:
            return "Please select at least one clothing item"
        case .invalidImageData:
            return "Could not process the generated image"
        case .invalidEndpoint:
            return "Invalid API endpoint configuration"
        case .invalidRequest:
            return "Failed to create API request"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let message):
            return "AI service error: \(message)"
        case .limitReached:
            return "You've reached your monthly generation limit. Upgrade to Premium for unlimited access!"
        }
    }
}
