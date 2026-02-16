// ItemSelectionGridView.swift
// Grid view for picking multiple items to style

import SwiftUI
import SwiftData

struct ItemSelectionGridView: View {
    let items: [ClothingItem]
    @Binding var selectedItems: Set<UUID>
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @State private var selectedCategory: Category?
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var filteredItems: [ClothingItem] {
        if let selectedCategory = selectedCategory {
            return items.filter { $0.category?.name == selectedCategory.name }
        }
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Filter Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" button
                    CategoryFilterButton(
                        title: "ALL",
                        isSelected: selectedCategory == nil,
                        count: items.count
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                        }
                    }
                    
                    // Category buttons
                    ForEach(categories) { category in
                        let itemCount = items.filter { $0.category?.name == category.name }.count
                        
                        CategoryFilterButton(
                            title: category.name.uppercased(),
                            isSelected: selectedCategory?.id == category.id,
                            count: itemCount
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(PoshTheme.Colors.canvas)
            
            Divider()
                .background(PoshTheme.Colors.ink.opacity(0.1))
            
            // Item Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        SelectableItemThumbnail(
                            item: item,
                            isSelected: selectedItems.contains(item.id)
                        ) {
                            toggleSelection(for: item)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func toggleSelection(for item: ClothingItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
}

struct SelectableItemThumbnail: View {
    let item: ClothingItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ItemThumbnailView(item: item, showLabel: false)
                    .scaleEffect(isSelected ? 0.95 : 1.0)
                    .overlay(
                        Rectangle()
                            .stroke(PoshTheme.Colors.ink, lineWidth: isSelected ? 3 : 0)
                    )
                
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(PoshTheme.Colors.ink)
                        .background(
                            Circle()
                                .fill(.white)
                                .padding(2)
                        )
                        .padding(6)
                }
            }
        }
        .buttonStyle(NoHighlightButtonStyle())
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Category Filter Button

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isSelected ? .white : PoshTheme.Colors.ink.opacity(0.6))
                
                // Count badge
                Text("\(count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? PoshTheme.Colors.gold : PoshTheme.Colors.ink.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white.opacity(0.2) : PoshTheme.Colors.stone)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? PoshTheme.Colors.gold : Color.white)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : PoshTheme.Colors.ink.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: isSelected ? PoshTheme.Colors.gold.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
