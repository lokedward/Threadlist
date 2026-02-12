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
    
    // MARK: - AI Generation (Two-Step Pipeline)
    
    /// Generate a cohesive outfit photo using Gemini Vision for analysis and Imagen for generation
    func generateModelPhoto(items: [ClothingItem], gender: Gender) async throws -> UIImage {
        guard !items.isEmpty else { throw StylistError.noItemsSelected }
        
        // Check usage limits
        if let remaining = generationsRemaining, remaining <= 0 {
            throw StylistError.limitReached
        }
        
        // 1. Prepare Image Data for Vision Analysis
        var imageParts: [Data] = []
        for item in items {
            if let image = ImageStorageService.shared.loadImage(withID: item.imageID),
               let jpegData = image.jpegData(compressionQuality: 0.8) {
                imageParts.append(jpegData)
            }
        }
        
        guard !imageParts.isEmpty else { throw StylistError.invalidImageData }
        
        // 2. Step 1: Vision Analysis (Gemini 1.5 Pro)
        let visionPrompt = """
        Analyze these clothing items. Create a single, highly detailed visual description suitable for an AI image generator. 
        Focus on specific fabrics, textures, necklines, sleeve lengths, patterns, and fit. 
        Do not describe the background or any person. Just describe the clothes as if worn together.
        """
        
        let garmentDescription = try await callGeminiVision(prompt: visionPrompt, images: imageParts)
        
        // 3. Step 2: Image Generation (Imagen 3)
        let modelDescription = "generic 5'6\" \(gender == .female ? "female" : "male") fashion model"
        let fullPrompt = """
        Professional full-body editorial studio photography of a \(modelDescription) wearing: \(garmentDescription).
        
        The model is standing in a neutral pose against a soft grey studio background. 
        Lighting is cinematic and soft. 8k resolution, photorealistic, highly detailed texture.
        """
        
        let generatedImageData = try await callGeminiImagen(prompt: fullPrompt)
        
        guard let image = UIImage(data: generatedImageData) else {
            throw StylistError.invalidImageData
        }
        
        incrementGenerationCount()
        return image
    }
    
    // MARK: - Private API Callers
    
    /// Step 1: The Eye (Gemini 1.5 Pro) - Analyzes images to create description
    private func callGeminiVision(prompt: String, images: [Data]) async throws -> String {
        let model = "gemini-1.5-pro"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(AppConfig.googleAPIKey)"
        guard let url = URL(string: urlString) else { throw StylistError.invalidEndpoint }
        
        // Construct Multipart Content (Text + Images)
        var parts: [[String: Any]] = [
            ["text": prompt]
        ]
        
        for imageData in images {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": parts]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🛡️ Add Bundle ID header to satisfy Google Cloud restrictions
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            print("Vision Error: \(String(data: data, encoding: .utf8) ?? "Unknown")")
            throw StylistError.apiError("Vision API Failed: \( (response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        // Parse the text response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let partsResponse = content["parts"] as? [[String: Any]],
              let text = partsResponse.first?["text"] as? String else {
            throw StylistError.invalidResponse
        }
        
        return text
    }
    
    /// Step 2: The Brush (Imagen 3) - Generates photo from description
    private func callGeminiImagen(prompt: String) async throws -> Data {
        let model = "imagen-3.0-generate-001"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):predict?key=\(AppConfig.googleAPIKey)"
        
        guard let url = URL(string: urlString) else { throw StylistError.invalidEndpoint }
        
        let body: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "3:4"
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🛡️ Add Bundle ID header to satisfy Google Cloud restrictions
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            print("Imagen Error: \(String(data: data, encoding: .utf8) ?? "Unknown")")
            throw StylistError.apiError("Image Generation Failed: \( (response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        // Parse Base64 Image Response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let first = predictions.first,
              let b64 = first["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: b64) else {
            throw StylistError.invalidImageData
        }
        
        return imageData
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
