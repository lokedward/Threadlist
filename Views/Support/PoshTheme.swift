// PoshTheme.swift
// Design tokens and styling rules for the high-end boutique aesthetic
// Light mode only - elegant champagne/gold color scheme

import SwiftUI

struct PoshTheme {
    // MARK: - Colors
    
    struct Colors {
        // Quiet Luxury Palette
        static let canvas = Color(white: 0.99) // Off-White/Paper
        static let ink = Color(white: 0.1)     // Soft Black
        static let stone = Color(white: 0.95)  // Subtle Cards
        static let accent = Color(red: 0.16, green: 0.20, blue: 0.25) // Muted Midnight
        
        // Deprecated / Mapped to new theme
        static let background = canvas
        static let cardBackground = Color.white
        static let primaryAccentStart = accent
        static let primaryAccentEnd = accent
        
        static var primaryGradient: LinearGradient {
            // Flat gradient for backward compatibility
            LinearGradient(colors: [accent, accent], 
                          startPoint: .topLeading, 
                          endPoint: .bottomTrailing)
        }
        
        static let secondaryAccent = ink.opacity(0.5)
        
        // Text
        static let headline = ink
        static let body = ink.opacity(0.8)
        
        // Shadows (Deprecated/ Subtle)
        static var cardShadow: Color {
            Color.clear // Removed shadow
        }
    }
    
    // MARK: - Typography
    
    struct Typography {
        static func headlineFont(size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        
        static func bodyFont(size: CGFloat, weight: Font.Weight = .light) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

// MARK: - View Modifiers

struct PoshCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PoshTheme.Colors.cardBackground)
            .cornerRadius(4) // Minimal
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1) // Tactile stroke
            )
    }
}

struct PoshButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(PoshTheme.Colors.ink) // Solid ink
            .cornerRadius(4) // Minimal
            .simultaneousGesture(TapGesture().onEnded { _ in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            })
    }
}

extension View {
    func poshCard() -> some View {
        modifier(PoshCardModifier())
    }
    
    func poshButton() -> some View {
        modifier(PoshButtonModifier())
    }
    
    func poshHeadline(size: CGFloat = 24) -> some View {
        self.font(PoshTheme.Typography.headlineFont(size: size))
            .textCase(.uppercase)
            .kerning(2.0)
            .foregroundColor(PoshTheme.Colors.headline)
    }
    
    func poshBody(size: CGFloat = 16, weight: Font.Weight = .light) -> some View {
        self.font(PoshTheme.Typography.bodyFont(size: size, weight: weight))
            .foregroundColor(PoshTheme.Colors.body)
    }
}

// MARK: - Reusable Components

struct PoshHeader: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image("app_icon") // This will use Icons/app_icon.png if properly added to assets
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            
            Text(title)
                .poshHeadline(size: 24)
        }
    }
}
