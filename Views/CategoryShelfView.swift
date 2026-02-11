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
                    .foregroundColor(PoshTheme.Colors.primaryInk.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(PoshTheme.Colors.primaryInk.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                
                NavigationLink {
                    CategoryGridView(category: category)
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.primaryInk)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(PoshTheme.Colors.primaryInk.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            
            // Horizontal scroll of items
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
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
                .padding(.horizontal)
            }
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
