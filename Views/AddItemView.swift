// AddItemView.swift
// Add new clothing item flow with image picker and metadata entry

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    
    // Image selection
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = true
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingImageCropper = false
    @State private var imageToCrop: UIImage?
    
    // Metadata
    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var brand = ""
    @State private var size = ""
    @State private var tagsText = ""
    
    @State private var isSaving = false
    
    var canSave: Bool {
        selectedImage != nil && !name.isEmpty && selectedCategory != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Image Section
                Section {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                imageToCrop = image
                                showingImageCropper = true
                            }
                        
                        HStack {
                            Button("Edit Photo") {
                                imageToCrop = selectedImage
                                showingImageCropper = true
                            }
                            
                            Spacer()
                            
                            Button("Change Photo") {
                                showingImageSourcePicker = true
                            }
                        }
                    } else {
                        Button {
                            showingImageSourcePicker = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("Add Photo")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                
                // Required Info
                Section("Item Details") {
                    TextField("Name", text: $name)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select a category").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                }
                
                // Optional Info
                Section("Additional Info (Optional)") {
                    TextField("Brand", text: $brand)
                    TextField("Size", text: $size)
                    TextField("Tags (comma separated)", text: $tagsText)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourcePicker) {
                Button("Take Photo") {
                    showingCamera = true
                }
                
                Button("Choose from Library") {
                    showingPhotoPicker = true
                }
                
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $imageToCrop, showCropper: $showingImageCropper)
            }
            .fullScreenCover(isPresented: $showingImageCropper) {
                if let image = imageToCrop {
                    ImageCropperView(image: image) { croppedImage in
                        selectedImage = croppedImage
                        showingImageCropper = false
                    } onCancel: {
                        showingImageCropper = false
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            imageToCrop = uiImage
                            showingImageCropper = true
                        }
                    }
                }
            }
            .onAppear {
                // Default to first category if available
                if selectedCategory == nil, let first = categories.first {
                    selectedCategory = first
                }
            }
        }
    }
    
    private func saveItem() {
        guard let image = selectedImage,
              let category = selectedCategory else { return }
        
        isSaving = true
        
        // Save image to disk (already cropped by user)
        guard let imageID = ImageStorageService.shared.saveImage(image) else {
            isSaving = false
            return
        }
        
        // Parse tags
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Create item
        let item = ClothingItem(
            name: name,
            category: category,
            brand: brand.isEmpty ? nil : brand,
            size: size.isEmpty ? nil : size,
            imageID: imageID,
            tags: tags
        )
        
        modelContext.insert(item)
        
        dismiss()
    }
}

