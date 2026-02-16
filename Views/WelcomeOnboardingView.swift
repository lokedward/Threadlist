import SwiftUI
import SwiftData

struct WelcomeOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var selectedTemplates: Set<String> = []
    @State private var allTemplates: [(name: String, categories: [String])] = [
        ("Classic Essentials", ["Tops", "Bottoms", "Outerwear", "Shoes"]),
        ("Athleisure", ["Activewear", "Sneakers", "Performance", "Athleisure"]),
        ("Dressy & Refined", ["Formal", "Blazers", "Dress Shoes", "Accessories"])
    ]
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hero Header with Gold Accents
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Your Digital Wardrobe")
                            .poshHeadline(size: 32)
                    }
                    .multilineTextAlignment(.center)
                    
                    HStack(spacing: 0) {
                        Text("BUILD YOUR ")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                        Text("THREADLIST")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundColor(PoshTheme.Colors.gold)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal)
                
                Spacer(minLength: 20)
                
                // Starter Paths (no header)
                VStack(spacing: 14) {
                    TemplateRow(
                        title: "Classic Essentials",
                        subtitle: "Perfect for everyday basics & versatile pieces",
                        categories: ["Tops", "Bottoms", "Outerwear", "Shoes"],
                        icon: "square.grid.2x2",
                        isSelected: selectedTemplates.contains("Classic Essentials"),
                        onToggle: { toggleTemplate("Classic Essentials") }
                    )
                    
                    TemplateRow(
                        title: "Athleisure",
                        subtitle: "For active lifestyles & comfortable style",
                        categories: ["Activewear", "Sneakers", "Performance", "Athleisure"],
                        icon: "figure.run",
                        isSelected: selectedTemplates.contains("Athleisure"),
                        onToggle: { toggleTemplate("Athleisure") }
                    )
                    
                    TemplateRow(
                        title: "Dressy & Refined",
                        subtitle: "Elevated pieces for special occasions",
                        categories: ["Formal", "Blazers", "Dress Shoes", "Accessories"],
                        icon: "star.fill",
                        isSelected: selectedTemplates.contains("Dressy & Refined"),
                        onToggle: { toggleTemplate("Dressy & Refined") }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 20)
                
                // Footer with CTA and Skip
                VStack(spacing: 16) {
                    if selectedTemplates.isEmpty {
                        Text("Choose a style to organize your wardrobe with custom categories.")
                            .poshBody(size: 12)
                            .opacity(0.5)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        // Selection count
                        Text("\(selectedTemplates.count) style\(selectedTemplates.count > 1 ? "s" : "") selected")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                        
                        // CTA Button
                        Button {
                            finalizeOnboarding()
                        } label: {
                            Text("BUILD MY CLOSET")
                                .tracking(2)
                        }
                        .poshButton()
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Skip button
                    Button {
                        withAnimation { hasCompletedOnboarding = true }
                    } label: {
                        Text("SKIP FOR NOW")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                    }
                }
                .padding(.bottom, 50)
                .animation(.spring(), value: selectedTemplates)
            }
        }
    }
    
    private func toggleTemplate(_ name: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if selectedTemplates.contains(name) {
            selectedTemplates.remove(name)
        } else {
            selectedTemplates.insert(name)
        }
    }
    
    
    private func finalizeOnboarding() {
        // Collect all categories from selected templates
        var allCategories: [String] = []
        for templateName in selectedTemplates {
            if let template = allTemplates.first(where: { $0.name == templateName }) {
                allCategories.append(contentsOf: template.categories)
            }
        }
        
        // Remove duplicates while preserving order
        var uniqueCategories: [String] = []
        var seen: Set<String> = []
        for category in allCategories {
            if !seen.contains(category) {
                uniqueCategories.append(category)
                seen.insert(category)
            }
        }
        
        // Create categories in the model
        for (index, name) in uniqueCategories.enumerated() {
            // Check if category already exists to avoid duplicates
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate<Category> { $0.name == name })
            if (try? modelContext.fetch(descriptor))?.isEmpty ?? true {
                let newCat = Category(name: name, displayOrder: index)
                modelContext.insert(newCat)
            }
        }
        
        try? modelContext.save()
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Mark as completed to switch HomeView
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

struct TemplateRow: View {
    let title: String
    let subtitle: String
    let categories: [String]
    let icon: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(PoshTheme.Colors.ink)
                        .frame(width: 48, height: 48)
                        .background(PoshTheme.Colors.stone)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(title.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(PoshTheme.Colors.ink)
                            
                            // Category count badge
                            Text("\(categories.count) CATEGORIES")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(PoshTheme.Colors.stone)
                                .cornerRadius(3)
                        }
                        
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Toggle Circle
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? PoshTheme.Colors.gold : PoshTheme.Colors.ink.opacity(0.2), lineWidth: 2)
                            .frame(width: 26, height: 26)
                        
                        if isSelected {
                            Circle()
                                .fill(PoshTheme.Colors.gold)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                
                // Category tags
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { category in
                        Text(category)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PoshTheme.Colors.stone.opacity(0.5))
                            .cornerRadius(5)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? PoshTheme.Colors.gold.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeOnboardingView(hasCompletedOnboarding: .constant(false))
        .modelContainer(for: [Category.self], inMemory: true)
}
