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
    @State private var imageToCrop: UIImage?
    @State private var croppingItem: CroppableImage?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var newImage: UIImage?
    @State private var isProcessingImage = false
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Image
                    Group {
                        if let image = isEditing ? (newImage ?? itemImage) : itemImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .poshCard()
                                .overlay(alignment: .bottomTrailing) {
                                    if isEditing {
                                        Button {
                                            showingImageSourcePicker = true
                                        } label: {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 18, weight: .light))
                                                .foregroundColor(.white)
                                                .padding(12)
                                                .background(PoshTheme.Colors.ink)
                                                .clipShape(Circle())
                                                .shadow(color: .black.opacity(0.1), radius: 5)
                                        }
                                        .padding(16)
                                    }
                                }
                        } else {
                            Color.white
                                .aspectRatio(1, contentMode: .fit)
                                .poshCard()
                                .overlay {
                                    Image(systemName: "handbag")
                                        .font(.system(size: 40, weight: .thin))
                                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))

                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Details
                    VStack(spacing: 24) {
                        if isEditing {
                            editingView
                        } else {
                            detailView
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(isEditing ? "" : "") // Handle navigation title via Principal Toolbar
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isEditing ? "EDIT COMPOSITION" : item.name.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .foregroundColor(PoshTheme.Colors.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("DONE") {
                        saveEdits()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(PoshTheme.Colors.ink)
                } else {
                    Button("EDIT") {
                        startEditing()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(PoshTheme.Colors.ink)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.modalTransitionDelay) {
                    croppingItem = CroppableImage(image: image)
                }
            }
        }) {
            ImagePickerView(image: $imageToCrop, sourceType: .camera)
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
                try? await Task.sleep(nanoseconds: AppConstants.Animation.processingDelay)
                
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
        VStack(alignment: .leading, spacing: 28) {
            // General Info Card
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COLLECTION")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                        
                        if let category = item.category {
                            Text(category.name)
                                .poshHeadline(size: 24)
                        } else {
                            Text("Uncategorized")
                                .poshHeadline(size: 24)
                        }
                    }
                    
                    Spacer()
                    
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(PoshTheme.Colors.ink)
                    }
                }
                
                Divider().background(PoshTheme.Colors.ink.opacity(0.2))
                
                // Details Grid
                VStack(spacing: 16) {
                    if let size = item.size, !size.isEmpty {
                        PoshDetailRow(label: "SIZE", value: size)
                    }
                    
                    PoshDetailRow(label: "ACQUIRED", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding(24)
            .poshCard()
            
            // Tags Card
            if !item.tags.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CHARACTERISTICS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    
                    FlowLayout(spacing: 10) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PoshTheme.Colors.ink.opacity(0.1))
                                .foregroundColor(PoshTheme.Colors.body)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(24)
                .poshCard()
            }
            
            // Actions
            VStack(spacing: 16) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("REMOVE FROM CLOSET")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(.red.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.top, 20)
        }
    }
    
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 16) {
                PoshTextField(label: "NAME", text: $editName)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CATEGORY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    
                    Menu {
                        ForEach(categories) { category in
                            Button(category.name) {
                                editCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text(editCategory?.name ?? "Select Category")
                                .poshBody(size: 16)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(PoshTheme.Colors.ink)
                        }
                        .padding(.vertical, 12)
                        .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.ink.opacity(0.3)), alignment: .bottom)
                    }
                }
                
                PoshTextField(label: "BRAND", text: $editBrand)
                PoshTextField(label: "SIZE", text: $editSize)
                PoshTextField(label: "TAGS", text: $editTagsText)
            }
            .padding(24)
            .poshCard()
            
            Button {
                cancelEditing()
            } label: {
                Text("DISCARD EDITS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(PoshTheme.Colors.ink)
                    .frame(maxWidth: .infinity)
            }
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
        let tags = editTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            
        Task {
            do {
                try await ClosetDataService.shared.updateItem(
                    item,
                    name: editName,
                    category: editCategory,
                    newImage: newImage,
                    brand: editBrand.isEmpty ? nil : editBrand,
                    size: editSize.isEmpty ? nil : editSize,
                    tags: tags,
                    context: modelContext
                )
                
                await MainActor.run {
                    if newImage != nil {
                        loadImage() // Refresh the displayed image
                    }
                    newImage = nil
                    isEditing = false
                }
            } catch {
                print("Error updating item: \(error)")
            }
        }
    }
    
    private func deleteItem() {
        Task {
            do {
                try await ClosetDataService.shared.deleteItem(item, context: modelContext)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting item: \(error)")
            }
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
