// CategoryShelfView.swift
// Horizontal scrolling shelf for a category

import SwiftUI
import SwiftData

struct CategoryShelfView: View {
    let category: Category
    
    private var sortedItems: [ClothingItem] {
        category.items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
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
                
                NavigationLink {
                    CategoryGridView(category: category)
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(PoshTheme.Colors.ink.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            
            // Horizontal scroll of items or Shadow Placeholders
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if sortedItems.isEmpty {
                        // Shadow Shelves for empty categories
                        ForEach(0..<3) { _ in
                            ShadowPlaceholderCard()
                                .frame(width: 140)
                                .opacity(0.6)
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
            }
        }
    }
}

// Reusable Shadow Placeholder for empty states
struct ShadowPlaceholderCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .thin))
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.1))
                .frame(width: 140, height: 180)
                .background(PoshTheme.Colors.stone.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.05))
                )
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, ClothingItem.self, configurations: config)
    
    let category = Category(name: "Tops", displayOrder: 0)
    container.mainContext.insert(category)
    
    return NavigationStack {
        CategoryShelfView(category: category)
    }
    .modelContainer(container)
}
