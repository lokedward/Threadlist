// ItemDetailView.swift
// Full item detail view with edit and delete functionality

import SwiftUI
import SwiftData
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var item: ClothingItem
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var itemImage: UIImage?
    
    // Edit state
    @State private var editName = ""
    @State private var editBrand = ""
    @State private var editSize = ""
    @State private var editCategory: Category?
    @State private var editTagsText = ""
    
    // Image editing state
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingImageCropper = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageToCrop: UIImage?
    @State private var newImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image
                Group {
                    if let image = isEditing ? (newImage ?? itemImage) : itemImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .bottomTrailing) {
                                if isEditing {
                                    Button {
                                        showingImageSourcePicker = true
                                    } label: {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Circle().fill(.ultraThinMaterial))
                                    }
                                    .padding(12)
                                }
                            }
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if isEditing {
                                    Button {
                                        showingImageSourcePicker = true
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.largeTitle)
                                            Text("Add Photo")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                } else {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                }
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .onTapGesture {
                    if isEditing {
                        showingImageSourcePicker = true
                    }
                }
                
                // Details
                VStack(spacing: 16) {
                    if isEditing {
                        editingView
                    } else {
                        detailView
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(isEditing ? "Edit Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Done") {
                        saveEdits()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .alert("Delete Item?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \"\(item.name)\" from your closet.")
        }
        .confirmationDialog("Change Photo", isPresented: $showingImageSourcePicker) {
            Button("Take Photo") {
                showingCamera = true
            }
            
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            
            if let image = newImage ?? itemImage {
                Button("Edit Current Photo") {
                    imageToCrop = image
                    showingImageCropper = true
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraViewForEdit(image: $imageToCrop, showCropper: $showingImageCropper)
        }
        .fullScreenCover(isPresented: $showingImageCropper) {
            if let image = imageToCrop {
                ImageCropperViewForEdit(image: image) { croppedImage in
                    newImage = croppedImage
                    showingImageCropper = false
                } onCancel: {
                    showingImageCropper = false
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                guard let item = newValue,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                
                // Resize large images to prevent memory crash/UI freeze
                let resizedImage = uiImage.resized(to: 1500)
                
                await MainActor.run {
                    imageToCrop = resizedImage
                    showingImageCropper = true
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var detailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Name and Category
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title.weight(.bold))
                
                if let category = item.category {
                    Text(category.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Divider()
            
            // Details Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                if let brand = item.brand, !brand.isEmpty {
                    DetailRow(label: "Brand", value: brand)
                }
                
                if let size = item.size, !size.isEmpty {
                    DetailRow(label: "Size", value: size)
                }
                
                DetailRow(label: "Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
            }
            
            // Tags
            if !item.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer(minLength: 20)
            
            // Delete Button
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Item")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var editingView: some View {
        VStack(spacing: 16) {
            // Change Photo Button
            Button {
                showingImageSourcePicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Change Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                TextField("Item name", text: $editName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Picker("Category", selection: $editCategory) {
                    Text("None").tag(nil as Category?)
                    ForEach(categories) { category in
                        Text(category.name).tag(category as Category?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Brand")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                TextField("Brand (optional)", text: $editBrand)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Size")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                TextField("Size (optional)", text: $editSize)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                TextField("Comma separated tags", text: $editTagsText)
                    .textFieldStyle(.roundedBorder)
            }
            
            Button("Cancel", role: .cancel) {
                cancelEditing()
            }
            .padding(.top)
        }
    }
    
    private func loadImage() {
        itemImage = ImageStorageService.shared.loadImage(withID: item.imageID)
    }
    
    private func startEditing() {
        editName = item.name
        editBrand = item.brand ?? ""
        editSize = item.size ?? ""
        editCategory = item.category
        editTagsText = item.tags.joined(separator: ", ")
        newImage = nil
        isEditing = true
    }
    
    private func cancelEditing() {
        newImage = nil
        isEditing = false
    }
    
    private func saveEdits() {
        item.name = editName
        item.brand = editBrand.isEmpty ? nil : editBrand
        item.size = editSize.isEmpty ? nil : editSize
        item.category = editCategory
        item.tags = editTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Save new image if changed
        if let newImg = newImage {
            // Delete old image
            ImageStorageService.shared.deleteImage(withID: item.imageID)
            
            // Save new image
            if let newImageID = ImageStorageService.shared.saveImage(newImg) {
                item.imageID = newImageID
                itemImage = newImg
            }
        }
        
        newImage = nil
        isEditing = false
    }
    
    private func deleteItem() {
        ImageStorageService.shared.deleteImage(withID: item.imageID)
        modelContext.delete(item)
        dismiss()
    }
}

// MARK: - Camera View for Edit
struct CameraViewForEdit: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var showCropper: Bool
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraViewForEdit
        
        init(_ parent: CameraViewForEdit) {
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

// MARK: - Image Cropper View for Edit
struct ImageCropperViewForEdit: View {
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
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .overlay(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    viewSize = geo.size
                                    scale = 1.0
                                    offset = .zero
                                    
                                    let aspect = image.size.width / image.size.height
                                    let viewAspect = geo.size.width / geo.size.height
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
                    
                    CropOverlayForEdit(cropSize: cropSize)
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
                        let geoWidth = UIScreen.main.bounds.width
                        let geoHeight = UIScreen.main.bounds.height
                        let shortSide = min(geoWidth, geoHeight)
                        let calculatedCropSize = shortSide - 40
                        
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
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func validateState(cropSize: CGFloat) {
        let aspect = image.size.width / image.size.height
        let vW = viewSize.width > 0 ? viewSize.width : 300
        let vH = viewSize.height > 0 ? viewSize.height : 300
        
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
        let img = image.fixedOrientation()
        
        let initialAspect = img.size.width / img.size.height
        let vW = viewSize.width > 0 ? viewSize.width : img.size.width
        let vH = viewSize.height > 0 ? viewSize.height : img.size.height
        let viewAspect = vW / vH
        
        let renderedWidth = viewAspect > initialAspect ? vH * initialAspect : vW
        let screenToPixelRatio = CGFloat(img.cgImage!.width) / renderedWidth
        let totalScale = scale
        
        let cropWidthInBaseRendered = cropSize / totalScale
        let cropHeightInBaseRendered = cropSize / totalScale
        
        let offsetXInBaseRendered = offset.width / totalScale
        let offsetYInBaseRendered = offset.height / totalScale
        
        let centerX = (renderedWidth / 2) - offsetXInBaseRendered
        let renderedHeight = renderedWidth / initialAspect
        let centerY = (renderedHeight / 2) - offsetYInBaseRendered
        
        let cropX = centerX - (cropWidthInBaseRendered / 2)
        let cropY = centerY - (cropHeightInBaseRendered / 2)
        
        let pixelX = cropX * screenToPixelRatio
        let pixelY = cropY * screenToPixelRatio
        let pixelWidth = cropWidthInBaseRendered * screenToPixelRatio
        let pixelHeight = cropHeightInBaseRendered * screenToPixelRatio
        
        let cropRect = CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
        
        guard let cgImage = img.cgImage?.cropping(to: cropRect) else {
            return img
        }
        
        return UIImage(cgImage: cgImage, scale: img.scale, orientation: .up)
    }
}

// MARK: - Crop Overlay for Edit
struct CropOverlayForEdit: View {
    let cropSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
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
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .position(x: centerX, y: centerY)
                
                Path { path in
                    let third = cropSize / 3
                    let left = centerX - cropSize / 2
                    let top = centerY - cropSize / 2
                    
                    path.move(to: CGPoint(x: left + third, y: top))
                    path.addLine(to: CGPoint(x: left + third, y: top + cropSize))
                    path.move(to: CGPoint(x: left + third * 2, y: top))
                    path.addLine(to: CGPoint(x: left + third * 2, y: top + cropSize))
                    
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

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

#Preview {
    let item = ClothingItem(name: "Vintage Jacket", brand: "Levi's", size: "M", tags: ["denim", "casual"])
    return NavigationStack {
        ItemDetailView(item: item)
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
