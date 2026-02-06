// ItemSelectionGridView.swift
// Grid view for picking multiple items to style

import SwiftUI

struct ItemSelectionGridView: View {
    let items: [ClothingItem]
    @Binding var selectedItems: Set<UUID>
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
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
                ItemThumbnailView(item: item)
                    .scaleEffect(isSelected ? 0.95 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PoshTheme.Colors.primaryAccentStart, lineWidth: isSelected ? 3 : 0)
                    )
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                        .background(Circle().fill(.white))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
