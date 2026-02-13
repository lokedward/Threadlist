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
        let limit = userTier == .premium ? 50 : 10
        resetCountIfNeeded()
        return max(0, limit - dailyGenerationCount)
    }
    
    // MARK: - Magic Fill (Metadata Enrichment)
    
    struct GarmentMetadata: Codable {
        let name: String
        let brand: String?
        let size: String?
        let category: String
        let tags: [String]
    }
    
    func enrichMetadata(image: UIImage) async throws -> GarmentMetadata {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw StylistError.invalidImageData
        }
        
        // Define the categories we support to help Gemini categorize accurately
        let knownCategories = ["Tops", "Bottoms", "Outerwear", "Shoes", "Accessories"]
        
        let prompt = """
        Accurately identify this clothing item for a high-end fashion app.
        Be professional and concise.
        
        Output only a valid JSON object:
        - "name": Brief, professional name (e.g. "Charcoal Wool Blazer", not "A very nice blazer")
        - "brand": Brand name if clearly visible on labels/logos, otherwise null
        - "size": Size if clearly visible on tags, otherwise null
        - "category": Categorize as exactly one of: \(knownCategories.joined(separator: ", "))
        - "tags": 3-5 high-quality descriptive keywords (fabric, style, occasion)
        
        Return PURE JSON. No descriptions.
        """
        
        let jsonString = try await callGemini(model: "gemini-2.5-flash", prompt: prompt, images: [data], responseType: .text)
        
        // Clean the response string if Gemini wrapped it in markdown code blocks
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw StylistError.invalidResponse
        }
        
        return try JSONDecoder().decode(GarmentMetadata.self, from: jsonData)
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
            if let img = await ImageStorageService.shared.loadImage(withID: item.imageID),
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
        do {
            let resultImage = try await generateImage(description: description, gender: gender)
            
            // Cache the final result
            OutfitCacheService.shared.cacheImage(resultImage, for: items, gender: gender)
            
            incrementGenerationCount()
            return resultImage
        } catch {
            print("❌ Image generation failed with error: \(error.localizedDescription)")
            print("⚠️ Invalidating cached description to force regeneration next time.")
            OutfitCacheService.shared.invalidateDescription(for: items, gender: gender)
            throw error
        }
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
    
    // MARK: - App Storage for Stylist Settings
    
    @AppStorage("stylistModelGender") private var genderRaw = "female"
    @AppStorage("stylistBodyType") private var bodyTypeRaw = ModelBodyType.slim.rawValue
    @AppStorage("stylistSkinTone") private var skinToneRaw = SkinTone.medium.rawValue
    @AppStorage("stylistModelHeight") private var heightRaw = ModelHeight.average.rawValue
    
    private func generateImage(description: String, gender: Gender) async throws -> UIImage {
        let model = "gemini-2.5-flash-image"
        
        // Retrieve settings
        let bodyType = ModelBodyType(rawValue: bodyTypeRaw) ?? .slim
        let skinTone = SkinTone(rawValue: skinToneRaw) ?? .medium
        let height = ModelHeight(rawValue: heightRaw) ?? .average
        
        let genderStr = gender == .male ? "male" : "female"
        
        let fullPrompt = """
        <IMAGE_GENERATION_REQUEST>
        Editorial neck down fashion photo.
        Model: \(height.promptDescription) \(genderStr) model, \(skinTone.promptDescription), \(bodyType.promptDescription).
        Outfit: \(description).
        Studio lighting, neutral grey background, 8k, highly detailed, photorealistic.
        Output: Raw image bytes.
        </IMAGE_GENERATION_REQUEST>
        """
        
        print("🎨 [Cost Optimization] Generating with settings: \(genderStr), \(bodyType.rawValue), \(skinTone.rawValue), \(height.rawValue)...")
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
        var parts: [Part] = [Part(text: prompt)]
        
        if let images = images {
            for imgData in images {
                parts.append(Part(inlineData: InlineData(mimeType: "image/jpeg", data: imgData.base64EncodedString())))
            }
        }
        
        let content = Content(role: "user", parts: parts)
        
        let safetySettings = [
            SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE"),
            SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE"),
            SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE"),
            SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE")
        ]
        
        // Note: For image generation, we request 1 candidate. 
        // We do *NOT* set responseMimeType to "image/jpeg" here because that wrapper is for the whole response, 
        // and Gemini Flash returns multimodal parts (text + inline_data).
        let generationConfig: GenerationConfig? = (responseType == .image) ?
            GenerationConfig(candidateCount: 1, responseMimeType: nil) : nil
        
        let requestBody = GeminiRequest(
            contents: [content],
            safetySettings: safetySettings,
            generationConfig: generationConfig
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🛡️ Add Bundle ID header to satisfy Google Cloud restrictions
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse else { throw StylistError.invalidResponse }
        
        if httpResp.statusCode != 200 {
            print("Gemini API Error (\(httpResp.statusCode)): \(String(data: data, encoding: .utf8) ?? "Unknown")")
            throw StylistError.apiError("Generation failed (Status \(httpResp.statusCode))")
        }
        
        // Debug: Log response for troubleshooting
        if let jsonString = String(data: data, encoding: .utf8) {
             print("GEMINI RAW RESPONSE: \(jsonString)")
        }
        
        // Parse Response
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let candidate = geminiResponse.candidates?.first,
              let content = candidate.content,
              !content.parts.isEmpty else {
            throw StylistError.invalidResponse
        }
        
        let partsResp = content.parts
        
        if responseType == .text {
            // Join all text parts if multiple exist
            let textParts = partsResp.compactMap { $0.text }
            return textParts.joined(separator: "\n")
        } else {
            // Search all parts for image data
            for part in partsResp {
                if let b64 = part.inlineData?.data {
                    return b64
                }
            }
            
            // Fallback: If no image pixels, check if the model gave a refusal message
            let textOutput = partsResp.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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



// MARK: - Gemini Codable Types

private struct GeminiRequest: Codable {
    let contents: [Content]
    let safetySettings: [SafetySetting]?
    let generationConfig: GenerationConfig?
    
    enum CodingKeys: String, CodingKey {
        case contents
        case safetySettings = "safety_settings"
        case generationConfig = "generation_config"
    }
}

private struct Content: Codable {
    let role: String?
    let parts: [Part]
}

private struct Part: Codable {
    var text: String? = nil
    var inlineData: InlineData? = nil
    
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
        case inlineDataCamel = "inlineData"
    }
    
    init(text: String? = nil, inlineData: InlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }
    
    // Custom decoding to support both snake_case (API standard) and camelCase (occasional)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        
        if let data = try container.decodeIfPresent(InlineData.self, forKey: .inlineData) {
            self.inlineData = data
        } else if let data = try container.decodeIfPresent(InlineData.self, forKey: .inlineDataCamel) {
            self.inlineData = data
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(inlineData, forKey: .inlineData)
    }
}

private struct InlineData: Codable {
    let mimeType: String?
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case mimeTypeCamel = "mimeType"
        case data
    }
    
    init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(String.self, forKey: .data)
        
        // Try both keys for mime type
        if let mime = try container.decodeIfPresent(String.self, forKey: .mimeType) {
            self.mimeType = mime
        } else {
            self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeTypeCamel)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
    }
}

private struct SafetySetting: Codable {
    let category: String
    let threshold: String
}

private struct GenerationConfig: Codable {
    let candidateCount: Int?
    let responseMimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case candidateCount = "candidate_count"
        case responseMimeType = "response_mime_type"
    }
}

private struct GeminiResponse: Codable {
    let candidates: [Candidate]?
}

private struct Candidate: Codable {
    let content: Content?
    let finishReason: String?
    let safetyRatings: [SafetyRating]?
    
    enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finish_reason"
        case safetyRatings = "safety_ratings"
    }
}

private struct SafetyRating: Codable {
    let category: String
    let probability: String
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
            return "You've reached your daily limit of 10 outfits. Upgrade to Premium for unlimited looks!"
        }
    }
}
