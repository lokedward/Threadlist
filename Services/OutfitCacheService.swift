import Foundation
import UIKit
import CryptoKit

/// Handles local caching of AI-generated outfit data to reduce API costs and improve UX
class OutfitCacheService {
    static let shared = OutfitCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let descriptionsFile: URL
    
    // In-memory description cache for speed
    private var descriptionCache: [String: String] = [:]
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("OutfitCache", isDirectory: true)
        descriptionsFile = cacheDirectory.appendingPathComponent("descriptions.json")
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        loadDescriptions()
    }
    
    // MARK: - Key Generation
    
    /// Generates a unique, stable hash key for a specific combination of items and gender (for Descriptions)
    func generateKey(for items: [ClothingItem], gender: Gender) -> String {
        let sortedIDs = items.map { $0.id.uuidString }.sorted()
        let genderStr = gender == .male ? "male" : "female"
        let rawKey = "\(sortedIDs.joined(separator: ","))_\(genderStr)"
        
        let inputData = Data(rawKey.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generates a specific key for the final image, including all model settings (Skin, Hair, etc.)
    func generateImageKey(for items: [ClothingItem], gender: Gender) -> String {
        let baseKey = generateKey(for: items, gender: gender)
        
        let defaults = UserDefaults.standard
        let settings = [
            defaults.string(forKey: "stylistBodyType") ?? "",
            defaults.string(forKey: "stylistSkinTone") ?? "",
            defaults.string(forKey: "stylistModelHeight") ?? "",
            defaults.string(forKey: "stylistAgeGroup") ?? "",
            defaults.string(forKey: "stylistHairColor") ?? "",
            defaults.string(forKey: "stylistHairStyle") ?? "",
            defaults.string(forKey: "stylistEnvironment") ?? "",
            defaults.string(forKey: "stylistFraming") ?? ""
        ].joined(separator: "|")
        
        let rawKey = "\(baseKey)_\(settings)"
        
        let inputData = Data(rawKey.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Description Cache
    
    func getCachedDescription(for items: [ClothingItem], gender: Gender) -> String? {
        let key = generateKey(for: items, gender: gender)
        return descriptionCache[key]
    }
    
    func cacheDescription(_ description: String, for items: [ClothingItem], gender: Gender) {
        let key = generateKey(for: items, gender: gender)
        descriptionCache[key] = description
        saveDescriptions()
    }
    
    func invalidateDescription(for items: [ClothingItem], gender: Gender) {
        let key = generateKey(for: items, gender: gender)
        descriptionCache.removeValue(forKey: key)
        saveDescriptions()
    }
    
    // MARK: - Image Cache
    
    func getCachedImage(for items: [ClothingItem], gender: Gender) -> UIImage? {
        let key = generateImageKey(for: items, gender: gender) // Use Settings-aware Key
        let filePath = cacheDirectory.appendingPathComponent("\(key).jpg")
        
        guard fileManager.fileExists(atPath: filePath.path),
              let data = try? Data(contentsOf: filePath) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func cacheImage(_ image: UIImage, for items: [ClothingItem], gender: Gender) {
        let key = generateImageKey(for: items, gender: gender) // Use Settings-aware Key
        let filePath = cacheDirectory.appendingPathComponent("\(key).jpg")
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: filePath)
        }
    }
    
    // MARK: - Persistence
    
    private func loadDescriptions() {
        guard fileManager.fileExists(atPath: descriptionsFile.path),
              let data = try? Data(contentsOf: descriptionsFile),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        self.descriptionCache = decoded
    }
    
    private func saveDescriptions() {
        if let data = try? JSONEncoder().encode(descriptionCache) {
            try? data.write(to: descriptionsFile)
        }
    }
    
    func clearCache() {
        descriptionCache.removeAll()
        saveDescriptions()
        
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
