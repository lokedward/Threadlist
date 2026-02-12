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
        
        // 2. Step A: Vision Analysis (Gemini 2.0 Flash)
        let description = try await analyzeGarments(images: garmentImages)
        
        // 3. Step B: Image Generation (Gemini 2.0 Flash)
        let resultImage = try await generateImage(description: description, gender: gender)
        
        incrementGenerationCount()
        return resultImage
    }
    
    // MARK: - Step A: Vision (See the Clothes)
    private func analyzeGarments(images: [Data]) async throws -> String {
        // 1. Use the STANDARD Flash model for text analysis
        // This model is optimized for vision-to-text input/output
        let model = "gemini-2.5-flash" 
        
        let prompt = """
        Analyze these clothing items images. Create a single, highly detailed visual description suitable for an AI image generator.
        Focus on fabrics, textures, exact colors, necklines, sleeve lengths, and fit.
        Do not describe the background, hangers, or any person. Just describe the clothes as if worn together as an outfit.
        Ensure the description is cohesive and ready to be used as a prompt for generating an image of a model wearing these exact items.
        """
        
        // Response Type is .text
        return try await callGemini(model: model, prompt: prompt, images: images, responseType: .text)
    }
    
    // MARK: - Step B: Generation (Create the Look)
    private func generateImage(description: String, gender: Gender) async throws -> UIImage {
        // 2. Use the IMAGE specific model for generation
        // If you use the standard model here, it will just return text!
        let model = "gemini-2.5-flash-image" 
        
        let fullPrompt = """
        Generate a photorealistic, full-body editorial fashion photograph of a 5'6" Asian slim female model.
        The model is wearing this specific outfit: \(description).
        
        Setting: Neutral grey studio background.
        Lighting: Soft, cinematic, professional studio lighting.
        Style: 8k resolution, highly detailed texture, realistic proportions.
        """
        
        // Response Type is .image
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
        if responseType == .image {
            requestBody["generationConfig"] = [
                "response_mime_type": "image/jpeg"
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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let rawString = String(data: data, encoding: .utf8) {
                print("❌ Failed to parse JSON. Raw response: \(rawString)")
            }
            throw StylistError.invalidResponse
        }
        
        // DEBUG: Log the full response to help diagnose missing image data
        if let dataString = String(data: data, encoding: .utf8) {
            print("💎 RAW GEMINI RESPONSE: \(dataString)")
        }
        
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first else {
            print("❌ No candidates in Gemini response: \(json)")
            if let promptFeedback = json["promptFeedback"] as? [String: Any] {
                print("⚠️ Prompt Feedback: \(promptFeedback)")
            }
            throw StylistError.invalidResponse
        }
        
        guard let content = firstCandidate["content"] as? [String: Any],
              let partsResp = content["parts"] as? [[String: Any]] else {
            print("❌ Candidate content/parts missing. Candidate: \(firstCandidate)")
            if let finishReason = firstCandidate["finishReason"] as? String {
                print("⚠️ Finish Reason: \(finishReason)")
                if finishReason == "SAFETY" {
                    if let safetyRatings = firstCandidate["safetyRatings"] as? [[String: Any]] {
                        print("🛡️ Safety Ratings: \(safetyRatings)")
                    }
                    throw StylistError.apiError("Generation blocked by safety filters. Try a different outfit.")
                }
            }
            throw StylistError.invalidResponse
        }
        
        if responseType == .text {
            // Join all text parts if multiple exist
            let textParts = partsResp.compactMap { $0["text"] as? String }
            return textParts.joined(separator: "\n")
        } else {
            // Image Generation returns 'inline_data' - search all parts
            for part in partsResp {
                if let inlineData = part["inline_data"] as? [String: Any],
                   let b64 = inlineData["data"] as? String {
                    return b64
                }
            }
            
            // If no image, collect all text for debugging
            let textOutput = partsResp.compactMap { $0["text"] as? String }.joined(separator: " ")
            if !textOutput.isEmpty {
                print("⚠️ Expected Image, but only got Text: \(textOutput)")
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
