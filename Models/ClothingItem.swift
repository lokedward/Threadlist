// ClothingItem.swift
// SwiftData model for clothing items

import Foundation
import SwiftData

@Model
final class ClothingItem {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String?
    var size: String?
    var imageID: UUID = UUID()
    
    @Attribute(.externalStorage)
    var imageData: Data?
    
    var dateAdded: Date = Date()
    var tags: [String] = []
    
    @Relationship(inverse: \Category.items)
    var category: Category?
    
    // Many-to-many relationship with Outfits
    var outfits: [Outfit]? = []
    
    init(
        id: UUID = UUID(),
        name: String,
        category: Category? = nil,
        brand: String? = nil,
        size: String? = nil,
        imageID: UUID = UUID(),
        imageData: Data? = nil,
        dateAdded: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brand = brand
        self.size = size
        self.imageID = imageID
        self.imageData = imageData
        self.dateAdded = dateAdded
        self.tags = tags
    }
}
