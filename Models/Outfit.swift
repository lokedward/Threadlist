// Outfit.swift
// SwiftData model for saved AI-generated outfits

import Foundation
import SwiftData

@Model
final class Outfit {
    var id: UUID
    var createdAt: Date
    var generatedImageID: UUID?
    
    // The items that make up this outfit
    @Relationship(inverse: \ClothingItem.outfits)
    var items: [ClothingItem]
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        generatedImageID: UUID? = nil,
        items: [ClothingItem] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.generatedImageID = generatedImageID
        self.items = items
    }
}
