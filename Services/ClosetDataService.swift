// ClosetDataService.swift
// Orchestrates data operations between SwiftData and File Storage

import Foundation
import SwiftData
import UIKit

@MainActor
class ClosetDataService {
    static let shared = ClosetDataService()
    
    private let imageStorage = ImageStorageService.shared
    
    private init() {}
    
    /// Adds a new clothing item to the closet, saving the image and persisting to database
    func addItem(
        name: String,
        category: Category,
        image: UIImage,
        brand: String? = nil,
        size: String? = nil,
        tags: [String] = [],
        context: ModelContext
    ) async throws {
        // 1. Save image to disk (async to avoid blocking main thread)
        guard let imageID = await imageStorage.saveImage(image) else {
            throw DataError.imageSaveFailed
        }
        
        // 2. Create model
        let item = ClothingItem(
            name: name,
            category: category,
            brand: brand,
            size: size,
            imageID: imageID,
            tags: tags
        )
        
        // 3. Insert (save happens in batch or immediately based on caller)
        context.insert(item)
    }
    
    /// Updates an existing item and its image if provided
    func updateItem(
        _ item: ClothingItem,
        name: String,
        category: Category?,
        newImage: UIImage? = nil,
        brand: String?,
        size: String?,
        tags: [String],
        context: ModelContext
    ) throws {
        item.name = name
        item.category = category
        item.brand = brand
        item.size = size
        item.tags = tags
        
        if let image = newImage {
            // Remove old image
            imageStorage.deleteImage(withID: item.imageID)
            
            // Save new image
            if let newID = imageStorage.saveImage(image) {
                item.imageID = newID
            } else {
                throw DataError.imageSaveFailed
            }
        }
        
        try context.save()
    }
    
    /// Removes an item and its associated image
    func deleteItem(_ item: ClothingItem, context: ModelContext) throws {
        imageStorage.deleteImage(withID: item.imageID)
        context.delete(item)
        try context.save()
    }
    
    
    /// Seeds default data like Categories if they don't exist
    @MainActor
    func seedInitialData(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = try context.fetch(descriptor)
        
        if existingCategories.isEmpty {
            let defaultCategories = ["Tops", "Bottoms", "Outerwear", "Shoes", "Accessories"]
            for (index, name) in defaultCategories.enumerated() {
                let category = Category(name: name, displayOrder: index)
                context.insert(category)
            }
            try context.save()
        }
    }
    
    enum DataError: Error, LocalizedError {
        case imageSaveFailed
        case persistentStoreError
        
        var errorDescription: String? {
            switch self {
            case .imageSaveFailed: return "Failed to save image to disk."
            case .persistentStoreError: return "Failed to save changes to the database."
            }
        }
    }
}
