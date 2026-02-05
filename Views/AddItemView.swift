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
    
    // Image selection
    @State private var selectedPhotoItem: PhotosPickerItem? // For single select
    @State private var selectedPhotoItems: [PhotosPickerItem] = [] // For multi select
    @State private var selectedImage: UIImage?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var imageToCrop: UIImage?
    @State private var croppingItem: CroppableImage?
    
    // Bulk Queue Management
    @State private var bulkImageQueue: [UIImage] = []
    @State private var totalBulkItems: Int = 0
    @State private var showingBulkPhotoPicker = false
    
    // Metadata
    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var brand = ""
    @State private var size = ""
    @State private var tagsText = ""
    
    // UI State
    @State private var isSaving = false
    @State private var isProcessingImage = false
    @State private var isMetadataExpanded = true // For collapsed state in bulk
    
    var canSave: Bool {
        if additionMode == .single {
            return selectedImage != nil && !name.isEmpty && selectedCategory != nil
        } else {
            return !bulkImageQueue.isEmpty && !name.isEmpty && selectedCategory != nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PoshTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    formContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navBarContent }
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourcePicker) {
                sourcePickerButtons
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .photosPicker(isPresented: $showingBulkPhotoPicker, selection: $selectedPhotoItems, maxSelectionLimit: 50, matching: .images)
            .fullScreenCover(isPresented: $showingCamera, onDismiss: handleCameraDismiss) {
                ImagePickerView(image: $imageToCrop, sourceType: .camera)
            }
            .fullScreenCover(item: $croppingItem) { item in
                CropView(image: item.image) { croppedImage in
                    selectedImage = croppedImage
                    croppingItem = nil
                } onCancel: {
                    croppingItem = nil
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                if let item = newValue { processSinglePhoto(item) }
            }
            .onChange(of: selectedPhotoItems) { _, newValue in
                if !newValue.isEmpty { processBulkPhotos(newValue) }
            }
            .overlay { processingOverlay }
            .onAppear { setupInitialCategory() }
        }
    }
    
    // MARK: - Component Blocks
    
    private var formContent: some View {
        VStack(spacing: 24) {
            modeToggle
            modeSpecificContent
        }
        .padding(20)
        .padding(.bottom, 40)
    }
    
    private var modeToggle: some View {
        Picker("Mode", selection: $additionMode) {
            ForEach(AdditionMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 40)
        .onChange(of: additionMode) {
            resetFields()
        }
    }
    
    @ViewBuilder
    private var modeSpecificContent: some View {
        if additionMode == .multiple && bulkImageQueue.isEmpty {
            bulkEmptyState
        } else {
            activeFormContent
        }
    }
    
    private var bulkEmptyState: some View {
        VStack(spacing: 30) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.4))
            
            Text("SELECT MULTIPLE GARMENTS")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(PoshTheme.Colors.secondaryAccent)
            
            Button {
                showingBulkPhotoPicker = true
            } label: {
                Text("OPEN GALLERY")
                    .tracking(2)
            }
            .poshButton()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }
    
    private var activeFormContent: some View {
        VStack(spacing: 24) {
            imageSection
            
            if additionMode == .multiple {
                Text(bulkProgressLabel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
            }
            
            detailsSection
            actionButton
        }
    }
    
    private var bulkProgressLabel: String {
        let currentItemIndex = totalBulkItems - bulkImageQueue.count + 1
        return "ITEM \(currentItemIndex) OF \(totalBulkItems)"
    }
    
    // MARK: - Subviews
    
    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = (additionMode == .single ? selectedImage : bulkImageQueue.first) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .poshCard()
                
                if additionMode == .single {
                    Button {
                        showingImageSourcePicker = true
                    } label: {
                        Text("CHANGE PHOTO")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    }
                }
            } else {
                imagePlaceholder
            }
        }
    }
    
    private var imagePlaceholder: some View {
        Button {
            showingImageSourcePicker = true
        } label: {
            VStack(spacing: 20) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(PoshTheme.Colors.secondaryAccent)
                    .padding(20)
                    .background(Circle().stroke(PoshTheme.Colors.secondaryAccent.opacity(0.3), lineWidth: 1))
                
                Text("ADD PHOTOGRAPH")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(PoshTheme.Colors.secondaryAccent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(PoshTheme.Colors.cardBackground)
            .cornerRadius(16)
            .poshCard()
        }
        .buttonStyle(.plain)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            detailsHeader
            
            VStack(spacing: 16) {
                PoshTextField(label: "NAME", text: $name, placeholder: "e.g. Classic Trench Coat")
                
                if isMetadataExpanded {
                    categoryPickerRow
                    
                    PoshTextField(label: "BRAND", text: $brand, placeholder: "Optional")
                    PoshTextField(label: "SIZE", text: $size, placeholder: "Optional")
                    PoshTextField(label: "TAGS", text: $tagsText, placeholder: "Separated by commas")
                }
            }
        }
        .padding(24)
        .poshCard()
    }
    
    private var detailsHeader: some View {
        HStack {
            Text("Item Details").poshHeadline(size: 20)
            Spacer()
            if additionMode == .multiple {
                Button { withAnimation { isMetadataExpanded.toggle() } } label: {
                    Image(systemName: isMetadataExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                }
            }
        }
    }
    
    private var categoryPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.secondaryAccent)
            
            Menu {
                ForEach(categories) { category in
                    Button(category.name) { selectedCategory = category }
                }
            } label: {
                HStack {
                    Text(selectedCategory?.name ?? "Select Category").poshBody(size: 16)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                }
                .padding(.vertical, 12)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3)), alignment: .bottom)
            }
        }
    }
    
    private var actionButton: some View {
        Button(action: saveItem) {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(actionButtonLabel)
                        .tracking(2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .poshButton()
        .disabled(!canSave || isSaving)
        .opacity(canSave ? 1.0 : 0.6)
        .padding(.top, 8)
    }
    
    private var actionButtonLabel: String {
        if additionMode == .single {
            return "SAVE TO CLOSET"
        } else {
            return bulkImageQueue.count > 1 ? "SAVE & NEXT" : "SAVE & FINISH"
        }
    }
    
    @ToolbarContentBuilder
    private var navBarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(additionMode == .single ? "New Item" : "Bulk Upload").poshHeadline(size: 18)
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .poshBody(size: 16)
                .foregroundColor(PoshTheme.Colors.secondaryAccent)
        }
    }
    
    @ViewBuilder
    private var sourcePickerButtons: some View {
        Button("Take Photo") { showingCamera = true }
        Button("Choose from Library") { showingPhotoPicker = true }
        Button("Cancel", role: .cancel) {}
    }
    
    @ViewBuilder
    private var processingOverlay: some View {
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
    
    private func handleCameraDismiss() {
        if let image = imageToCrop {
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.modalTransitionDelay) {
                croppingItem = CroppableImage(image: image)
            }
        }
    }
    
    private func setupInitialCategory() {
        if selectedCategory == nil, let first = categories.first {
            selectedCategory = first
        }
    }

    // MARK: - Helper Methods
    
    private func resetFields() {
        name = ""
        // Keep Category and Brand for bulk convenience
        if additionMode == .single {
            selectedImage = nil
            size = ""
            tagsText = ""
        }
    }
    
    private func processSinglePhoto(_ item: PhotosPickerItem) {
        isProcessingImage = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                try? await Task.sleep(nanoseconds: AppConstants.Animation.processingDelay)
                await MainActor.run {
                    croppingItem = CroppableImage(image: image)
                    selectedPhotoItem = nil
                    isProcessingImage = false
                }
            }
        }
    }
    
    private func processBulkPhotos(_ items: [PhotosPickerItem]) {
        isProcessingImage = true
        totalBulkItems = items.count
        
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                    images.append(image)
                }
            }
            
            await MainActor.run {
                bulkImageQueue = images
                selectedPhotoItems = []
                isProcessingImage = false
                // In bulk mode, metadata is often same, collapse by default unless first item
                if totalBulkItems > 1 { isMetadataExpanded = true }
            }
        }
    }
    
    private func saveItem() {
        let currentImage = additionMode == .single ? selectedImage : bulkImageQueue.first
        guard let image = currentImage,
              let category = selectedCategory else { return }
        
        isSaving = true
        
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Task {
            do {
                try await ClosetDataService.shared.addItem(
                    name: name,
                    category: category,
                    image: image,
                    brand: brand.isEmpty ? nil : brand,
                    size: size.isEmpty ? nil : size,
                    tags: tags,
                    context: modelContext
                )
                
                await MainActor.run {
                    isSaving = false
                    if additionMode == .single {
                        dismiss()
                    } else {
                        // Progress to next
                        bulkImageQueue.removeFirst()
                        name = "" // Always clear name
                        // Collapse metadata for speed if it was already set
                        withAnimation { isMetadataExpanded = false }
                        
                        if bulkImageQueue.isEmpty {
                            dismiss()
                        }
                    }
                }
            } catch {
                print("Error saving item: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}





#Preview {
    AddItemView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}

// MARK: - Support Components

struct PoshTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.secondaryAccent)
            
            TextField(placeholder, text: $text)
                .poshBody(size: 16)
                .padding(.vertical, 12)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3)), alignment: .bottom)
        }
    }
}
