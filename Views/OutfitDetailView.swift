import SwiftUI
import SwiftData

struct OutfitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let outfit: Outfit
    let heroImage: UIImage
    
    @State private var isProcessingShare = false
    @State private var showTearSheetPreview = false
    @State private var tearSheetImage: UIImage?
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            VStack {
                ZoomableImageView(image: heroImage)
                    .frame(maxHeight: .infinity)
                
                // Bottom Controls
                HStack {
                    Button(role: .destructive) {
                        deleteOutfit()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                            Text("DELETE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .poshCard()
                    }
                    
                    Button {
                        shareOutfit()
                    } label: {
                        VStack(spacing: 4) {
                            if isProcessingShare {
                                ProgressView()
                                    .tint(.white)
                                    .frame(height: 20)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                            }
                            Text("SHARE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                        }
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PoshTheme.Colors.ink)
                        .cornerRadius(0) // Posh style
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .disabled(isProcessingShare)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            
            // Error Overlay
            if let error = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .poshBody(size: 12)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .poshCard()
                    .padding()
                    .transition(.move(edge: .bottom))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        errorMessage = nil
                    }
                }
            }
        }
        .navigationTitle("Curated Look")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTearSheetPreview) {
            if let imageToShare = tearSheetImage {
                TearSheetPreviewView(image: imageToShare)
            }
        }
    }
    
    private func deleteOutfit() {
        if let imageID = outfit.generatedImageID {
            ImageStorageService.shared.deleteImage(withID: imageID)
        }
        modelContext.delete(outfit)
        dismiss()
    }
    
    private func shareOutfit() {
        isProcessingShare = true
        errorMessage = nil
        
        Task {
            var rawImages: [UIImage] = []
            // Using the outfit items array loaded via SwiftData relationship
            for item in outfit.items {
                if let img = await ImageStorageService.shared.loadImage(withID: item.imageID) {
                    rawImages.append(img)
                }
            }
            
            let cutouts = try? await ImageProcessingService.shared.processClothingImages(rawImages)
            
            await MainActor.run {
                let tearSheet = OutfitTearSheet(
                    heroImage: heroImage,
                    cutoutImages: cutouts ?? rawImages,
                    title: "Curated Look".uppercased()
                )
                
                let renderer = ImageRenderer(content: tearSheet)
                renderer.scale = 3.0 // High res scale
                
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
