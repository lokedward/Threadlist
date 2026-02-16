// ImageStorageService.swift
// Handles saving/loading images to/from the Documents directory

import Foundation
import UIKit

class ImageStorageService {
    static let shared = ImageStorageService()
    
    private let fileManager = FileManager.default
    private let imageDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.threaddit.imagestorage", qos: .userInitiated)
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = documentsPath.appendingPathComponent("ClothingImages", isDirectory: true)
        
        // Config cache limits
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
        
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: imageDirectory.path) {
            try? fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Save an image with compression and return the UUID (Async version for performance)
    func saveImage(_ image: UIImage, withID id: UUID = UUID()) async -> UUID? {
        // Cache immediately on calling thread
        cache.setObject(image, forKey: id.uuidString as NSString)
        
        return await withCheckedContinuation { continuation in
            ioQueue.async {
                // Perform compression on background queue
                guard let data = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fileURL = self.imageDirectory.appendingPathComponent("\(id.uuidString).jpg")
                try? data.write(to: fileURL)
                continuation.resume(returning: id)
            }
        }
    }
    
    /// Save an image with compression and return the UUID (Legacy sync version)
    func saveImage(_ image: UIImage, withID id: UUID = UUID()) -> UUID? {
        // Cache immediately
        cache.setObject(image, forKey: id.uuidString as NSString)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        let fileURL = imageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        ioQueue.async {
            try? data.write(to: fileURL)
        }
        return id
    }
    
    /// Load an image by its UUID (Async)
    func loadImage(withID id: UUID) async -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            ioQueue.async {
                let fileURL = self.imageDirectory.appendingPathComponent("\(id.uuidString).jpg")
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    // Cache and return
                    self.cache.setObject(image, forKey: key)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Load an image by its UUID (Legacy Sync for compatibility)
    func loadImage(withID id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let fileURL = imageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        cache.setObject(image, forKey: key)
        return image
    }
    
    /// Delete an image by its UUID
    func deleteImage(withID id: UUID) {
        let key = id.uuidString as NSString
        cache.removeObject(forKey: key)
        
        let fileURL = imageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Get all image file URLs (for export)
    func getAllImageURLs() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents.filter { $0.pathExtension == "jpg" }
    }
}
