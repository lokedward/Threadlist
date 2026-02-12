import SwiftUI
import SwiftData

struct WelcomeOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTemplate: String? = nil
    @State private var pendingCategories: [String] = []
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Hero Header
                    VStack(spacing: 8) {
                        Text("The Digital Studio")
                            .poshHeadline(size: 32)
                            .multilineTextAlignment(.center)
                        
                        Text("CURATE YOUR WARDROBE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    }
                    .padding(.top, 80)
                    
                    if let selected = selectedTemplate {
                        // Feedback / Success State
                        VStack(spacing: 32) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundColor(PoshTheme.Colors.ink)
                            
                            VStack(spacing: 12) {
                                Text("\(selected.uppercased()) READY")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(2)
                                
                                Text("We've drafted specialized shelves for your \(selected.lowercased()) collection.")
                                    .poshBody(size: 14)
                                    .opacity(0.6)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button {
                                finalizeOnboarding()
                            } label: {
                                Text("BUILD MY CLOSET")
                                    .tracking(2)
                            }
                            .poshButton()
                        }
                        .padding(40)
                        .background(Color.white)
                        .cornerRadius(24)
                        .poshCard()
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Starter Paths
                        VStack(alignment: .leading, spacing: 24) {
                            Text("CHOOSE A STARTER PATH")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                TemplateRow(
                                    title: "Minimalist Capsule",
                                    subtitle: "Tops, Bottoms, Outerwear, Shoes",
                                    categories: ["Tops", "Bottoms", "Outerwear", "Shoes"],
                                    icon: "square.grid.2x2",
                                    onSelect: { name, cats in
                                        selectedTemplate = name
                                        pendingCategories = cats
                                    }
                                )
                                
                                TemplateRow(
                                    title: "The Weekend Edit",
                                    subtitle: "Denim, Knits, Accessories, Loungewear",
                                    categories: ["Denim", "Knits", "Accessories", "Loungewear"],
                                    icon: "leaf",
                                    onSelect: { name, cats in
                                        selectedTemplate = name
                                        pendingCategories = cats
                                    }
                                )
                                
                                TemplateRow(
                                    title: "Modern Executive",
                                    subtitle: "Tailoring, Shirts, Formal, Bags",
                                    categories: ["Tailoring", "Shirts", "Formal", "Bags"],
                                    icon: "briefcase",
                                    onSelect: { name, cats in
                                        selectedTemplate = name
                                        pendingCategories = cats
                                    }
                                )
                            }
                            .padding(.horizontal)
                        }
                        .transition(.opacity)
                    }
                    
                    // Footer Hint
                    if selectedTemplate == nil {
                        Text("This structure helps you visualize your full potential")
                            .poshBody(size: 12)
                            .opacity(0.4)
                            .padding(.bottom, 40)
                    }
                }
                .animation(.spring(), value: selectedTemplate)
            }
        }
    }
    
    private func finalizeOnboarding() {
        for (index, name) in pendingCategories.enumerated() {
            let newCat = Category(name: name, displayOrder: index)
            modelContext.insert(newCat)
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // At this point, HomeView's Re-evaluation will swap WelcomeOnboardingView out
    }
}

struct TemplateRow: View {
    let title: String
    let subtitle: String
    let categories: [String]
    let icon: String
    let onSelect: (String, [String]) -> Void
    
    var body: some View {
        Button {
            // Haptic feedack on tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            onSelect(title.replacingOccurrences(of: " Capsule", with: "").replacingOccurrences(of: "The ", with: "").replacingOccurrences(of: " Edit", with: ""), categories)
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
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.2))
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.white)
            .poshCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeOnboardingView()
        .modelContainer(for: [Category.self], inMemory: true)
}
