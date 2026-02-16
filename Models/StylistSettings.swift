// StylistSettings.swift
// Models and Views for dynamic stylist configuration

import SwiftUI

// MARK: - Enums

enum ModelBodyType: String, CaseIterable, Identifiable {
    case slim = "Slim"
    case athletic = "Athletic"
    case curvy = "Curvy"
    case plusSize = "Plus Size"
    
    var id: String { rawValue }
    
    var promptDescription: String {
        switch self {
        case .slim: return "slim build"
        case .athletic: return "athletic build"
        case .curvy: return "curvy full-figured build"
        case .plusSize: return "plus-size full-figured build"
        }
    }
}

enum SkinTone: String, CaseIterable, Identifiable {
    case fair = "Fair"
    case medium = "Medium"
    case olive = "Olive"
    case dark = "Dark"
    case deep = "Deep"
    
    var id: String { rawValue }
    
    var promptDescription: String {
        switch self {
        case .fair: return "fair skin tone"
        case .medium: return "medium skin tone"
        case .olive: return "olive skin tone"
        case .dark: return "dark skin tone"
        case .deep: return "deep skin tone"
        }
    }
    
    var color: Color {
        switch self {
        case .fair: return Color(red: 0.95, green: 0.85, blue: 0.80)
        case .medium: return Color(red: 0.85, green: 0.70, blue: 0.60)
        case .olive: return Color(red: 0.75, green: 0.60, blue: 0.45)
        case .dark: return Color(red: 0.55, green: 0.40, blue: 0.30)
        case .deep: return Color(red: 0.35, green: 0.25, blue: 0.20)
        }
    }
}

enum ModelHeight: String, CaseIterable, Identifiable {
    case petite = "Petite"
    case average = "Average"
    case tall = "Tall"
    
    var id: String { rawValue }
    
    var promptDescription: String {
        switch self {
        case .petite: return "petite height"
        case .average: return "average height"
        case .tall: return "tall height"
        }
    }
}

enum StylistOccasion: String, CaseIterable, Identifiable {
    case casual = "Casual"
    case professional = "Professional"
    case dateNight = "Date Night"
    case formal = "Formal/Wedding"
    case vacation = "Vacation"
    case gym = "Athletic/Gym"
    case custom = "Custom..."
    
    var id: String { rawValue }
}

enum StyleVibe: String, CaseIterable, Identifiable {
    case minimalist = "Minimalist"
    case avantGarde = "Avant-Garde"
    case timeless = "Timeless"
    case streetStyle = "Street Style"
    case boho = "Bohemian"
    case elegant = "Elegant"
    
    var id: String { rawValue }
}

enum StylingDensity: String, CaseIterable, Identifiable {
    case simple = "Minimalist/Simple"
    case balanced = "Balanced"
    case layered = "Layered/Complex"
    
    var id: String { rawValue }
}

enum StylistTab: String, CaseIterable, Identifiable {
    case closet = "CLOSET"
    case styling = "STYLING"
    case model = "MODEL"
    
    var id: String { rawValue }
}

// MARK: - Settings View

// MARK: - Integrated Tab Views

struct StylingTabView: View {
    @AppStorage("stylistOccasion") private var occasionRaw = StylistOccasion.casual.rawValue
    @AppStorage("stylistCustomOccasion") private var customOccasion = ""
    @AppStorage("stylistStyleVibe") private var vibeRaw = StyleVibe.timeless.rawValue
    @AppStorage("stylistDensity") private var densityRaw = StylingDensity.balanced.rawValue
    @AppStorage("stylistMood") private var mood = ""
    
    var onStyleMe: () -> Void
    
    // Occasion presets with visual styling
    private let occasionPresets: [(occasion: StylistOccasion, icon: String, gradient: [Color], subtitle: String)] = [
        (.dateNight, "heart.fill", [Color(red: 0.9, green: 0.3, blue: 0.4), Color(red: 0.95, green: 0.5, blue: 0.6)], "Romantic & Confident"),
        (.professional, "briefcase.fill", [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.4, green: 0.6, blue: 0.9)], "Polished & Put-Together"),
        (.casual, "sun.max.fill", [Color(red: 0.95, green: 0.7, blue: 0.3), Color(red: 0.98, green: 0.85, blue: 0.5)], "Relaxed & Effortless"),
        (.vacation, "airplane", [Color(red: 0.3, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.85, blue: 0.95)], "Adventure Ready"),
        (.formal, "sparkles", [Color(red: 0.5, green: 0.3, blue: 0.7), Color(red: 0.7, green: 0.5, blue: 0.85)], "Elegant & Sophisticated"),
        (.gym, "figure.run", [Color(red: 0.3, green: 0.8, blue: 0.4), Color(red: 0.5, green: 0.9, blue: 0.6)], "Active & Dynamic")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Tap an occasion and let AI curate your perfect look")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.bottom, -5)
                
