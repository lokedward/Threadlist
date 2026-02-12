// StylistService.swift
// AI styling and image generation with multi-provider support

import Foundation
import SwiftUI
internal import Combine 

class StylistService {
    static let shared = StylistService()
    
    private init() {}
    
    // MARK: - Usage Tracking
    
    @AppStorage("dailyGenerationCount") private var dailyGenerationCount: Int = 0
    @AppStorage("lastResetDate") private var lastResetDate: String = "" // "yyyy-MM-dd"
    @AppStorage("userTier") private var userTierRaw: String = "free"
    
    var userTier: GenerationTier {
        get { userTierRaw == "premium" ? .premium : .free }
        set { userTierRaw = newValue == .premium ? "premium" : "free" }
    }
    
    var generationsRemaining: Int? {
        let limit = userTier == .premium ? 50 : 3 // Daily limits
        resetCountIfNeeded()
        return max(0, limit - dailyGenerationCount)
    }
    
    private func resetCountIfNeeded() {
        let currentDay = currentDayKey()
        if lastResetDate != currentDay {
            dailyGenerationCount = 0
            lastResetDate = currentDay
        }
    }
    
    private func currentDayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func incrementGenerationCount() {
        resetCountIfNeeded()
        dailyGenerationCount += 1
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
    
    // MARK: - AI Generation (Outfit Stitching)
    
    /// Generate a cohesive outfit stitched onto a model using Google's Virtual Try-On logic
    func generateModelPhoto(items: [ClothingItem], gender: Gender) async throws -> UIImage {
        guard items.count >= 2 else {
            throw StylistError.apiError("Please select 2 or more items to stitch an outfit.")
        }
        
        // Check usage limits
        if let remaining = generationsRemaining, remaining <= 0 {
            throw StylistError.limitReached
        }
        
        // Prepare garment images
        let garmentImages = items.compactMap { item -> UIImage? in
            ImageStorageService.shared.loadImage(withID: item.imageID)
        }
        
        guard garmentImages.count == items.count else {
            throw StylistError.invalidImageData
        }
        
        // Build the stitching request
        // Note: For Imagen 3 "Stitching" (Nanobanana), we typically send garments as auxiliary inputs
        let imageData: Data = try await callStitchingAPI(garments: garmentImages, gender: gender)
        
        guard let image = UIImage(data: imageData) else {
            throw StylistError.invalidImageData
        }
        
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
    
    // MARK: - API Calls (Stitching Implementation)
    
    private func callStitchingAPI(garments: [UIImage], gender: Gender) async throws -> Data {
        // Build URL with API key as query parameter for Generative Language API
        // or use the standard URL if it's a Vertex AI endpoint
        let isVertex = AppConfig.imagenEndpoint.contains("aiplatform.googleapis.com")
        
        var urlComponents = URLComponents(string: AppConfig.imagenEndpoint)
        if !isVertex {
            // AI Studio keys usually go in query params
            urlComponents?.queryItems = [URLQueryItem(name: "key", value: AppConfig.googleAPIKey)]
        }
        
        guard let url = urlComponents?.url else {
            throw StylistError.invalidEndpoint
        }
        
        // Convert garments to Base64 for the API
        let garmentData = garments.compactMap { $0.jpegData(compressionQuality: 0.8)?.base64EncodedString() }
        
        // Construct the payload. 
        // Note: For "Stitching" (Virtual Try On), the API typically expects a base 'person_image' 
        // to stitch garments ONTO. Since we don't have a selfie yet, we use a placeholder 
        // model based on gender.
        
        let requestBody: [String: Any]
        if AppConfig.imagenEndpoint.contains("virtual-try-on") {
            // Official Virtual Try On Format
            requestBody = [
                "instances": [
                    [
                        "person_image": ["bytesBase64Encoded": ""], // We need a base model image here
                        "garment_image": ["bytesBase64Encoded": garmentData.first ?? ""]
                    ]
                ]
            ]
        } else {
            // standard Imagen 3 format with multi-image signals if supported
            requestBody = [
                "instances": [
                    [
                        "prompt": "A professional fashion photography shot of a \(gender == .female ? "female" : "male") model wearing these specific items: \(garments.count) separate garments. Photorealistic, 8k, studio lighting.",
                        "image": ["bytesBase64Encoded": garmentData.first ?? ""] // If using as reference
                    ]
                ],
                "parameters": [
                    "sampleCount": 1,
                    "aspectRatio": "3:4"
                ]
            ]
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw StylistError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if isVertex {
            // Vertex AI uses Bearer tokens (OAuth)
            request.setValue("Bearer \(AppConfig.googleAPIKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("❌ API Error \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(errorString)")
            }
            throw StylistError.apiError("Google API returned status \(httpResponse.statusCode). Check your endpoint/key.")
        }
        
        // Parse result (assuming standard Image generation response)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let first = predictions.first,
              let b64 = first["bytesBase64Encoded"] as? String,
              let image = Data(base64Encoded: b64) else {
            throw StylistError.invalidResponse
        }
        
        return image
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
            return "Could not process the garment images"
        case .invalidEndpoint:
            return "Stitching API misconfigured"
        case .invalidRequest:
            return "Failed to create stitching request"
        case .invalidResponse:
            return "Invalid response from outfit generator"
        case .apiError(let message):
            return message
        case .limitReached:
            return "You've reached your daily limit of 3 outfits. Upgrade to Premium for unlimted looks!"
        }
    }
}
