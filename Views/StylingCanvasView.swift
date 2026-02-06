// StylingCanvasView.swift
// View for layering items on a model

import SwiftUI

struct StylingCanvasView: View {
    let selectedItems: [ClothingItem]
    let gender: StylistView.Gender
    
    var body: some View {
        ZStack {
            // Model Placeholder
            VStack {
                Spacer()
                Image(systemName: gender == .female ? "figure.stand" : "figure.stand.dress")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 400)
                    .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.1))
                Spacer()
            }
            
            // Layered Items
            ZStack {
                ForEach(selectedItems.sorted { 
                    StylistService.shared.layeringOrder(for: $0) < StylistService.shared.layeringOrder(for: $1)
                }) { item in
                    ItemLayer(item: item)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            
            // "Vibe Check" Overlay
            VStack {
                Spacer()
                if !selectedItems.isEmpty {
                    VibeCheckView(items: selectedItems)
                        .padding(.bottom, 20)
                }
            }
            
            if selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    
                    Text("SELECT PIECES TO START STYLING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                }
            }
        }
        .background(
            RadialGradient(
                colors: [PoshTheme.Colors.primaryAccentEnd.opacity(0.05), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        )
    }
}

struct VibeCheckView: View {
    let items: [ClothingItem]
    @State private var advice: String = "Analyzing your look..."
    @State private var isAnalyzing = true
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                Text("GEMINI VIBE CHECK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
            }
            
            if isAnalyzing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(advice)
                    .poshBody(size: 14)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(20)
        .poshCard()
        .padding(.horizontal, 40)
        .task(id: items) {
            isAnalyzing = true
            advice = await StylistService.shared.getVibeCheck(for: items)
            isAnalyzing = false
        }
    }
}

struct ItemLayer: View {
    let item: ClothingItem
    @State private var image: UIImage?
    @State private var offset: CGSize = .zero
    
    var body: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: frameHeight)
                    .poshCard()
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                    )
            } else {
                Color.clear
                    .onAppear {
                        image = ImageStorageService.shared.loadImage(withID: item.imageID)
                    }
            }
        }
    }
    
    private var frameHeight: CGFloat {
        let order = StylistService.shared.layeringOrder(for: item)
        if order >= 50 { return 100 } // Shoes
        if order >= 40 { return 300 } // Outerwear
        return 220 // Tops/Bottoms
    }
}
