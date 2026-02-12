// PoshTheme.swift
// Design tokens and styling rules for the high-end boutique aesthetic
// Light mode only - elegant champagne/gold color scheme

import SwiftUI
import UIKit

struct PoshTheme {
    // MARK: - Colors
    
    struct Colors {
        // Quiet Luxury Palette
        static let canvas: Color = Color(white: 0.99) // Backgrounds
        static let ink: Color = Color(white: 0.12)    // Soft Charcoal primary
        static let stone: Color = Color(white: 0.96)  // Card Backgrounds
        static let border: Color = Color.black.opacity(0.08) // Hairlines
        static let error: Color = Color(red: 0.8, green: 0.2, blue: 0.2).opacity(0.8) // Muted Red
        static let gold: Color = Color(red: 0.83, green: 0.68, blue: 0.21) // Muted Champagne Gold
        
        static let uiInk: UIColor = UIColor(white: 0.12, alpha: 1.0)
        static let uiCanvas: UIColor = UIColor(white: 0.99, alpha: 1.0)
        static let uiGold: UIColor = UIColor(red: 0.83, green: 0.68, blue: 0.21, alpha: 1.0)
        
        // Text - Mapped to Ink
        static let headline: Color = ink
        static let body: Color = ink.opacity(0.8)
    }
    
    // MARK: - Typography
    
    struct Typography {
        static func headline(size: CGFloat) -> Font {
            // Editorial signature: Serif regular
            .system(size: size, weight: .regular, design: .serif)
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
            .cornerRadius(0) // Sharp editorial corners
            .overlay(
                Rectangle()
                    .stroke(PoshTheme.Colors.border, lineWidth: 0.5) // Physical 0.5pt hairline
            )
            .shadow(color: .clear, radius: 0)
    }
}

struct PoshButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .bold)) // Slightly smaller, sharper text
            .tracking(2) // Signiture luxury tracking
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(PoshTheme.Colors.ink) // Solid ink
            .cornerRadius(0) // Sharp corners
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
        HStack(spacing: 12) {
            Image("brand_logo")
                .renderingMode(.template) // Ensure template mode for tinting
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
                .foregroundColor(PoshTheme.Colors.ink)
            
            Text("THREADLIST")
                .poshHeadline(size: 14) // Understated branding
            
            if !title.isEmpty && title != "THREADLIST" {
                Text("|")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.2))
                
                Text(title)
                    .poshHeadline(size: 14)
            }
        }
    }
}
