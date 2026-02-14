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
    case profile = "PROFILE"
    
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Define your vibe and let our AI stylist curate the perfect ensemble for you.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.bottom, -5)

                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET OCCASION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    Picker("Occasion", selection: $occasionRaw) {
                        ForEach(StylistOccasion.allCases) { occ in
                            Text(occ.rawValue).tag(occ.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(PoshTheme.Colors.ink)
                    
                    if occasionRaw == StylistOccasion.custom.rawValue {
                        TextField("E.g. Vintage Italian Summer", text: $customOccasion)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("STYLE PARAMETERS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    HStack {
                        Text("Vibe")
                            .font(.system(size: 14))
                        Spacer()
                        Picker("Vibe", selection: $vibeRaw) {
                            ForEach(StyleVibe.allCases) { vibe in
                                Text(vibe.rawValue).tag(vibe.rawValue)
                            }
                        }
                        .accentColor(PoshTheme.Colors.ink)
                    }
                    
                    HStack {
                        Text("Density")
                            .font(.system(size: 14))
                        Spacer()
                        Picker("Density", selection: $densityRaw) {
                            ForEach(StylingDensity.allCases) { density in
                                Text(density.rawValue).tag(density.rawValue)
                            }
                        }
                        .accentColor(PoshTheme.Colors.ink)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("MOOD (OPTIONAL)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                    
                    TextField("E.g. monochromatic colors, oversized fit...", text: $mood, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(2...3)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(PoshTheme.Colors.border, lineWidth: 0.5)
                        )
                }
                
                Button(action: onStyleMe) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("STYLE ME NOW")
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .poshButton()
                .padding(.top, 10)
            }
            .padding()
        }
    }
}

struct ProfileTabView: View {
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
                        .accentColor(PoshTheme.Colors.ink)
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
                        .accentColor(PoshTheme.Colors.ink)
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
                                        .stroke(PoshTheme.Colors.gold, lineWidth: tone.rawValue == skinToneRaw ? 2 : 0)
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
    var onStyleMe: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ProfileTabView()
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
