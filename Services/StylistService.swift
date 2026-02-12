// StylistService.swift
// AI styling using Gemini 2.0 Flash for both vision and image generation

import Foundation
import SwiftUI
internal import Combine

class StylistService {
    static let shared = StylistService()
    private init() {}
    
    // MARK: - Usage Tracking
    @AppStorage("dailyGenerationCount") private var dailyGenerationCount: Int = 0
    @AppStorage("lastResetDate") private var lastResetDate: String = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"
    
    var userTier: GenerationTier {
        get { userTierRaw == "premium" ? .premium : .free }
        set { userTierRaw = newValue == .premium ? "premium" : "free" }
    }
    
    var generationsRemaining: Int? {
        let limit = userTier == .premium ? 50 : 3
        resetCountIfNeeded()
        return max(0, limit - dailyGenerationCount)
    }
    
    // MARK: - Core Pipeline
    
    func generateModelPhoto(items: [ClothingItem], gender: Gender) async throws -> UIImage {
        guard !items.isEmpty else { throw StylistError.noItemsSelected }
        
        // Check usage limits
        if let remaining = generationsRemaining, remaining <= 0 {
            throw StylistError.limitReached
        }
        
        // 1. Prepare Images
        var garmentImages: [Data] = []
        for item in items {
            if let img = ImageStorageService.shared.loadImage(withID: item.imageID),
               let data = img.jpegData(compressionQuality: 0.7) {
                garmentImages.append(data)
            }
        }
        guard !garmentImages.isEmpty else { throw StylistError.invalidImageData }
        
        // 2. Cache Check: Do we already have this exact outfit?
        if let cachedImage = OutfitCacheService.shared.getCachedImage(for: items, gender: gender) {
            print("🚀 Outfit Cache Hit! Returning stored image.")
            return cachedImage
        }
        
        // 3. Step A: Vision Analysis (Gemini 2.5 Flash)
        let description: String
        if let cachedDesc = OutfitCacheService.shared.getCachedDescription(for: items, gender: gender) {
            print("📝 Description Cache Hit.")
            description = cachedDesc
        } else {
            description = try await analyzeGarments(images: garmentImages)
            OutfitCacheService.shared.cacheDescription(description, for: items, gender: gender)
        }
        
        // 4. Step B: Image Generation (Gemini 2.5 Flash Image)
        let resultImage = try await generateImage(description: description, gender: gender)
        
        // Cache the final result
        OutfitCacheService.shared.cacheImage(resultImage, for: items, gender: gender)
        
        incrementGenerationCount()
        return resultImage
    }
    
    private func analyzeGarments(images: [Data]) async throws -> String {
        let model = "gemini-2.5-flash" 
        
        let prompt = """
        Output a detailed visual description of these clothes as a single outfit. 
        Focus: fabrics, textures, colors, fit, necklines. 
        Exclude: backgrounds, people, hangers. 
        Format: Direct descriptive text for an image generator.
        """
        
        print("🔍 [Cost Optimization] Analyzing with tighter prompt...")
        return try await callGemini(model: model, prompt: prompt, images: images, responseType: .text)
    }
    
    private func generateImage(description: String, gender: Gender) async throws -> UIImage {
        let model = "gemini-2.5-flash-image" 
        let modelType = gender == .male ? "male" : "female"
        
        let fullPrompt = """
        <IMAGE_GENERATION_REQUEST>
        Editorial neck down fashion photo, 5'6" Asian slim \(modelType) model.
        Outfit: \(description).
        Studio lighting, neutral grey background, 8k, highly detailed.
        Output: Raw image bytes.
        </IMAGE_GENERATION_REQUEST>
        """
        
        print("🎨 [Cost Optimization] Generating with concise prompt...")
        let base64String = try await callGemini(model: model, prompt: fullPrompt, images: nil, responseType: .image)
        
        guard let data = Data(base64Encoded: base64String), let image = UIImage(data: data) else {
            throw StylistError.invalidImageData
        }
        return image
    }
    
    // MARK: - Universal API Caller (Gemini 2.0 Flash)
    
    private enum ResponseType { case text, image }
    
    private func callGemini(model: String, prompt: String, images: [Data]?, responseType: ResponseType) async throws -> String {
        // Use the latest flash model which supports image generation
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(AppConfig.googleAPIKey)"
        
        guard let url = URL(string: urlString) else { throw StylistError.invalidEndpoint }
        
        // Construct Request
        var parts: [[String: Any]] = [ ["text": prompt] ]
        
        if let images = images {
            for imgData in images {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": imgData.base64EncodedString()
                    ]
                ])
            }
        }
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": parts
                ]
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"]
            ]
        ]
        
        // If we expect an image, try to force it via generationConfig
        // NOTE: We avoid response_mime_type = 'image/jpeg' here as it causes 400 errors.
        if responseType == .image {
            requestBody["generationConfig"] = [
                "candidate_count": 1
            ]
        }
        
        // Note: Gemini 2.0 Flash generates images natively when prompted.
        // We do NOT use response_mime_type = "image/jpeg" because that field is for the overall response wrapper (text/json/etc).
        // The image will be returned as a part within the 'inline_data' multimodal response.
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🛡️ Add Bundle ID header to satisfy Google Cloud restrictions
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse else { throw StylistError.invalidResponse }
        
        if httpResp.statusCode != 200 {
            print("Gemini API Error (\(httpResp.statusCode)): \(String(data: data, encoding: .utf8) ?? "Unknown")")
            throw StylistError.apiError("Generation failed (Status \(httpResp.statusCode))")
        }
        
        // Parse Response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let partsResp = content["parts"] as? [[String: Any]] else {
            throw StylistError.invalidResponse
        }
        
        if responseType == .text {
            // Join all text parts if multiple exist
            let textParts = partsResp.compactMap { $0["text"] as? String }
            return textParts.joined(separator: "\n")
        } else {
            // Search all parts for image data (handles both snake_case and camelCase)
            for part in partsResp {
                let inlineData = (part["inline_data"] ?? part["inlineData"]) as? [String: Any]
                if let b64 = inlineData?["data"] as? String {
                    return b64
                }
            }
            
            // Fallback: If no image pixels, check if the model gave a refusal message
            let textOutput = partsResp.compactMap { $0["text"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !textOutput.isEmpty {
                throw StylistError.apiError("Generation refused: \(textOutput)")
            }
            
            throw StylistError.apiError("No image data returned")
        }
    }
    
    // MARK: - Helpers
    
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
            return "Generation API misconfigured"
        case .invalidRequest:
            return "Failed to create generation request"
        case .invalidResponse:
            return "Invalid response from outfit generator"
        case .apiError(let message):
            return message
        case .limitReached:
            return "You've reached your daily limit of 3 outfits. Upgrade to Premium for unlimited looks!"
        }
    }
}
