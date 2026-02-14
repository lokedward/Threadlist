// ItemSelectionGridView.swift
// Grid view for picking multiple items to style

import SwiftUI

struct ItemSelectionGridView: View {
    let items: [ClothingItem]
    @Binding var selectedItems: Set<UUID>
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
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
                ItemThumbnailView(item: item, showLabel: true)
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
