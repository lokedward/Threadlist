// Category.swift
// SwiftData model for user-editable categories

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var displayOrder: Int = 0
    
    @Relationship(deleteRule: .nullify)
    var items: [ClothingItem]? = []
    
    init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.items = []
    }
}
