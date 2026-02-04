import SwiftUI
import UIKit

struct CropView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    // Track the actual image display frame
    @State private var imageFrame: CGRect = .zero
    // Crop rectangle in screen coordinates
    @State private var cropRect: CGRect = .zero
    @State private var draggedCorner: Corner?
    
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Image layer (zoomable/pannable)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(imageScale)
                        .offset(imageOffset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    imageScale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = imageScale
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    imageOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = imageOffset
                                }
                        )
                    
                    // Crop overlay
                    CropOverlay(
                        cropRect: $cropRect,
                        draggedCorner: $draggedCorner,
                        imageFrame: $imageFrame,
                        viewSize: geometry.size
                    )
                }
                .onChange(of: geometry.size) { _, newSize in
                    // Only initialize once when geometry is actually ready
                    if cropRect == .zero && newSize.width > 0 && newSize.height > 0 {
                        // Calculate initial image display frame
                        imageFrame = calculateImageFrame(in: newSize)
                        
                        // Initialize crop rect to match image bounds (full image)
                        cropRect = imageFrame
                    }
                }
                .onAppear {
                    // Trigger initial calculation
                    if geometry.size.width > 0 && geometry.size.height > 0 {
                        imageFrame = calculateImageFrame(in: geometry.size)
                        cropRect = imageFrame
                    }
                }
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { handleDone() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func calculateImageFrame(in viewSize: CGSize) -> CGRect {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displaySize: CGSize
        if imageAspect > viewAspect {
            // Image is wider, fit to width
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // Image is taller, fit to height
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        // Center the image in the view
        let x = (viewSize.width - displaySize.width) / 2
        let y = (viewSize.height - displaySize.height) / 2
        
        return CGRect(x: x, y: y, width: displaySize.width, height: displaySize.height)
    }
    
    private func handleDone() {
        // Convert crop rect to image coordinates and extract
        let croppedImage = cropImage()
        onComplete(croppedImage)
    }
    
    private func cropImage() -> UIImage {
        // We need to map the crop rectangle (screen coordinates) to image coordinates
        // accounting for scale and offset
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropRect.width, height: cropRect.height))
        
        return renderer.image { context in
            // Calculate the image's actual display frame considering scale and offset
            let imageSize = image.size
            
            // The image is displayed with aspectRatio(.fit), so calculate its display size
            let screenSize = UIScreen.main.bounds.size
            let imageAspect = imageSize.width / imageSize.height
            let screenAspect = screenSize.width / screenSize.height
            
            var displaySize: CGSize
            if imageAspect > screenAspect {
                // Image is wider, fit to width
                displaySize = CGSize(width: screenSize.width, height: screenSize.width / imageAspect)
            } else {
                // Image is taller, fit to height
                displaySize = CGSize(width: screenSize.height * imageAspect, height: screenSize.height)
            }
            
            // Apply scale
            displaySize = CGSize(
                width: displaySize.width * imageScale,
                height: displaySize.height * imageScale
            )
            
            // Calculate image center with offset
            let imageCenter = CGPoint(
                x: screenSize.width / 2 + imageOffset.width,
                y: screenSize.height / 2 + imageOffset.height
            )
            
            // Image frame in screen coordinates
            let currentImageFrame = CGRect(
                x: imageCenter.x - displaySize.width / 2,
                y: imageCenter.y - displaySize.height / 2,
                width: displaySize.width,
                height: displaySize.height
            )
            
            // Calculate crop rect relative to image frame
            let relativeRect = CGRect(
                x: (cropRect.minX - currentImageFrame.minX) / displaySize.width,
                y: (cropRect.minY - currentImageFrame.minY) / displaySize.height,
                width: cropRect.width / displaySize.width,
                height: cropRect.height / displaySize.height
            )
            
            // Convert to image pixel coordinates
            let cropInImageCoords = CGRect(
                x: relativeRect.minX * imageSize.width,
                y: relativeRect.minY * imageSize.height,
                width: relativeRect.width * imageSize.width,
                height: relativeRect.height * imageSize.height
            )
            
            // Draw the cropped portion
            if let cgImage = image.cgImage?.cropping(to: cropInImageCoords) {
                let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                croppedImage.draw(in: CGRect(origin: .zero, size: cropRect.size))
            } else {
                // Fallback: draw the full image scaled
                image.draw(in: CGRect(origin: .zero, size: cropRect.size))
            }
        }
    }
}

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    @Binding var draggedCorner: CropView.Corner?
    @Binding var imageFrame: CGRect
    let viewSize: CGSize
    
    private let handleSize: CGFloat = 30
    private let minCropSize: CGFloat = 100
    
    @State private var initialCropRect: CGRect = .zero
    
    var body: some View {
        ZStack {
            // Dimmed overlay
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .frame(width: viewSize.width, height: viewSize.height)
                        .overlay(
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(x: cropRect.midX, y: cropRect.midY)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
            
            // Corner handles
            ForEach(CropView.Corner.allCases, id: \.self) { corner in
                Rectangle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .position(cornerPosition(corner))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if draggedCorner == nil {
                                    initialCropRect = cropRect
                                    draggedCorner = corner
                                }
                                updateCropRect(for: corner, translation: value.translation)
                            }
                            .onEnded { _ in
                                draggedCorner = nil
                            }
                    )
            }
        }
    }
    
    private func cornerPosition(_ corner: CropView.Corner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }
    
    private func updateCropRect(for corner: CropView.Corner, translation: CGSize) {
        var newRect = initialCropRect
        
        switch corner {
        case .topLeft:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
            
        case .topRight:
            newRect.origin.y += translation.height
            newRect.size.width += translation.width
            newRect.size.height -= translation.height
            
        case .bottomLeft:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
            
        case .bottomRight:
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        }
        
        // Enforce minimum size
        if newRect.width >= minCropSize && newRect.height >= minCropSize {
            // Keep within IMAGE bounds (not screen bounds)
            if newRect.minX >= imageFrame.minX && newRect.maxX <= imageFrame.maxX &&
               newRect.minY >= imageFrame.minY && newRect.maxY <= imageFrame.maxY {
                cropRect = newRect
            }
        }
    }
}

#Preview {
    if let sampleImage = UIImage(systemName: "photo.fill") {
        CropView(
            image: sampleImage,
            onComplete: { _ in },
            onCancel: {}
        )
    }
}
