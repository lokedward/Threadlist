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
    @State private var minScale: CGFloat = 1.0
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
        
        // 3. Calculate Min Scale (Aspect Fit)
        // This allows us to zoom out until the whole image is visible inside the crop box
        if imgRatio > cropRatio {
            // Image is wider -> Min scale is when width fits
            minScale = cropSize.width / width
        } else {
            // Image is taller -> Min scale is when height fits
            minScale = cropSize.height / height
        }
        
        // 4. Reset State
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
            // Centering if zoomed out beyond the width
            newX = 0
        }
        
        if verticalOverflow > 0 {
            newY = min(max(newY, -verticalOverflow), verticalOverflow)
        } else {
            // Centering if zoomed out beyond the height
            newY = 0
        }
        
        offset = CGSize(width: newX, height: newY)
        lastOffset = offset
        
        // We still allow a bit of "bounce" but usually we'd snap here
        if scale < minScale {
            scale = minScale
        }
    }
    
    // MARK: - Cropping Logic
    
    private func cropImage() -> UIImage? {
        // We need to create a square image that represents what the user sees in the crop box.
        // Instead of just cropping the original CGImage (which fails if we want padding),
        // we use UIGraphicsImageRenderer to draw the original image into a new square canvas.
        
        let outputSize = CGSize(width: 2000, height: 2000) // High-res square output
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        
        // The scale factor between our screen `cropSize` and the `outputSize`
        let outputScale = outputSize.width / cropSize.width
        
        return renderer.image { context in
            // 1. Background Fill (Cinematic Black)
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            
            // 2. Draw the image with user's transform
            // We need to map: (Image Center + Offset) * OutputScale
            
            let drawWidth = imageSize.width * scale * outputScale
            let drawHeight = imageSize.height * scale * outputScale
            
            // The position of the image center relative to the crop box center (which is the center of our output canvas)
            let drawX = (outputSize.width / 2) - (drawWidth / 2) + (offset.width * outputScale)
            let drawY = (outputSize.height / 2) - (drawHeight / 2) + (offset.height * outputScale)
            
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
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