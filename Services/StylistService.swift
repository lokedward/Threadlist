// StylistService.swift
// AI styling using Gemini 2.0 Flash for both vision and image generation

import Foundation
import SwiftUI
internal import Combine

@MainActor
class StylistService {
    static let shared = StylistService()
    private init() {}
    
    // Limit checks are now handled via SubscriptionService.shared
    var generationsRemaining: Int? {
        let limit = SubscriptionService.shared.currentTier.styleMeLimit
        return max(0, limit - SubscriptionService.shared.generationCount)
    }
    
    // MARK: - Magic Fill (Metadata Enrichment)
    
    struct GarmentMetadata: Codable {
        let name: String
        let brand: String?
        let size: String?
        let category: String
        let tags: [String]
    }
    
    func enrichMetadata(image: UIImage) async throws -> GarmentMetadata? {
        // Optimization: Resize image to 512px max dimension to reduce network latency
        let resizedImage = resizeImage(image, targetSize: CGSize(width: 512, height: 512))
        
        guard let data = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw StylistError.invalidImageData
        }
        
        // Define the categories we support to help Gemini categorize accurately
        let knownCategories = ["Tops", "Bottoms", "Outerwear", "Shoes", "Accessories"]
        
        let prompt = """
        IDENTIFY CLOTHING: Check if this photo contains a clear clothing item.
        
        IF NO CLOTHING DETECTED: Return exactly the text "NONE".
        
        IF CLOTHING DETECTED: Return only a valid JSON object:
        - "name": Brief, professional name (e.g. "Charcoal Wool Blazer")
        - "brand": Brand name if visible, otherwise null
        - "size": Size if visible, otherwise null
        - "category": Exactly one of: \(knownCategories.joined(separator: ", "))
        - "tags": 3-4 descriptive, unique keywords (1-2 words each). Focus on:
          1. Textile details (e.g. "twill", "heavyweight", "ribbed")
          2. Aesthetic DNA (e.g. "dark academia", "gorpcore", "minimalist")
          3. Technical features (e.g. "water-resistant", "raw-hem")
          IMPORTANT: Values MUST BE strictly unique from words used in the "name".
        
        NO PREAMBLE. NO MARKDOWN.
        """
        
        let jsonString = try await callGemini(model: "gemini-2.0-flash", prompt: prompt, images: [data], responseType: .text)
        
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "NONE" {
            return nil
        }
        
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
    
    // Helper to resize image for faster transmission
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // MARK: - Occasion-Based Selection
    
    func suggestOutfit(for occasion: String, availableItems: [ClothingItem]) async throws -> (Set<UUID>, String) {
        guard !availableItems.isEmpty else { return ([], "") }
        
        // 1. Prepare Wardrobe Summary
        let itemsInfo = availableItems.map { item in
            """
            - [ID: \(item.id.uuidString)]
              Name: \(item.name)
              Category: \(item.category?.name ?? "Unknown")
              Brand: \(item.brand ?? "N/A")
              Tags: \(item.tags.joined(separator: ", "))
            """
        }.joined(separator: "\n")
        
        // 2. Fetch Active Session Parameters
        let vibe = UserDefaults.standard.string(forKey: "stylistStyleVibe") ?? StyleVibe.timeless.rawValue
        let density = UserDefaults.standard.string(forKey: "stylistDensity") ?? StylingDensity.balanced.rawValue
        let mood = UserDefaults.standard.string(forKey: "stylistMood") ?? ""
        
        // 3. Build Prompt
        let timestamp = Date().timeIntervalSince1970
        let prompt = """
        You are a high-end personal stylist for a premium fashion app.
        
        GOAL: Pick the BEST outfit from the user's closet and provide a technical visual description for an image generator.
        
        TARGET PARAMETERS:
        - Occasion: \(occasion)
        - Desired Vibe: \(vibe)
        - Styling Complexity: \(density)
        \(mood.isEmpty ? "" : "- Additional Mood/Inspiration: \(mood)")
        
        USER CLOSET:
        \(itemsInfo)
        
        INSTRUCTIONS:
        1. Select a complete look: one top, one bottom, one pair of shoes, and optional accessory/outerwear if density allows.
        2. Strictly follow the density: "Minimalist" means fewer basics; "Layered" means more accessories and outerwear.
        3. IMPORTANT: Provide VARIETY. If called multiple times for the same occasion, suggest DIFFERENT combinations. Be creative and explore various aesthetics from the available items.
        4. Output only a JSON object:
        {
          "ids": ["UUID-1", "UUID-2"],
          "explanation": "A very brief (1 sentence) stylish explanation of why this look fits the requested vibe and occasion.",
          "visual_description": "A highly detailed visual description of the combined look. Describe the specific fabrics (e.g., 'heavyweight cotton', 'merino wool'), colors, textures, and fit (e.g. 'oversized', 'tapered') of the selected items as they would appear together. This is for a photorealistic image generator."
        }
        
        Randomization seed: \(timestamp)
        
        Return pure JSON only. NO MARKDOWN.
        """
        
        let response = try await callGemini(model: "gemini-2.5-flash", prompt: prompt, images: nil, responseType: .text)
        
        // 4. Parse Response
        let cleanedJSON = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw StylistError.invalidResponse
        }
        
        struct SuggestionResponse: Codable {
            let ids: [String]
            let explanation: String
            let visual_description: String
        }
        
        let decoded = try JSONDecoder().decode(SuggestionResponse.self, from: jsonData)
        let uuids = decoded.ids.compactMap { UUID(uuidString: $0) }
        
