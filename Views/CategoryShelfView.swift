// CategoryShelfView.swift
// Horizontal scrolling shelf for a category

import SwiftUI
import SwiftData

struct CategoryShelfView: View {
    let category: Category
    @Binding var selectedTab: Int
    @Binding var preselectedCategory: String?
    @State private var isExpanded: Bool
    
    init(category: Category, selectedTab: Binding<Int>, preselectedCategory: Binding<String?>) {
        self.category = category
        self._selectedTab = selectedTab
        self._preselectedCategory = preselectedCategory
        // Default to expanded for roomier feel
        self._isExpanded = State(initialValue: true)
    }
    
    private var sortedItems: [ClothingItem] {
        category.items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center) {
                    Text(category.name)
                        .poshHeadline(size: 20)
                    
                    Text("\(category.items.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PoshTheme.Colors.ink.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.gold) // Gold accent
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Horizontal scroll of items or Shadow Placeholders
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        if sortedItems.isEmpty {
                            // Shadow Shelf for empty categories with descriptive emoji
                            let emoji = placeholderEmoji(for: category.name)
                            ShadowPlaceholderCard(emoji: emoji)
                                .frame(width: 140)
                                .onTapGesture {
                                    withAnimation {
                                        // Set the category name to be preselected
                                        preselectedCategory = category.name
                                        // Switch to Curate tab
                                        selectedTab = 1
                                    }
                                }
                        } else {
                            ForEach(sortedItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    ItemThumbnailView(item: item)
                                        .frame(width: 140)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
    
    private func placeholderEmoji(for categoryName: String) -> String {
        let name = categoryName.lowercased()
        if name.contains("top") || name.contains("shirt") { return "👕" }
        if name.contains("bottom") || name.contains("denim") || name.contains("pants") { return "👖" }
        if name.contains("outer") || name.contains("coat") || name.contains("jacket") || name.contains("tailor") { return "🧥" }
        if name.contains("shoes") || name.contains("sneaker") || name.contains("boots") { return "👟" }
        if name.contains("bag") || name.contains("handbag") { return "👜" }
        if name.contains("access") || name.contains("jewelry") { return "💍" }
        if name.contains("knit") || name.contains("sweater") { return "🧶" }
        if name.contains("lounge") || name.contains("sleep") { return "🛌" }
        if name.contains("formal") || name.contains("dress") { return "👗" }
        if name.contains("suit") { return "👔" }
        return "✨"
    }
}

// Reusable Shadow Placeholder for empty states
struct ShadowPlaceholderCard: View {
    let emoji: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background
                Rectangle()
                    .fill(PoshTheme.Colors.stone.opacity(0.4))
                
                // Dash Border
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.1))
                
                // Content
                VStack(spacing: 8) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .grayscale(1.0)
                        .opacity(0.3)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.2))
                }
            }
            .frame(width: 140, height: 180)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, ClothingItem.self, configurations: config)
    
    let category = Category(name: "Tops", displayOrder: 0)
    container.mainContext.insert(category)
    
    return NavigationStack {
        CategoryShelfView(
            category: category,
            selectedTab: .constant(0),
            preselectedCategory: .constant(nil)
        )
    }
    .modelContainer(container)
}
