// StylingCanvasView.swift
// View for generating AI-styled model photos with tier support

import SwiftUI
import SwiftData

struct StylingCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    let selectedItems: [ClothingItem]
    let gender: Gender
    
    // External state management
    @Binding var generatedImage: UIImage?
    @Binding var isGenerating: Bool
    @Binding var isSaved: Bool
    
    @State private var errorMessage: String?
    @State private var showUpgradePrompt = false
    @State private var dynamicLoadingMessage = "CREATING YOUR LOOK"
    @State private var lastGeneratedItemIds: Set<UUID> = []
    
    // Share Sheet State
    @State private var isProcessingShare = false
    @State private var showTearSheetPreview = false
    @State private var tearSheetImage: UIImage?
    
    let stylistService = StylistService.shared
    
    private var hasSelectionChanged: Bool {
        let currentIds = Set(selectedItems.map { $0.id })
        return currentIds != lastGeneratedItemIds
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            RadialGradient(
                colors: [PoshTheme.Colors.ink.opacity(0.05), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            
            if isGenerating {
                // Loading state - Blocall user interaction when generating
                VStack(spacing: 48) {
                    BrandLogoView(isAnimating: true, speed: 0.8)
                        .frame(width: 140, height: 140)
                    
                    VStack(spacing: 16) {
                        Text(dynamicLoadingMessage.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(4)
                            .foregroundColor(PoshTheme.Colors.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(usageMessage)
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                    }
                }
                .padding(.vertical, 60)
                .padding(.horizontal, 40)
                .background(Color.white.opacity(0.95))
                .poshCard()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let generated = generatedImage {
                // Show generated model photo
                VStack(spacing: 8) {
                    ZoomableImageView(image: generated)
                        .frame(maxHeight: 500) // Contain the zoomable area
                        .poshCard()
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text("Pinch to zoom • Double tap to reset")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                        .padding(.bottom, 8)
                    
                    // Regenerate, Save or Share buttons
                    HStack(spacing: 8) {
                        Button {
                            // If items haven't changed, user is intentionally asking for a different look/pose
                            generateLook(bypassCache: !hasSelectionChanged)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: hasSelectionChanged ? "sparkles" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20))
                                Text(hasSelectionChanged ? "NEW" : "RETRY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                            }
                            .foregroundColor(PoshTheme.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .poshCard()
                        }
                        
                        Button {
                            saveOutfit()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: isSaved ? "heart.fill" : "heart")
                                    .font(.system(size: 20))
                                Text(isSaved ? "SAVED" : "SAVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                            }
                            .foregroundColor(Color.white) // Use direct white
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSaved ? PoshTheme.Colors.ink.opacity(0.5) : PoshTheme.Colors.ink)
                            .cornerRadius(0) // Posh style
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isSaved)
                        
                        Button {
                            shareOutfit()
                        } label: {
                            VStack(spacing: 4) {
                                if isProcessingShare {
                                    ProgressView()
                                        .tint(PoshTheme.Colors.ink)
                                        .frame(height: 20)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                }
                                Text("SHARE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                            }
                            .foregroundColor(PoshTheme.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .poshCard()
                        }
                        .disabled(isProcessingShare)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                // Combined state for Empty and Ready to Generate to ensure layout stability
                ZStack {
                    // Central Brand Piece - anchored so it never shifts
                    VStack(spacing: 24) {
                        BrandLogoView(isAnimating: selectedItems.isEmpty)
                            .frame(width: 140, height: 140)
                        
                        if selectedItems.isEmpty {
                            Text("SELECT PIECES TO START STYLING")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(3)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom Controls - anchored to bottom, won't affect central piece
                    if !selectedItems.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            
                            if SubscriptionService.shared.currentTier == .free {
                                let remaining = SubscriptionService.shared.currentTier.styleMeLimit - SubscriptionService.shared.generationCount
                                Text("\(max(0, remaining)) free suggestions remaining today")
                                    .poshBody(size: 12)
                                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                            }
                            
                            Button {
                                if SubscriptionService.shared.canPerformStyleMe() {
                                    generateLook()
                                } else {
                                    showUpgradePrompt = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                    Text(SubscriptionService.shared.currentTier == .free ? "GENERATE LOOK (FREE)" : "GENERATE LOOK")
                                        .tracking(2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .poshButton()
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            // Error overlay
            if let error = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: error.contains("limit") ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                            .foregroundColor(error.contains("limit") ? .orange : .red)
                        Text(error)
                            .poshBody(size: 12)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .poshCard()
                    .padding()
                    .transition(.move(edge: .bottom))
                    .onTapGesture {
                        if error.contains("limit") {
                            showUpgradePrompt = true
                        }
                    }
                }
                .onAppear {
                    if !error.contains("limit") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                errorMessage = nil
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            PaywallView()
        }
        .sheet(isPresented: $showTearSheetPreview) {
            if let imageToShare = tearSheetImage {
                TearSheetPreviewView(image: imageToShare)
            }
        }
    }
    
    private var usageMessage: String {
        let service = SubscriptionService.shared
        let used = service.currentTier.limitPeriod == .monthly ? service.monthlyGenerationCount : service.generationCount
        let limit = service.currentTier.styleMeLimit
        
        if service.currentTier == .free {
            return "\(limit - used) of \(limit) monthly looks remaining"
        } else {
            let period = service.currentTier.limitPeriod == .monthly ? "month" : "day"
            return "\(limit - used) of \(limit) looks left this \(period)"
        }
    }
    
    func generateLook(bypassCache: Bool = false) {
        guard !selectedItems.isEmpty, !isGenerating else { return }
        
        let currentIds = Set(selectedItems.map { $0.id })
        
        dynamicLoadingMessage = LoadingMessageService.shared.randomMessage(for: .generation)
        errorMessage = nil
        isGenerating = true
        
        Task {
            do {
                let image = try await StylistService.shared.generateModelPhoto(
                    items: selectedItems,
                    gender: gender,
                    bypassCache: bypassCache
                )
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.lastGeneratedItemIds = currentIds
                        self.generatedImage = image
                        self.isGenerating = false
                        self.isSaved = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    withAnimation {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func saveOutfit() {
        guard let image = generatedImage else { return }
        
        Task {
            if let imageID = await ImageStorageService.shared.saveImage(image) {
                // Create Outfit
                let outfit = Outfit(generatedImageID: imageID, items: selectedItems)
                modelContext.insert(outfit)
                
                await MainActor.run {
                    isSaved = true
                }
            }
        }
    }
    
    private func shareOutfit() {
        guard let aiImage = generatedImage else { return }
        
        isProcessingShare = true
        errorMessage = nil
        
        Task {
            // 1. Fetch images using legacy sync call or async if available
            var rawImages: [UIImage] = []
            for item in selectedItems {
                if let img = await ImageStorageService.shared.loadImage(withID: item.imageID) {
                    rawImages.append(img)
                }
            }
            
            // 2. Process cutouts
            let cutouts = try? await ImageProcessingService.shared.processClothingImages(rawImages)
            
            // 3. Render View on Main thread
            await MainActor.run {
                let tearSheet = OutfitTearSheet(
                    heroImage: aiImage,
                    cutoutImages: cutouts ?? rawImages,
                    title: "Curated Look".uppercased()
                )
                
                let renderer = ImageRenderer(content: tearSheet)
                renderer.scale = 3.0 // High res scale for sharing
                
                if let cgImage = renderer.cgImage {
                    self.tearSheetImage = UIImage(cgImage: cgImage)
                    self.showTearSheetPreview = true
                } else {
                    self.errorMessage = "Failed to render share image."
                }
                
                self.isProcessingShare = false
            }
        }
    }
}

// MARK: - Upgrade Prompt REMOVED (Use PaywallView instead)

#Preview {
    StylingCanvasView(
        selectedItems: [],
        gender: .female,
        generatedImage: .constant(nil),
        isGenerating: .constant(false),
        isSaved: .constant(false)
    )
}
