// CategoryGridView.swift
// Full-screen grid view for all items in a category

import SwiftUI
import SwiftData

struct CategoryGridView: View {
    let category: Category
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var sortedItems: [ClothingItem] {
        category.items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            ScrollView {
                if sortedItems.isEmpty {
                    VStack(spacing: 24) {
                        Spacer(minLength: 120)
                        
                        Image(systemName: "handbag")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            Text("ARCHIVE EMPTY")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(3)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                            
                            Text("No items curated in \(category.name.uppercased()) yet.")
                                .poshBody(size: 14)
                                .opacity(0.6)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemThumbnailView(item: item, size: .large)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(category.name.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
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
        CategoryGridView(category: category)
    }
    .modelContainer(container)
}
