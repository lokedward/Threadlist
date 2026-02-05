import SwiftUI
import UIKit



struct CropView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    // Crop frame state
    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    
    // Interaction state
    @State private var isDraggingCrop = false
    @State private var cropDragStart: CGPoint = .zero
    @State private var cropRectAtDragStart: CGRect = .zero
    
    @State private var isPinchingCrop = false
    @State private var cropRectAtPinchStart: CGRect = .zero
    
    // Static image state (no more imageScale/imageOffset)
    

    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Loading state if frame isn't ready
                    if imageFrame == .zero {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                    
                    // Image layer (Fixed background)
                    if imageFrame != .zero {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageFrame.width, height: imageFrame.height)
                            .position(x: imageFrame.midX, y: imageFrame.midY)
                    }
                    
                    // Crop overlay with interative box
                    if imageFrame != .zero {
                        CropOverlay(
                            cropRect: $cropRect,
                            isDraggingCrop: $isDraggingCrop,
                            cropDragStart: $cropDragStart,
                            cropRectAtDragStart: $cropRectAtDragStart,
                            imageFrame: imageFrame,
                            viewSize: geometry.size
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black.ignoresSafeArea())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if !isPinchingCrop {
                                isPinchingCrop = true
                                cropRectAtPinchStart = cropRect
                            }
                            updateCropScale(value)
                        }
                        .onEnded { _ in
                            isPinchingCrop = false
                        }
                )
                .onChange(of: geometry.size) { _, newSize in
                    setupFrame(in: newSize)
                }
                .onAppear {
                    setupFrame(in: geometry.size)
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
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        let x = (viewSize.width - displaySize.width) / 2
        let y = (viewSize.height - displaySize.height) / 2
        
        return CGRect(x: x, y: y, width: displaySize.width, height: displaySize.height)
    }
    
    private func setupFrame(in viewSize: CGSize) {
        guard viewSize.width > 50 && viewSize.height > 50 else { return }
        
        imageFrame = calculateImageFrame(in: viewSize)
        
        if cropRect == .zero {
            // Start crop window as the entire image
            cropRect = imageFrame
        }
    }
    
    private func updateCropScale(_ scale: CGFloat) {
        let startRect = cropRectAtPinchStart
        var newWidth = startRect.width * scale
        var newHeight = startRect.height * scale
        
        // Maintain the aspect ratio of the initial image/crop choice
        let ratio = startRect.width / startRect.height
        
        // Maximum constraints (image bounds)
        if newWidth > imageFrame.width {
            newWidth = imageFrame.width
            newHeight = newWidth / ratio
        }
        if newHeight > imageFrame.height {
            newHeight = imageFrame.height
            newWidth = newHeight * ratio
        }
        
        // Minimum constraints
        if newWidth < 80 || newHeight < 80 {
            newWidth = max(newWidth, 80)
            newHeight = newWidth / ratio
        }
        
        // Calculate new origin to keep it centered during pinch
        let oldCenter = CGPoint(x: startRect.midX, y: startRect.midY)
        var newX = oldCenter.x - newWidth / 2
        var newY = oldCenter.y - newHeight / 2
        
        // Clamping to stay inside imageFrame
        if newX < imageFrame.minX { newX = imageFrame.minX }
        if newY < imageFrame.minY { newY = imageFrame.minY }
        if newX + newWidth > imageFrame.maxX { newX = imageFrame.maxX - newWidth }
        if newY + newHeight > imageFrame.maxY { newY = imageFrame.maxY - newHeight }
        
        cropRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    private func handleDone() {
        let croppedImage = cropImage()
        onComplete(croppedImage)
    }
    
    private func cropImage() -> UIImage {
        let imageSize = image.size
        
        // Calculate coordinates relative to the imageFrame (where the image is actually drawn)
        let relativeX = (cropRect.minX - imageFrame.minX) / imageFrame.width
        let relativeY = (cropRect.minY - imageFrame.minY) / imageFrame.height
        let relativeW = cropRect.width / imageFrame.width
        let relativeH = cropRect.height / imageFrame.height
        
        let cropInImageCoords = CGRect(
            x: relativeX * imageSize.width,
            y: relativeY * imageSize.height,
            width: relativeW * imageSize.width,
            height: relativeH * imageSize.height
        )
        
        if let cgImage = image.cgImage?.cropping(to: cropInImageCoords) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
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
            
            // Crop rectangle area (Interactive)
            Rectangle()
                .fill(Color.white.opacity(0.001)) // Transparent but interactive
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                )
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
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
        
        // Keep crop frame within visible image bounds (bounds passed in as imageFrame)
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
