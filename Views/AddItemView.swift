// AddItemView.swift
// Add new clothing item flow with image picker and metadata entry

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    
    enum AdditionMode: String, CaseIterable {
        case single = "SINGLE"
        case multiple = "MULTIPLE"
    }
    
    @State private var additionMode: AdditionMode = .single
    
    // Image selection state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var imageToCrop: UIImage?
    @State private var croppingItem: CroppableImage?
    
    // Bulk Queue state
    @State private var bulkImageQueue: [UIImage] = []
    @State private var totalBulkItems: Int = 0
    @State private var showingBulkPhotoPicker = false
    
    // Metadata state
    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var brand = ""
    @State private var size = ""
    @State private var tagsText = ""
    
    // UI state
    @State private var isSaving = false
    @State private var isProcessingImage = false
    @State private var isMetadataExpanded = true
    
    var canSave: Bool {
        let hasImage = additionMode == .single ? selectedImage != nil : !bulkImageQueue.isEmpty
        return hasImage && !name.isEmpty && selectedCategory != nil
    }
    
    var body: some View {
        NavigationStack {
            MainFormView(
                additionMode: $additionMode,
                name: $name,
                selectedCategory: $selectedCategory,
                brand: $brand,
                size: $size,
                tagsText: $tagsText,
                isMetadataExpanded: $isMetadataExpanded,
                selectedImage: selectedImage,
                bulkImageQueue: bulkImageQueue,
                totalBulkItems: totalBulkItems,
                isSaving: isSaving,
                categories: categories,
                onAddPhoto: { showingImageSourcePicker = true },
                onOpenBulkGallery: { showingBulkPhotoPicker = true },
                onSave: saveItem,
                onCropComplete: { img in selectedImage = img }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(additionMode == .single ? "New Item" : "Bulk Upload").poshHeadline(size: 18)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .poshBody(size: 16)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                }
            }
            // Modifiers decoupled here
            .modifier(AddItemPickerModifiers(
                showingImageSourcePicker: $showingImageSourcePicker,
                showingCamera: $showingCamera,
                showingPhotoPicker: $showingPhotoPicker,
                showingBulkPhotoPicker: $showingBulkPhotoPicker,
                selectedPhotoItem: $selectedPhotoItem,
                selectedPhotoItems: $selectedPhotoItems,
                croppingItem: $croppingItem,
                imageToCrop: $imageToCrop,
                isProcessingImage: $isProcessingImage,
                onSingleProcessed: { img in croppingItem = CroppableImage(image: img) },
                onBulkProcessed: { imgs in 
                    bulkImageQueue = imgs
                    totalBulkItems = imgs.count
                    isMetadataExpanded = true
                }
            ))
            .overlay {
                if isProcessingImage {
                    ProcessingOverlayView()
                }
            }
            .onAppear {
                if selectedCategory == nil { selectedCategory = categories.first }
            }
        }
    }
    
    private func saveItem() {
        let currentImage = additionMode == .single ? selectedImage : bulkImageQueue.first
        guard let image = currentImage, let category = selectedCategory else { return }
        
        isSaving = true
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        Task {
            do {
                try await ClosetDataService.shared.addItem(
                    name: name, category: category, image: image,
                    brand: brand.isEmpty ? nil : brand, size: size.isEmpty ? nil : size,
                    tags: tags, context: modelContext
                )
                await MainActor.run {
                    isSaving = false
                    if additionMode == .single {
                        dismiss()
                    } else {
                        bulkImageQueue.removeFirst()
                        name = ""
                        withAnimation { isMetadataExpanded = false }
                        if bulkImageQueue.isEmpty { dismiss() }
                    }
                }
            } catch {
                print("Error: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Subviews (Static Extraction)

struct MainFormView: View {
    @Binding var additionMode: AddItemView.AdditionMode
    @Binding var name: String
    @Binding var selectedCategory: Category?
    @Binding var brand: String
    @Binding var size: String
    @Binding var tagsText: String
    @Binding var isMetadataExpanded: Bool
    
    let selectedImage: UIImage?
    let bulkImageQueue: [UIImage]
    let totalBulkItems: Int
    let isSaving: Bool
    let categories: [Category]
    
    let onAddPhoto: () -> Void
    let onOpenBulkGallery: () -> Void
    let onSave: () -> Void
    let onCropComplete: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Mode", selection: $additionMode) {
                        ForEach(AddItemView.AdditionMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 40)
                    
                    if additionMode == .multiple && bulkImageQueue.isEmpty {
                        BulkEmptyStateView(onOpenGallery: onOpenBulkGallery)
                    } else {
                        VStack(spacing: 24) {
                            ImageSectionView(
                                image: additionMode == .single ? selectedImage : bulkImageQueue.first,
                                showChangeButton: additionMode == .single,
                                onTrigger: onAddPhoto
                            )
                            
                            if additionMode == .multiple {
                                let currentItemIndex = totalBulkItems - bulkImageQueue.count + 1
                                Text("ITEM \(currentItemIndex) OF \(totalBulkItems)")
                                    .font(.system(size: 10, weight: .bold)).tracking(2)
                                    .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                            }
                            
                            DetailsSectionView(
                                name: $name, category: $selectedCategory, brand: $brand,
                                size: $size, tagsText: $tagsText, isExpanded: $isMetadataExpanded,
                                showExpandButton: additionMode == .multiple, categories: categories
                            )
                            
                            Button(action: onSave) {
                                Text(isSaving ? "SAVING..." : (additionMode == .single ? "SAVE TO CLOSET" : (bulkImageQueue.count > 1 ? "SAVE & NEXT" : "SAVE & FINISH")))
                                    .tracking(2).frame(maxWidth: .infinity)
                            }
                            .poshButton()
                            .disabled(isSaving)
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
        }
    }
}

struct ImageSectionView: View {
    let image: UIImage?
    let showChangeButton: Bool
    let onTrigger: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if let uiImage = image {
                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity).frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16)).poshCard()
                
                if showChangeButton {
                    Button(action: onTrigger) {
                        Text("CHANGE PHOTO").font(.system(size: 12, weight: .bold)).tracking(1)
                            .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    }
                }
            } else {
                Button(action: onTrigger) {
                    VStack(spacing: 20) {
                        Image(systemName: "plus").font(.system(size: 30, weight: .light)).foregroundColor(PoshTheme.Colors.secondaryAccent)
                            .padding(20).background(Circle().stroke(PoshTheme.Colors.secondaryAccent.opacity(0.3), lineWidth: 1))
                        Text("ADD PHOTOGRAPH").font(.system(size: 12, weight: .bold)).tracking(2).foregroundColor(PoshTheme.Colors.secondaryAccent)
                    }
                    .frame(maxWidth: .infinity).frame(height: 300)
                    .background(PoshTheme.Colors.cardBackground).cornerRadius(16).poshCard()
                }.buttonStyle(.plain)
            }
        }
    }
}

