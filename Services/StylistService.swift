// StylistService.swift
// AI styling and image generation with multi-provider support

import Foundation
import SwiftUI

class StylistService {
    static let shared = StylistService()
    
    private init() {}
    
    // MARK: - Usage Tracking
    
    @AppStorage("monthlyGenerationCount") private var monthlyGenerationCount: Int = 0
    @AppStorage("lastResetDate") private var lastResetDate: String = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"
    
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
        
        // Call appropriate API based on tier
        let generatedImageData: Data
        switch userTier {
        case .free:
            generatedImageData = try await callStabilityAPI(prompt: prompt)
        case .premium:
            generatedImageData = try await callImagenAPI(prompt: prompt)
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
        let modelDescription = "A professional fashion model photo of a \(genderTerm) model"
        
        // Sort items by layering order for natural description
        let sortedItems = items.sorted { layeringOrder(for: $0) < layeringOrder(for: $1) }
        
        var clothingDescriptions: [String] = []
        
        for item in sortedItems {
            var desc = ""
            if let category = item.category?.name.lowercased() {
                desc += "\(category)"
            }
            if let brand = item.brand, !brand.isEmpty {
                desc += " by \(brand)"
            }
            if !item.name.isEmpty {
                desc += " (\(item.name))"
            }
            clothingDescriptions.append(desc)
        }
        
        let clothingList = clothingDescriptions.joined(separator: ", ")
        
        // Final prompt
        return """
        \(modelDescription) wearing: \(clothingList). 
        Full body shot, neutral background, professional studio lighting, 
        high fashion editorial style, ultra realistic, 8k quality.
        """
    }
    
    // MARK: - API Calls
    
    private func callStabilityAPI(prompt: String) async throws -> Data {
        guard let url = URL(string: AppConfig.stabilityEndpoint) else {
            throw StylistError.invalidEndpoint
        }
        
        // Build request body for Stability AI
        let requestBody: [String: Any] = [
            "text_prompts": [
                [
                    "text": prompt,
                    "weight": 1
                ],
                [
                    "text": "blurry, distorted, low quality, cartoon, illustration, deformed",
                    "weight": -1
                ]
            ],
            "cfg_scale": 7,
            "height": 1024,
            "width": 1024,
            "samples": 1,
            "steps": 30
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
        // Construct the request URL
        guard let url = URL(string: AppConfig.imagenEndpoint) else {
            throw StylistError.invalidEndpoint
        }
        
        // Build request body
        let requestBody: [String: Any] = [
            "instances": [
                [
                    "prompt": prompt
                ]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "3:4",
                "outputImageWidth": 1024,
                "negativePrompt": "blurry, distorted, low quality, cartoon, illustration",
                "personGeneration": "allow_adult"
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw StylistError.invalidRequest
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.googleAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StylistError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let firstPrediction = predictions.first,
              let bytesBase64Encoded = firstPrediction["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: bytesBase64Encoded) else {
            throw StylistError.invalidResponse
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
