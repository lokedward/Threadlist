// SharedTypes.swift
// Global data structures and utility types

import SwiftUI

/// A wrapper for images being passed and animated between views
struct CroppableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Stylist Types

enum Gender {
    case male, female
}

/// Common app constants for consistent styling/behavior
struct AppConstants {
    struct Animation {
        static let modalTransitionDelay: Double = 0.3
        static let processingDelay: UInt64 = 500_000_000 // 0.5s
    }
    
    struct Image {
        static let maxUploadDimension: CGFloat = 2000
        static let compressionQuality: CGFloat = 0.8
    }
}