        return (Set(uuids), decoded.visual_description)
    }
    
    // MARK: - Core Pipeline
    
    func generateModelPhoto(items: [ClothingItem], gender: Gender, preComputedDescription: String? = nil) async throws -> UIImage {
        guard !items.isEmpty else { throw StylistError.noItemsSelected }
        
        // Check usage limits
        if !SubscriptionService.shared.canPerformStyleMe() {
            let tier = SubscriptionService.shared.currentTier
            throw StylistError.limitReached(limit: tier.styleMeLimit, period: tier.limitPeriod == .monthly ? "monthly" : "daily")
        }
        
        // 1. Prepare Images (Only if needed for analysis)
        func getGarmentImages() async -> [Data] {
            var images: [Data] = []
            for item in items {
                if let img = await ImageStorageService.shared.loadImage(withID: item.imageID),
                   let data = img.jpegData(compressionQuality: 0.7) {
                    images.append(data)
                }
            }
            return images
        }
        
        // 2. Cache Check: Do we already have this exact outfit?
        if let cachedImage = OutfitCacheService.shared.getCachedImage(for: items, gender: gender) {
            print("🚀 Outfit Cache Hit! Returning stored image.")
            return cachedImage
        }
        
        // 3. Step A: Vision Analysis or use Pre-computed Description
        let description: String
        if let preComputed = preComputedDescription {
            print("✨ Using pre-computed description. Skipping Vision step.")
            description = preComputed
            OutfitCacheService.shared.cacheDescription(description, for: items, gender: gender)
        } else if let cachedDesc = OutfitCacheService.shared.getCachedDescription(for: items, gender: gender) {
            print("📝 Description Cache Hit.")
            description = cachedDesc
        } else {
            let garmentImages = await getGarmentImages()
            guard !garmentImages.isEmpty else { throw StylistError.invalidImageData }
            
            // Optimization: Resize images to 512px max for analysis to reduce upload time
            var optimizedImages: [Data] = []
            for data in garmentImages {
                if let img = UIImage(data: data) {
                    let resized = resizeImage(img, targetSize: CGSize(width: 512, height: 512))
                    if let resizedData = resized.jpegData(compressionQuality: 0.6) {
                        optimizedImages.append(resizedData)
                    }
                }
            }
            
            description = try await analyzeGarments(images: optimizedImages.isEmpty ? garmentImages : optimizedImages)
            OutfitCacheService.shared.cacheDescription(description, for: items, gender: gender)
        }
        
        // 4. Step B: Image Generation (Gemini 2.5 Flash Image)
        do {
            let resultImage = try await generateImage(description: description, gender: gender)
            
            // Cache the final result
            OutfitCacheService.shared.cacheImage(resultImage, for: items, gender: gender)
            
            SubscriptionService.shared.recordGeneration()
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
    
    // New Parameters
    @AppStorage("stylistAgeGroup") private var ageGroupRaw = ModelAgeGroup.millennial.rawValue
    @AppStorage("stylistHairColor") private var hairColorRaw = ModelHairColor.brown.rawValue
    @AppStorage("stylistHairStyle") private var hairStyleRaw = ModelHairStyle.wavy.rawValue
    @AppStorage("stylistEnvironment") private var environmentRaw = ModelEnvironment.studio.rawValue
    @AppStorage("stylistFraming") private var framingRaw = ModelFraming.neckDown.rawValue
    
    private func generateImage(description: String, gender: Gender) async throws -> UIImage {
        let model = "gemini-2.5-flash-image"
        
        // Retrieve settings
        let bodyType = ModelBodyType(rawValue: bodyTypeRaw) ?? .slim
        let skinTone = SkinTone(rawValue: skinToneRaw) ?? .medium
        let height = ModelHeight(rawValue: heightRaw) ?? .average
        let ageGroup = ModelAgeGroup(rawValue: ageGroupRaw) ?? .millennial
        
        let hairColor = ModelHairColor(rawValue: hairColorRaw) ?? .brown
        let hairStyle = ModelHairStyle(rawValue: hairStyleRaw) ?? .wavy
        let environment = ModelEnvironment(rawValue: environmentRaw) ?? .studio
        let framing = ModelFraming(rawValue: framingRaw) ?? .neckDown
        
        let genderStr = gender == .male ? "male" : "female"
        
        let fullPrompt = """
        <IMAGE_GENERATION_REQUEST>
        Editorial fashion photography\(framing.promptDescription) shot
        Model: \(ageGroup.promptDescription) \(height.promptDescription) \(genderStr) model, \(skinTone.promptDescription), \(bodyType.promptDescription).
        Hair: \(hairColor.rawValue) \(hairStyle.rawValue) hair.
        Outfit: \(description).
        Setting: \(environment.promptDescription), blurred depth of field.
        Lighting: Cinematic lighting fitting the environment, 8k, highly detailed, photorealistic.
        Safety: Strictly fashion-related. No nudity, no violence, no inappropriate content.
        
        CRITICAL INSTRUCTION:
        If the Outfit description above does NOT explicitly mention a Top (shirt, blouse, etc.), the model MUST wear a highly detailed plain white t-shirt.
        If the Outfit description above does NOT explicitly mention a Bottom (pants, skirt, shorts, etc.), the model MUST wear highly detailed plain black shorts.
        Do not describe these default items as "missing". Just render them.
        
        Output: Raw image bytes.
        </IMAGE_GENERATION_REQUEST>
        """
        
        print("🎨 [Cost Optimization] Generating with settings: \(genderStr), \(ageGroup.rawValue), \(environment.rawValue)...")
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
            SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE")
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
    case limitReached(limit: Int, period: String)
    
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
        case .limitReached(let limit, let period):
            return "You've reached your \(period) limit of \(limit) outfits. Upgrade for more looks!"
        }
    }
}
