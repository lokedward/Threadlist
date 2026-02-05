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
    @State private var imageToCrop: UIImage?
    @State private var croppingItem: CroppableImage?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var newImage: UIImage?
    @State private var isProcessingImage = false
    
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
            

            
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            // Ensure camera is fully dismissed on iOS 18 before selecting the cropping item
            if let image = imageToCrop {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    croppingItem = CroppableImage(image: image)
                }
            }
        }) {
            CameraViewForEdit(image: $imageToCrop)
        }
        
        .fullScreenCover(item: $croppingItem) { item in
            CropView(image: item.image) { croppedImage in
                newImage = croppedImage
                croppingItem = nil
            } onCancel: {
                croppingItem = nil
            }
        }

        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            
            isProcessingImage = true
            
            Task {
                // Load raw data first
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { isProcessingImage = false }
                    return
                }
                
                // Downsample efficiently without loading full image into RAM
                // Using 1500px as max dimension for high quality but low memory footprint
                guard let downsampledImage = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) else {
                    await MainActor.run { isProcessingImage = false }
                    return
                }
                
                // Critical Fix: Wait for PhotosPicker to fully dismiss before presenting cropper
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                
                await MainActor.run {
                    croppingItem = CroppableImage(image: downsampledImage)
                    selectedPhotoItem = nil
                    isProcessingImage = false
                }
            }
        }
        .overlay {
            if isProcessingImage {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Processing Image...")
                        .padding()
                        .background(Material.regular)
                        .cornerRadius(10)
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
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
