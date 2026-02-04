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
    
    // Fixed square crop frame
    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    
    // Crop frame dragging
    @State private var isDraggingCrop = false
    @State private var cropDragStart: CGPoint = .zero
    @State private var cropRectAtDragStart: CGRect = .zero
    
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
                        .background(
                            GeometryReader { imageGeometry in
                                Color.clear
                                    .onAppear {
                                        // Get the actual frame of the image in the parent coordinate space
                                        let frame = imageGeometry.frame(in: .named("CropContainer"))
                                        if imageFrame == .zero {
                                            imageFrame = frame
                                        }
                                    }
                                    .onChange(of: imageGeometry.size) { _, _ in
                                        imageFrame = imageGeometry.frame(in: .named("CropContainer"))
                                    }
                            }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    imageScale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = imageScale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isDraggingCrop {
                                        imageOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if !isDraggingCrop {
                                        lastOffset = imageOffset
                                    }
                                }
                        )
                    
                    // Crop overlay
                    CropOverlay(
                        cropRect: $cropRect,
                        isDraggingCrop: $isDraggingCrop,
                        cropDragStart: $cropDragStart,
                        cropRectAtDragStart: $cropRectAtDragStart,
                        imageFrame: imageFrame,
                        viewSize: geometry.size
                    )
                }
                .coordinateSpace(name: "CropContainer")
                .onChange(of: geometry.size) { _, newSize in
                    if cropRect == .zero && newSize.width > 0 && newSize.height > 0 {
                        imageFrame = calculateImageFrame(in: newSize)
                        cropRect = calculateInitialCropRect(in: newSize)
                    }
                }
                .onAppear {
                    if geometry.size.width > 0 && geometry.size.height > 0 {
                        imageFrame = calculateImageFrame(in: geometry.size)
                        cropRect = calculateInitialCropRect(in: geometry.size)
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
            // Image is wider - fits to width
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // Image is taller - fits to height
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        // Center within the available view size
        let x = (viewSize.width - displaySize.width) / 2
        let y = (viewSize.height - displaySize.height) / 2
        
        return CGRect(x: x, y: y, width: displaySize.width, height: displaySize.height)
    }
    
    private func calculateInitialCropRect(in viewSize: CGSize) -> CGRect {
        // Create a square crop frame, 70% of the smaller screen dimension
        let size = min(viewSize.width, viewSize.height) * 0.7
        let x = (viewSize.width - size) / 2
        let y = (viewSize.height - size) / 2
        
        return CGRect(x: x, y: y, width: size, height: size)
    }
    
    private func handleDone() {
        let croppedImage = cropImage()
        onComplete(croppedImage)
    }
    
    private func cropImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropRect.width, height: cropRect.height))
        
        return renderer.image { context in
            let imageSize = image.size
            let screenSize = UIScreen.main.bounds.size
            let imageAspect = imageSize.width / imageSize.height
            let screenAspect = screenSize.width / screenSize.height
            
            var displaySize: CGSize
            if imageAspect > screenAspect {
                displaySize = CGSize(width: screenSize.width, height: screenSize.width / imageAspect)
            } else {
                displaySize = CGSize(width: screenSize.height * imageAspect, height: screenSize.height)
            }
            
            displaySize = CGSize(
                width: displaySize.width * imageScale,
                height: displaySize.height * imageScale
            )
            
            let imageCenter = CGPoint(
                x: screenSize.width / 2 + imageOffset.width,
                y: screenSize.height / 2 + imageOffset.height
            )
            
            let currentImageFrame = CGRect(
                x: imageCenter.x - displaySize.width / 2,
                y: imageCenter.y - displaySize.height / 2,
                width: displaySize.width,
                height: displaySize.height
            )
            
            let relativeRect = CGRect(
                x: (cropRect.minX - currentImageFrame.minX) / displaySize.width,
                y: (cropRect.minY - currentImageFrame.minY) / displaySize.height,
                width: cropRect.width / displaySize.width,
                height: cropRect.height / displaySize.height
            )
            
            let cropInImageCoords = CGRect(
                x: relativeRect.minX * imageSize.width,
                y: relativeRect.minY * imageSize.height,
                width: relativeRect.width * imageSize.width,
                height: relativeRect.height * imageSize.height
            )
            
            if let cgImage = image.cgImage?.cropping(to: cropInImageCoords) {
                let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                croppedImage.draw(in: CGRect(origin: .zero, size: cropRect.size))
            } else {
                image.draw(in: CGRect(origin: .zero, size: cropRect.size))
            }
        }
    }
}

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    @Binding var isDraggingCrop: Bool
    @Binding var cropDragStart: CGPoint
    @Binding var cropRectAtDragStart: CGRect
    let imageFrame: CGRect
    let viewSize: CGSize
    
    var body: some View {
        ZStack {
            // Dimmed overlay outside crop area
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
            
            // Crop rectangle border (white, clean)
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDraggingCrop {
                                isDraggingCrop = true
                                cropDragStart = value.startLocation
                                cropRectAtDragStart = cropRect
                            }
                            
                            let translation = CGSize(
                                width: value.location.x - cropDragStart.x,
                                height: value.location.y - cropDragStart.y
                            )
                            
                            updateCropPosition(translation: translation)
                        }
                        .onEnded { _ in
                            isDraggingCrop = false
                        }
                )
        }
    }
    
    private func updateCropPosition(translation: CGSize) {
        var newRect = cropRectAtDragStart
        newRect.origin.x += translation.width
        newRect.origin.y += translation.height
        
        // Keep crop frame within image bounds
        if newRect.minX < imageFrame.minX {
            newRect.origin.x = imageFrame.minX
        }
        if newRect.maxX > imageFrame.maxX {
            newRect.origin.x = imageFrame.maxX - newRect.width
        }
        if newRect.minY < imageFrame.minY {
            newRect.origin.y = imageFrame.minY
        }
        if newRect.maxY > imageFrame.maxY {
            newRect.origin.y = imageFrame.maxY - newRect.height
        }
        
        cropRect = newRect
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
