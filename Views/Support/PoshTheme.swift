// PoshTheme.swift
// Design tokens and styling rules for the high-end boutique aesthetic

import SwiftUI

struct PoshTheme {
    // MARK: - Colors
    
    struct Colors {
        // Backgrounds
        static let background = Color(light: Color(red: 0.98, green: 0.977, blue: 0.965), 
                                     dark: Color(red: 0.07, green: 0.07, blue: 0.07))
        
        static let cardBackground = Color(light: .white, 
                                         dark: Color(red: 0.12, green: 0.12, blue: 0.12))
        
        // Accents - Primary (Champagne in Light, Bronze in Dark)
        static let primaryAccentStart = Color(light: Color(red: 0.83, green: 0.68, blue: 0.21), // Champagne
                                            dark: Color(red: 0.80, green: 0.50, blue: 0.20)) // Bronze
        
        static let primaryAccentEnd = Color(light: Color(red: 0.91, green: 0.82, blue: 0.48), 
                                          dark: Color(red: 0.55, green: 0.27, blue: 0.07))
        
        static var primaryGradient: LinearGradient {
            LinearGradient(colors: [primaryAccentStart, primaryAccentEnd], 
                          startPoint: .topLeading, 
                          endPoint: .bottomTrailing)
        }
        
        // Secondary Accents
        static let secondaryAccent = Color(light: Color(red: 0.85, green: 0.75, blue: 0.65), 
                                         dark: Color(red: 0.45, green: 0.35, blue: 0.25))
        
        // Text
        static let headline = Color(light: Color(red: 0.18, green: 0.14, blue: 0.12), 
                                  dark: Color(red: 0.98, green: 0.977, blue: 0.965))
        
        static let body = Color(light: Color(red: 0.36, green: 0.33, blue: 0.31), 
                              dark: Color(red: 0.85, green: 0.85, blue: 0.85))
        
        // Shadows
        static var cardShadow: Color {
            Color.black.opacity(0.08)
        }
        
        static var bronzeGlow: Color {
            Color(red: 0.80, green: 0.50, blue: 0.20).opacity(0.3)
        }
    }
    
    // MARK: - Typography
    
    struct Typography {
        static func headline(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }
        
        static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

// MARK: - View Modifiers

struct PoshCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(PoshTheme.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(
                color: colorScheme == .light ? PoshTheme.Colors.cardShadow : PoshTheme.Colors.bronzeGlow,
                radius: colorScheme == .light ? 10 : 15,
                x: 0,
                y: 5
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(PoshTheme.Colors.secondaryAccent.opacity(0.2), lineWidth: 0.5)
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
            .background(PoshTheme.Colors.primaryGradient)
            .cornerRadius(30)
            .shadow(color: PoshTheme.Colors.primaryAccentStart.opacity(0.3), radius: 8, x: 0, y: 4)
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
            .foregroundColor(PoshTheme.Colors.headline)
    }
    
    func poshBody(size: CGFloat = 16, weight: Font.Weight = .regular) -> some View {
        self.font(PoshTheme.Typography.body(size: size, weight: weight))
            .foregroundColor(PoshTheme.Colors.body)
    }
}

// Helper for Light/Dark color selection
extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
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
