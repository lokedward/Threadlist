// Outfit.swift
// SwiftData model for saved AI-generated outfits

import Foundation
import SwiftData

@Model
final class Outfit {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var generatedImageID: UUID?
    
    @Attribute(.externalStorage)
    var imageData: Data?
    
    // The items that make up this outfit
    @Relationship(inverse: \ClothingItem.outfits)
    var items: [ClothingItem]? = []
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        generatedImageID: UUID? = nil,
        imageData: Data? = nil,
        items: [ClothingItem] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.generatedImageID = generatedImageID
        self.imageData = imageData
        self.items = items
    }
}