                // Occasion Preset Cards
                VStack(spacing: 12) {
                    ForEach(Array(occasionPresets.chunked(into: 2)), id: \.first!.occasion) { pair in
                        HStack(spacing: 12) {
                            ForEach(pair, id: \.occasion) { preset in
                                OccasionPresetCard(
                                    title: preset.occasion.rawValue.uppercased(),
                                    subtitle: preset.subtitle,
                                    icon: preset.icon,
                                    gradient: preset.gradient,
                                    isSelected: occasionRaw == preset.occasion.rawValue
                                ) {
                                    occasionRaw = preset.occasion.rawValue
                                    onStyleMe()
                                }
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Custom Occasion Option
                VStack(alignment: .leading, spacing: 12) {
                    Text("CUSTOM OCCASION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    TextField("E.g. Vintage Italian Summer, Art Gallery Opening...", text: $customOccasion, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(2...3)
                        .padding(12)
                        .background(PoshTheme.Colors.canvas)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(PoshTheme.Colors.border, lineWidth: 0.5)
                        )
                    
                    Button(action: {
                        if !customOccasion.isEmpty {
                            occasionRaw = StylistOccasion.custom.rawValue
                            onStyleMe()
                        }
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("STYLE FOR CUSTOM OCCASION")
                                .tracking(1.5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .poshButton()
                    .disabled(customOccasion.isEmpty)
                    .opacity(customOccasion.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding()
        }
    }
}

// MARK: - Occasion Preset Card

struct OccasionPresetCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? PoshTheme.Colors.gold : Color.clear, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// Helper extension for chunking array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct ProfileTabView: View {
    @Binding var showPaywall: Bool
    @AppStorage("stylistModelGender") private var genderRaw = "female"
    @AppStorage("stylistBodyType") private var bodyTypeRaw = ModelBodyType.slim.rawValue
    @AppStorage("stylistSkinTone") private var skinToneRaw = SkinTone.medium.rawValue
    @AppStorage("stylistModelHeight") private var heightRaw = ModelHeight.average.rawValue
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GENDER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    Picker("Gender", selection: $genderRaw) {
                        Text("Female").tag("female")
                        Text("Male").tag("male")
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BODY TYPE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.gold)
                        
                        Picker("Body Type", selection: $bodyTypeRaw) {
                            ForEach(ModelBodyType.allCases) { type in
                                Text(type.rawValue).tag(type.rawValue)
                            }
                        }
                        .tint(PoshTheme.Colors.ink)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HEIGHT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.gold)
                        
                        Picker("Height", selection: $heightRaw) {
                            ForEach(ModelHeight.allCases) { h in
                                Text(h.rawValue).tag(h.rawValue)
                            }
                        }
                        .tint(PoshTheme.Colors.ink)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("SKIN TONE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    HStack(spacing: 12) {
                        ForEach(SkinTone.allCases) { tone in
                            Circle()
                                .fill(tone.color)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(PoshTheme.Colors.ink, lineWidth: tone.rawValue == skinToneRaw ? 2 : 0)
                                )
                                .onTapGesture {
                                    skinToneRaw = tone.rawValue
                                }
                        }
                    }
                }
                
                Text("These settings help the AI generate a model that best represents you.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
            .padding()
        }
    }
}

// Deprecated: Keeping for backward compatibility until all refs are gone
struct StylistSettingsView: View {
    @State private var showPaywall = false
    var onStyleMe: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ProfileTabView(showPaywall: $showPaywall)
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
                .navigationTitle("Profile Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .foregroundColor(PoshTheme.Colors.ink)
                    }
                }
        }
    }
}

struct StylistAIPopupView: View {
    var onStyleMe: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            StylingTabView(onStyleMe: {
                dismiss()
                onStyleMe()
            })
            .navigationTitle("Magic Stylist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(PoshTheme.Colors.ink)
                }
            }
        }
    }
}

#Preview {
    StylistAIPopupView(onStyleMe: {})
}
