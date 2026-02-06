// StylistService.swift
// Logic for AI styling and item layering

import Foundation
import SwiftUI

class StylistService {
    static let shared = StylistService()
    
    private init() {}
    
    /// Determines the z-index/order for an item based on its category
    func layeringOrder(for item: ClothingItem) -> Int {
        guard let categoryName = item.category?.name.lowercased() else { return 0 }
        
        // Lower numbers are back, higher are front
        if categoryName.contains("under") || categoryName.contains("base") {
            return 10
        } else if categoryName.contains("pant") || categoryName.contains("skirt") || categoryName.contains("jean") {
            return 20
        } else if categoryName.contains("top") || categoryName.contains("shirt") || categoryName.contains("blouse") {
            return 30
        } else if categoryName.contains("dress") {
            return 35
        } else if categoryName.contains("outer") || categoryName.contains("jacket") || categoryName.contains("coat") {
            return 40
        } else if categoryName.contains("shoe") || categoryName.contains("boot") {
            return 50
        } else if categoryName.contains("access") || categoryName.contains("bag") || categoryName.contains("hat") {
            return 60
        }
        
        return 0
    }
    
    /// Get styling advice from "Gemini Nanobanana"
    func getVibeCheck(for items: [ClothingItem]) async -> String {
        guard !items.isEmpty else { return "Select some pieces to get started!" }
        
        // Simulating Gemini's reasoning
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let names = items.map { $0.name }
        return "This combination of \(names.joined(separator: " and ")) looks incredibly chic! The palette is giving 'quiet luxury' vibes. Perfect for a gallery opening or a sophisticated brunch."
    }
}
