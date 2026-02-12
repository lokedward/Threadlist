import SwiftUI
import SwiftData

struct WelcomeOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    
    // Seasonal detection
    private var currentSeason: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "Spring"
        case 6...8: return "Summer"
        case 9...11: return "Autumn"
        default: return "Winter"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Hero Header
                VStack(spacing: 8) {
                    Text("Your Digital Studio")
                        .poshHeadline(size: 32)
                        .multilineTextAlignment(.center)
                    
                    Text("START BUILDING YOUR COLLECTION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                }
                .padding(.top, 60)
                
                // Shadow Shelves Visualization
                VStack(alignment: .leading, spacing: 20) {
                    Text("THE SHELF CONCEPT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        ShadowPlaceholderCard(icon: "coat", label: "Outerwear")
                        ShadowPlaceholderCard(icon: "tshirt", label: "Basics")
                        ShadowPlaceholderCard(icon: "fossil.shell", label: "Accessories")
                    }
                    .padding(.horizontal)
                }
                
                // Seasonal Templates
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("\(currentSeason.uppercased()) ESSENTIALS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                        
                        Spacer()
                        
                        Text("TAP TO ADD")
                            .font(.system(size: 9))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        TemplateRow(
                            title: "Minimalist Capsule",
                            subtitle: "Tops, Bottoms, Outerwear, Shoes",
                            categories: ["Tops", "Bottoms", "Outerwear", "Shoes"],
                            icon: "square.grid.2x2"
                        )
                        
                        TemplateRow(
                            title: "The Weekend Edit",
                            subtitle: "Denim, Knits, Accessories, Loungewear",
                            categories: ["Denim", "Knits", "Accessories", "Loungewear"],
                            icon: "leaf"
                        )
                        
                        TemplateRow(
                            title: "Modern Executive",
                            subtitle: "Tailoring, Shirts, Formal, Bags",
                            categories: ["Tailoring", "Shirts", "Formal", "Bags"],
                            icon: "briefcase"
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Footer Hint
                Text("Add your first item to begin styling")
                    .poshBody(size: 12)
                    .opacity(0.4)
                    .padding(.bottom, 40)
            }
        }
        .background(PoshTheme.Colors.canvas)
    }
}

struct ShadowPlaceholderCard: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.1))
                .frame(width: 80, height: 100)
                .background(PoshTheme.Colors.stone.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.05))
                )
            
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

struct TemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let subtitle: String
    let categories: [String]
    let icon: String
    
    @State private var hasAdded = false
    
    var body: some View {
        Button {
            addCategories()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(PoshTheme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .background(PoshTheme.Colors.stone)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: hasAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(hasAdded ? .green : PoshTheme.Colors.ink.opacity(0.2))
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.white)
            .poshCard()
        }
        .buttonStyle(.plain)
        .disabled(hasAdded)
    }
    
    private func addCategories() {
        for (index, name) in categories.enumerated() {
            let newCat = Category(name: name, displayOrder: index)
            modelContext.insert(newCat)
        }
        
        withAnimation {
            hasAdded = true
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    WelcomeOnboardingView()
        .modelContainer(for: [Category.self], inMemory: true)
}