// MARK: - Image Cropper View
struct ImageCropperView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cropSize = min(geometry.size.width, geometry.size.height) - 40
                let cropFrame = CGRect(
                    x: (geometry.size.width - cropSize) / 2,
                    y: (geometry.size.height - cropSize) / 2,
                    width: cropSize,
                    height: cropSize
                )
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .overlay(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    viewSize = geo.size
                                    // Reset state on appear
                                    scale = 1.0
                                    offset = .zero
                                    
                                    // Calculate min scale to fill crop box
                                    let aspect = image.size.width / image.size.height
                                    let viewAspect = geo.size.width / geo.size.height
                                    
                                    // If image is wider/taller than view, fit logic applies
                                    // We need to ensure minimal scale fills the crop box
                                    // But for simplicity, starting at 1.0 (fit) usually covers it unless very weird aspect ratio
                                    // Let's ensure start scale is enough to cover cropSize
                                    
                                    let fittedWidth = viewAspect > aspect ? geo.size.height * aspect : geo.size.width
                                    let fittedHeight = viewAspect > aspect ? geo.size.height : geo.size.width / aspect
                                    
                                    let minScaleWidth = cropSize / fittedWidth
                                    let minScaleHeight = cropSize / fittedHeight
                                    let minNeeded = max(minScaleWidth, minScaleHeight)
                                    
                                    if minNeeded > 1.0 {
                                        scale = minNeeded
                                    }
                                }
                        })
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation {
                                        validateState(cropSize: cropSize)
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                    withAnimation {
                                        validateState(cropSize: cropSize)
                                    }
                                }
                        )
                    
                    // Crop overlay
                    CropOverlay(cropSize: cropSize)
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Calculate final crop
                        // We need to pass the geometry size to the crop function
                        // Since we can't easily capture it from the button action closure without storing it
                        // We'll rely on the stored 'viewSize' from the image overlay, 
                        // but we need the outer geometry size
                        // Let's pass the crop calculations inside the view logic
                        
                        // Re-calculate crop params locally
                        let geoWidth = UIScreen.main.bounds.width // Approx for SafeArea
                        let geoHeight = UIScreen.main.bounds.height // Approx
                        let shortSide = min(geoWidth, geoHeight)
                        let calculatedCropSize = shortSide - 40 // Matches logic above
                        
                        let cropped = cropImage(cropSize: calculatedCropSize)
                        onSave(cropped)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") {
                        withAnimation {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            
                            // Re-apply min scale logic if needed
                            // (Simplified reset to 1.0 for now)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func validateState(cropSize: CGFloat) {
        // 1. Ensure scale is large enough to fill crop box
        // Calculate current rendered size
        let aspect = image.size.width / image.size.height
        // Approx view size if not captured yet (fallback)
        let vW = viewSize.width > 0 ? viewSize.width : 300
        let vH = viewSize.height > 0 ? viewSize.height : 300
        
        // This math assumes 'fit' content mode behavior
        let viewAspect = vW / vH
        let renderedWidth = viewAspect > aspect ? vH * aspect : vW
        let renderedHeight = viewAspect > aspect ? vH : vW / aspect
        
        let currentWidth = renderedWidth * scale
        let currentHeight = renderedHeight * scale
        
        if currentWidth < cropSize || currentHeight < cropSize {
            let minScaleW = cropSize / renderedWidth
            let minScaleH = cropSize / renderedHeight
            scale = max(minScaleW, minScaleH)
        }
        
        // 2. Bound offset to keep image inside crop box
        // Max offset is (currentSize - cropSize) / 2
        let maxOffsetX = (renderedWidth * scale - cropSize) / 2
        let maxOffsetY = (renderedHeight * scale - cropSize) / 2
        
        if maxOffsetX >= 0 {
            offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        }
        
        if maxOffsetY >= 0 {
            offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
        }
        
        lastOffset = offset
        lastScale = 1.0
    }
    
    private func cropImage(cropSize: CGFloat) -> UIImage {
        // Calculate the rectangle on the original image that corresponds to the crop box
        
        let initialAspect = image.size.width / image.size.height
        let vW = viewSize.width > 0 ? viewSize.width : image.size.width
        let vH = viewSize.height > 0 ? viewSize.height : image.size.height
        let viewAspect = vW / vH
        
        // Size of the image as rendered on screen (at scale 1.0)
        let renderedWidth = viewAspect > initialAspect ? vH * initialAspect : vW
        
        // The scale factor between screen pixels and actual image pixels
        // actual pixels = screen pixels * ratio
        let screenToImageRatio = image.size.width / renderedWidth
        
        // The effective scale including user zoom
        let totalScale = scale
        
        // Center of the crop box is the center of the screen (0, 0 in offset space)
        // Center of the image is at 'offset' relative to screen center
        // Vector from Image Center to Crop Center is '-offset'
        
        // Size of the crop box in unscaled screen coordinates
        // But the image is scaled by 'scale'.
        // So in the coordinate space of the displayed image (scale 1.0), the crop box is size / scale
        
        let cropWidthInBaseRendered = cropSize / totalScale
        let cropHeightInBaseRendered = cropSize / totalScale
        
        let offsetXInBaseRendered = offset.width / totalScale
        let offsetYInBaseRendered = offset.height / totalScale
        
        // Center of crop relative to image center (in base rendered coords)
        let centerX = (renderedWidth / 2) - offsetXInBaseRendered
        // Height calculation depends on aspect ratio - let's use the ratio
        let renderedHeight = renderedWidth / initialAspect
        let centerY = (renderedHeight / 2) - offsetYInBaseRendered
        
        let cropX = centerX - (cropWidthInBaseRendered / 2)
        let cropY = centerY - (cropHeightInBaseRendered / 2)
        
        // Convert to actual image pixels
        let pixelX = cropX * screenToImageRatio
        let pixelY = cropY * screenToImageRatio
        let pixelWidth = cropWidthInBaseRendered * screenToImageRatio
        let pixelHeight = cropHeightInBaseRendered * screenToImageRatio
        
        let cropRect = CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Crop Overlay
struct CropOverlay: View {
    let cropSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Semi-transparent overlay with hole
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        ZStack {
                            Rectangle()
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: cropSize, height: cropSize)
                                .position(x: centerX, y: centerY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                
                // Crop frame border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .position(x: centerX, y: centerY)
                
                // Grid lines
                Path { path in
                    let third = cropSize / 3
                    let left = centerX - cropSize / 2
                    let top = centerY - cropSize / 2
                    
                    // Vertical lines
                    path.move(to: CGPoint(x: left + third, y: top))
                    path.addLine(to: CGPoint(x: left + third, y: top + cropSize))
                    path.move(to: CGPoint(x: left + third * 2, y: top))
                    path.addLine(to: CGPoint(x: left + third * 2, y: top + cropSize))
                    
                    // Horizontal lines
                    path.move(to: CGPoint(x: left, y: top + third))
                    path.addLine(to: CGPoint(x: left + cropSize, y: top + third))
                    path.move(to: CGPoint(x: left, y: top + third * 2))
                    path.addLine(to: CGPoint(x: left + cropSize, y: top + third * 2))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var showCropper: Bool
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false // We'll use our own cropper
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let original = info[.originalImage] as? UIImage {
                parent.image = original
                parent.showCropper = true
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
