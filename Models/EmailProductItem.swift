// EmailProductItem.swift
// Shared model for parsed email product data

import Foundation

/// Represents a product parsed from an email, ready to be reviewed and added to wardrobe
struct EmailProductItem: Identifiable {
    let id = UUID()
    let name: String
    let imageURL: URL?
    let brand: String?
    let size: String?
    let color: String?
    
    init(name: String, imageURL: URL?, brand: String? = nil, size: String? = nil, color: String? = nil) {
        self.name = name
        self.imageURL = imageURL
        self.brand = brand
        self.size = size
        self.color = color
    }
}
