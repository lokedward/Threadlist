// PoshTheme.swift
// Design tokens and styling rules for the high-end boutique aesthetic
// Light mode only - elegant champagne/gold color scheme

import SwiftUI
import UIKit

struct PoshTheme {
    // MARK: - Colors
    
    struct Colors {
        // Quiet Luxury Palette
        static let primaryCanvas: Color = Color(white: 0.99) // Off-White/Paper
        static let primaryInk: Color = Color(white: 0.1)     // Soft Black
        static let stone = Color(white: 0.95)  // Subtle Cards
        static let accent = Color(red: 0.16, green: 0.20, blue: 0.25) // Muted Midnight
        
        static let uiInk = UIColor(white: 0.1, alpha: 1.0)
        static let uiCanvas = UIColor(white: 0.99, alpha: 1.0)
        
        static let canvas = primaryCanvas
        static let ink = primaryInk
        
        // Text - Mapped to Ink
        static let headline = primaryInk
        static let body = primaryInk.opacity(0.8)
    }
    
    // MARK: - Typography
    
    struct Typography {
        static func headline(size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        
        static func body(size: CGFloat, weight: Font.Weight = .light) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

// MARK: - View Modifiers

struct PoshCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
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
        self.font(PoshTheme.Typography.headline(size: size))
            .textCase(.uppercase)
            .kerning(2.0)
            .foregroundColor(PoshTheme.Colors.headline)
    }
    
    func poshBody(size: CGFloat = 16, weight: Font.Weight = .light) -> some View {
        self.font(PoshTheme.Typography.body(size: size, weight: weight))
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
