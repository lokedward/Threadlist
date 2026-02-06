// ItemThumbnailView.swift
// Reusable thumbnail component for clothing items

import SwiftUI

enum ThumbnailSize {
    case small
    case large
    
    var dimension: CGFloat {
        switch self {
        case .small: return 140
        case .large: return 0 // flexible
        }
    }
}

struct ItemThumbnailView: View {
    let item: ClothingItem
    var size: ThumbnailSize = .small
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image Container
            Rectangle()
                .fill(PoshTheme.Colors.secondaryAccent.opacity(0.05))
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "handbag")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3))
                    }
                }
                .clipped()
            
            // Info Overlay
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.secondaryAccent)
                    }
                    
                    Text(item.name)
                        .poshHeadline(size: 13)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PoshTheme.Colors.cardBackground.opacity(0.85))
                .background(.ultraThinMaterial)
            }
        }
        .frame(width: size == .small ? size.dimension : nil)
        .poshCard()
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        image = ImageStorageService.shared.loadImage(withID: item.imageID)
    }
}

#Preview {
    let item = ClothingItem(name: "Vintage Denim Jacket", brand: "Levi's")
    return ItemThumbnailView(item: item)
        .padding()
}