struct DetailsSectionView: View {
    @Binding var name: String
    @Binding var category: Category?
    @Binding var brand: String
    @Binding var size: String
    @Binding var tagsText: String
    @Binding var isExpanded: Bool
    let showExpandButton: Bool
    let categories: [Category]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Item Details").poshHeadline(size: 20)
                Spacer()
                if showExpandButton {
                    Button { withAnimation { isExpanded.toggle() } } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(PoshTheme.Colors.secondaryAccent)
                    }
                }
            }
            VStack(spacing: 16) {
                PoshTextField(label: "NAME", text: $name, placeholder: "e.g. Classic Trench Coat")
                if isExpanded {
                    CategoryPickerField(selectedCategory: $category, categories: categories)
                    PoshTextField(label: "BRAND", text: $brand, placeholder: "Optional")
                    PoshTextField(label: "SIZE", text: $size, placeholder: "Optional")
                    PoshTextField(label: "TAGS", text: $tagsText, placeholder: "Separated by commas")
                }
            }
        }
        .padding(24).poshCard()
    }
}

struct CategoryPickerField: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(PoshTheme.Colors.secondaryAccent)
            Menu {
                ForEach(categories) { cat in Button(cat.name) { selectedCategory = cat } }
            } label: {
                HStack {
                    Text(selectedCategory?.name ?? "Select Category").poshBody(size: 16)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(PoshTheme.Colors.secondaryAccent)
                }
                .padding(.vertical, 12)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3)), alignment: .bottom)
            }
        }
    }
}

struct BulkEmptyStateView: View {
    let onOpenGallery: () -> Void
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 50, weight: .ultraLight)).foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.4))
            Text("SELECT MULTIPLE GARMENTS").font(.system(size: 14, weight: .bold)).tracking(2).foregroundColor(PoshTheme.Colors.secondaryAccent)
            Button(action: onOpenGallery) { Text("OPEN GALLERY").tracking(2) }.poshButton()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 100)
    }
}

struct ProcessingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ProgressView("Processing Image...").padding().background(Material.regular).cornerRadius(10)
        }
    }
}

// MARK: - Decoupled Modifiers

struct AddItemPickerModifiers: ViewModifier {
    @Binding var showingImageSourcePicker: Bool
    @Binding var showingCamera: Bool
    @Binding var showingPhotoPicker: Bool
    @Binding var showingBulkPhotoPicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var croppingItem: CroppableImage?
    @Binding var imageToCrop: UIImage?
    @Binding var isProcessingImage: Bool
    
    let onSingleProcessed: (UIImage) -> Void
    let onBulkProcessed: ([UIImage]) -> Void
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourcePicker) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .photosPicker(isPresented: $showingBulkPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 50, matching: .images)
            .fullScreenCover(isPresented: $showingCamera, onDismiss: handleCameraDismiss) {
                ImagePickerView(image: $imageToCrop, sourceType: .camera)
            }
            .fullScreenCover(item: $croppingItem) { item in
                CropView(image: item.image) { croppedImage in
                    onSingleProcessed(croppedImage)
                    croppingItem = nil
                } onCancel: {
                    croppingItem = nil
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                if let item = newValue { processSingle(item) }
            }
            .onChange(of: selectedPhotoItems) { _, newValue in
                if !newValue.isEmpty { processBulk(newValue) }
            }
    }
    
    private func handleCameraDismiss() {
        if let image = imageToCrop {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onSingleProcessed(image)
            }
        }
    }
    
    private func processSingle(_ item: PhotosPickerItem) {
        isProcessingImage = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                await MainActor.run {
                    onSingleProcessed(img)
                    selectedPhotoItem = nil
                    isProcessingImage = false
                }
            }
        }
    }
    
    private func processBulk(_ items: [PhotosPickerItem]) {
        isProcessingImage = true
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                    images.append(img)
                }
            }
            await MainActor.run {
                onBulkProcessed(images)
                selectedPhotoItems = []
                isProcessingImage = false
            }
        }
    }
}

// MARK: - Preview Logic & PoshTextField

struct PoshTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(PoshTheme.Colors.secondaryAccent)
            TextField(placeholder, text: $text).poshBody(size: 16).padding(.vertical, 12)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3)), alignment: .bottom)
        }
    }
}

#Preview {
    AddItemView().modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
