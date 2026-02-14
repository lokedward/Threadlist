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
    var showLabel: Bool = false
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image Container
            Rectangle()
                .fill(PoshTheme.Colors.ink.opacity(0.05))
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "handbag")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                    }
                }
                .clipped()
            
            // Info Overlay (conditionally shown)
            if showLabel {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        if let brand = item.brand, !brand.isEmpty {
                            Text(brand.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                                .lineLimit(1)
                        }
                        
                        Text(item.name)
                            .poshHeadline(size: 13)
                            .foregroundColor(PoshTheme.Colors.headline.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.85))
                    .background(.ultraThinMaterial)
                }
                .clipped()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .poshCard()
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            if let loaded = await ImageStorageService.shared.loadImage(withID: item.imageID) {
                await MainActor.run {
                    self.image = loaded
                }
            }
        }
    }
}

#Preview {
    let item = ClothingItem(name: "Vintage Denim Jacket", brand: "Levi's")
    return ItemThumbnailView(item: item)
        .padding()
}
