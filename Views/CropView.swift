import SwiftUI
import UIKit

struct CropView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    // Configuration
    // Standard industry crop is Square (1:1) or Portrait (4:5). 
    // Let's stick to Square 1:1 for a consistent grid layout in the app.
    private let cropAspectRatio: CGFloat = 1.0 
    
    // View State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewState: CGSize = .zero // For drag gesture
    
    // Layout State
    @State private var containerSize: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var cropSize: CGSize = .zero
    
    // UX constants
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Solid Cinematic Background
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        if imageSize != .zero {
                            // 2. The Interaction Layer (Dual Image)
                            ZStack {
                                // Layer A: The "Greyed Out" Background (Entire Image)
                                imageView
                                    .opacity(0.4)
                                
                                // Layer B: The "Clear" Crop Area (Clipped Viewport)
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: cropSize.width, height: cropSize.height)
                                    .overlay {
                                        imageView
                                    }
                                    .clipped()
                                
                                // Layer C: Tertiary Editorial Polish (Grid)
                                GridView(size: cropSize)
                                    .allowsHitTesting(false)
                            }
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { val in
                                            let delta = val / lastScale
                                            lastScale = val
                                            let newScale = scale * delta
                                            scale = min(max(newScale, minScale), maxScale)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            withAnimation(.spring()) {
                                                validateBounds()
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { val in
                                            let dragTranslation = CGSize(
                                                width: val.translation.width + lastOffset.width,
                                                height: val.translation.height + lastOffset.height
                                            )
                                            offset = dragTranslation
                                        }
                                        .onEnded { val in
                                            lastOffset = offset
                                            withAnimation(.spring()) {
                                                validateBounds()
                                            }
                                        }
                                )
                            )
                        }
                    }
                    .onAppear {
                        configureLayout(in: geometry.size)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        configureLayout(in: newSize)
                    }
                }
            }
            .navigationTitle("Position & Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        if let cropped = cropImage() {
                            onComplete(cropped)
                        } else {
                            onComplete(image)
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(PoshTheme.Colors.canvas)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
    
    // Helper view to keep layers in sync
    private var imageView: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: imageSize.width, height: imageSize.height)
            .scaleEffect(scale)
            .offset(x: offset.width, y: offset.height)
    }
    
    // MARK: - Setup & Layout Logic
    
    private func configureLayout(in size: CGSize) {
        containerSize = size
        
        // 1. Calculate Crop Box Size (Square with padding)
        let padding: CGFloat = 20
        let availableWidth = size.width - (padding * 2)
        // Ensure we don't exceed available height
        let cropDimension = min(availableWidth, size.height - 150)
        
        cropSize = CGSize(width: cropDimension, height: cropDimension / cropAspectRatio)
        
        // 2. Calculate Base Image Size (Aspect Fill)
        // The image usually starts fitting the crop box perfectly
        let imgRatio = image.size.width / image.size.height
        let cropRatio = cropSize.width / cropSize.height
        
        if imgRatio > cropRatio {
            // Image is wider than crop -> Fit Height, Scale Width
            let height = cropSize.height
            let width = height * imgRatio
            imageSize = CGSize(width: width, height: height)
        } else {
            // Image is taller -> Fit Width, Scale Height
            let width = cropSize.width
            let height = width / imgRatio
            imageSize = CGSize(width: width, height: height)
        }
        
        // 3. Reset State
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    // MARK: - Bounds Validation (Rubber Banding)
    
    private func validateBounds() {
        // Enforce: Image must cover the cropSize at all times.
        
        // Calculate current visual size
        let visualWidth = imageSize.width * scale
        let visualHeight = imageSize.height * scale
        
        // Calculate limits for offset
        // How much "extra" image do we have beyond the crop box?
        let horizontalOverflow = (visualWidth - cropSize.width) / 2
        let verticalOverflow = (visualHeight - cropSize.height) / 2
        
        // Offset limit is +/- the overflow amount
        // If we drag right (positive), we can't show left blank space.
        // Limit: maxX = horizontalOverflow
        
        var newX = offset.width
        var newY = offset.height
        
        if horizontalOverflow > 0 {
            newX = min(max(newX, -horizontalOverflow), horizontalOverflow)
        } else {
            newX = 0
        }
        
        if verticalOverflow > 0 {
            newY = min(max(newY, -verticalOverflow), verticalOverflow)
        } else {
            newY = 0
        }
        
        offset = CGSize(width: newX, height: newY)
        lastOffset = offset
        
        // Re-enforce min scale if user pinched too small
        if scale < minScale {
            scale = minScale
        }
    }
    
    // MARK: - Cropping Logic
    
    private func cropImage() -> UIImage? {
        // We need to map the "Crop Box" (screen coordinates) back to the "Original Image" (pixel coordinates).
        
        // 1. Determine the visible rect relative to the Image View
        // The image view is centered. The crop box is centered.
        // The difference is determined by `scale` and `offset`.
        
        // Center of the image view (in its own coordinate system)
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        // The scale factor between the Screen Image and the Original UIImage
        // We rendered the image at `imageSize`. The original is `image.size`.
        let renderRatio = image.size.width / imageSize.width
        
        // Calculate the "Viewport" rectangle on the Rendered Image (pre-scale)
        // Offset moves the image, so effectively it moves the crop rect in the opposite direction relative to image center
        let visibleWidth = cropSize.width / scale
        let visibleHeight = cropSize.height / scale
        
        let visibleX = centerX - (visibleWidth / 2) - (offset.width / scale)
        let visibleY = centerY - (visibleHeight / 2) - (offset.height / scale)
        
        // 2. Convert to Original Image Coordinates
        let cropX = visibleX * renderRatio
        let cropY = visibleY * renderRatio
        let cropW = visibleWidth * renderRatio
        let cropH = visibleHeight * renderRatio
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        
        // 3. Perform Crop
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Visual Polish

struct GridView: View {
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Rule of Thirds
            VStack {
                Divider().background(Color.white.opacity(0.3))
                Spacer()
                Divider().background(Color.white.opacity(0.3))
            }
            .frame(width: size.width, height: size.height)
            .padding(.vertical, size.height / 3)
            
            HStack {
                Divider().background(Color.white.opacity(0.3))
                Spacer()
                Divider().background(Color.white.opacity(0.3))
            }
            .frame(width: size.width, height: size.height)
            .padding(.horizontal, size.width / 3)
        }
    }
}