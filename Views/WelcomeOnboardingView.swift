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
            
            ScrollView {
                VStack(spacing: 40) {
                    // Top Navigation
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { hasCompletedOnboarding = true }
                        } label: {
                            Text("SKIP")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Hero Header
                    VStack(spacing: 8) {
                        Text("Your Digital Wardrobe")
                            .poshHeadline(size: 32)
                            .multilineTextAlignment(.center)
                        
                        Text("BUILD YOUR THREADLIST")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    }
                    .padding(.horizontal)
                    
                    // Starter Paths
                    VStack(alignment: .leading, spacing: 24) {
                        Text("SELECT YOUR WARDROBE STYLE")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                            .padding(.horizontal)
                        
                        VStack(spacing: 20) {
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
                        .padding(.horizontal)
                    }
                    
                    // Footer Hint
                    if selectedTemplates.isEmpty {
                        Text("Choose a style to organize your wardrobe with custom categories.")
                            .poshBody(size: 13)
                            .opacity(0.5)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                    } else {
                        // CTA Button
                        VStack(spacing: 12) {
                            Text("\(selectedTemplates.count) style\(selectedTemplates.count > 1 ? "s" : "") selected")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            Button {
                                finalizeOnboarding()
                            } label: {
                                Text("BUILD MY CLOSET")
                                    .tracking(2)
                            }
                            .poshButton()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(PoshTheme.Colors.ink)
                        .frame(width: 56, height: 56)
                        .background(PoshTheme.Colors.stone)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(title.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(PoshTheme.Colors.ink)
                            
                            // Category count badge
                            Text("\(categories.count) CATEGORIES")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(PoshTheme.Colors.stone)
                                .cornerRadius(4)
                        }
                        
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Toggle Circle
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? PoshTheme.Colors.ink : PoshTheme.Colors.ink.opacity(0.2), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        if isSelected {
                            Circle()
                                .fill(PoshTheme.Colors.ink)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                
                // Category tags
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Text(category)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PoshTheme.Colors.stone.opacity(0.5))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? PoshTheme.Colors.ink.opacity(0.15) : Color.clear, lineWidth: 2)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeOnboardingView(hasCompletedOnboarding: .constant(false))
        .modelContainer(for: [Category.self], inMemory: true)
}
