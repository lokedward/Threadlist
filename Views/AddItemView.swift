// AddItemView.swift
// Add new clothing item flow with image picker and metadata entry

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Query private var items: [ClothingItem]
    
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
    
    // Prefilled items (from Email Import)
    var prefilledItems: [EmailProductItem]? = nil
    
    // UI state
    @State private var isSaving = false
    @State private var isProcessingImage = false
    @State private var isMetadataExpanded = true
    @State private var emailItemsQueue: [EmailProductItem] = []
    @State private var isLoadingEmailImage = false
    @State private var showingSaveAlert = false
    @State private var dynamicLoadingMessage = "PROCESSING..."
    @State private var showPaywall = false
    @State private var showingMagicFillExplainer = false
    
    var canSave: Bool {
        let hasImage = additionMode == .single ? selectedImage != nil : !bulkImageQueue.isEmpty
        return hasImage && !name.isEmpty && selectedCategory != nil
    }
    
    var skipAction: (() -> Void)? {
        guard additionMode == .multiple else { return nil }
        if !emailItemsQueue.isEmpty || !bulkImageQueue.isEmpty {
            return { skipCurrentItem() }
        }
        return nil
    }
    
    var cancelAction: (() -> Void)? {
        guard additionMode == .multiple else { return nil }
        if !emailItemsQueue.isEmpty || !bulkImageQueue.isEmpty {
            return { cancelReview() }
        }
        return nil
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
                itemsRemaining: !emailItemsQueue.isEmpty ? emailItemsQueue.count : nil,
                isSaving: isSaving,
                categories: categories,
                onAddPhoto: { showingImageSourcePicker = true },
                onOpenBulkGallery: { showingBulkPhotoPicker = true },
                onSave: { saveItem() },
                onCropComplete: { img in selectedImage = img },
                onSkip: skipAction,
                onCancel: cancelAction,
                onMagicFill: { performMagicFill() }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(additionMode == .single ? "New Item" : "Bulk Upload").poshHeadline(size: 18)
                }
                
                if prefilledItems != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(PoshTheme.Colors.ink)
                    }
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
                onInitialImage: { img in croppingItem = CroppableImage(image: img) },
                onFinalImage: { img in 
                    selectedImage = img
                    performMagicFill()
                },
                onBulkProcessed: { imgs in 
                    bulkImageQueue = imgs
                    totalBulkItems = imgs.count
                    isMetadataExpanded = true
                    performMagicFill()
                }
            ))
            .overlay {
                if isProcessingImage {
                    ProcessingOverlayView(message: dynamicLoadingMessage)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingMagicFillExplainer) {
                MagicFillExplainerView {
                    showingMagicFillExplainer = false
                    showPaywall = true
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                if let prefilled = prefilledItems, !prefilled.isEmpty {
                    additionMode = .multiple
                    emailItemsQueue = prefilled
                    totalBulkItems = prefilled.count
                    loadNextEmailItem()
                } else if selectedCategory == nil { 
                    selectedCategory = categories.first 
                }
            }
            .alert("SUCCESS", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { 
                    // Manual reset of scroll position is handled via the form view's internal logic or state
                }
            } message: {
                Text("Your item has been added to the wardrobe.")
            }
        }
    }
    
    // MARK: - Email Import Logic
    
    private func loadNextEmailItem() {
        guard !emailItemsQueue.isEmpty else {
            bulkImageQueue.removeAll()
            dismiss()
            return
        }
        
        let item = emailItemsQueue[0]
        
        name = item.name
        brand = item.brand ?? ""
        size = item.size ?? ""
        // Keep category selection or default
        if selectedCategory == nil { selectedCategory = categories.first }
        
        isLoadingEmailImage = true
        bulkImageQueue.removeAll()
        
        if let url = item.imageURL {
            Task {
                if let data = try? await URLSession.shared.data(from: url).0,
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.bulkImageQueue = [image]
                        self.isLoadingEmailImage = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingEmailImage = false
                    }
                }
            }
        } else {
            isLoadingEmailImage = false
        }
    }
    
    private func skipCurrentItem() {
        withAnimation {
            if !emailItemsQueue.isEmpty {
                emailItemsQueue.removeFirst()
                loadNextEmailItem()
            } else if !bulkImageQueue.isEmpty {
                bulkImageQueue.removeFirst()
                // Reset fields for the next item
                name = ""
                brand = ""
                size = ""
                tagsText = ""
                
                if bulkImageQueue.isEmpty {
                    additionMode = .single
                    resetForm()
                }
            }
        }
    }
    
    private func cancelReview() {
        withAnimation {
            bulkImageQueue.removeAll()
            emailItemsQueue.removeAll()
            additionMode = .single
            resetForm()
        }
    }
    
    private func resetForm() {
        selectedImage = nil
        selectedPhotoItem = nil
        name = ""
        brand = ""
        size = ""
        tagsText = ""
        // Only reset category if it's currently nil, preserving the last used category for efficiency
        if selectedCategory == nil {
            selectedCategory = categories.first
        }
    }

    private func saveItem() {
        let currentImage = additionMode == .single ? selectedImage : bulkImageQueue.first
        guard let image = currentImage, let category = selectedCategory else { return }
        
        // Check Capacity for Free users
        if !SubscriptionService.shared.canAddItem(currentCount: items.count) {
            showPaywall = true
            return
        }
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
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
                        showingSaveAlert = true
                        resetForm()
                    } else {
                        bulkImageQueue.removeFirst()
                        
                        if !emailItemsQueue.isEmpty {
                            // We just saved the current email item (index 0)
                            emailItemsQueue.removeFirst()
                            loadNextEmailItem()
                        } else {
                            name = ""
                            brand = ""
                            size = ""
                            tagsText = ""
                            // Keep category as is for bulk speed? Or reset?
                            withAnimation { isMetadataExpanded = true }
                            if bulkImageQueue.isEmpty {
                                // Instead of resetting to single, we stay in the mode the user chose
                                // but we clear the form for the next potential entry
                                resetForm()
                            } else {
                                // Auto-fill the next item in the bulk queue
                                performMagicFill()
                            }
                        }
                    }
                }
            } catch {
                print("Error: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func performMagicFill() {
        if SubscriptionService.shared.currentTier == .free {
            showingMagicFillExplainer = true
            return
        }
        
        // Check Limit
        if !SubscriptionService.shared.canPerformMagicFill() {
            showPaywall = true
            return
        }
        
        let currentImage = additionMode == .single ? selectedImage : bulkImageQueue.first
        guard let image = currentImage else { return }
        
        dynamicLoadingMessage = LoadingMessageService.shared.randomMessage(for: .magicFill)
        isProcessingImage = true
        Task {
            do {
                if let metadata = try await StylistService.shared.enrichMetadata(image: image) {
                    await MainActor.run {
                        SubscriptionService.shared.recordMagicFill()
                        withAnimation {
                            self.name = metadata.name
                            self.brand = metadata.brand ?? ""
                            self.size = metadata.size ?? ""
                            self.tagsText = metadata.tags.joined(separator: ", ")
                            
                            // Match category
                            if let matched = categories.first(where: { $0.name.lowercased() == metadata.category.lowercased() }) {
                                self.selectedCategory = matched
                            }
                        }
                        self.isProcessingImage = false
                    }
                } else {
                    await MainActor.run {
                        // "Fail Fast" - image was not a clothing item
                        dynamicLoadingMessage = "NO CLOTHING DETECTED"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.isProcessingImage = false
                        }
                    }
                }
            } catch {
                print("❌ Magic Fill Error: \(error)")
                await MainActor.run {
                    self.isProcessingImage = false
                }
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
    var itemsRemaining: Int? = nil
    let isSaving: Bool
    let categories: [Category]
    
    let onAddPhoto: () -> Void
    let onOpenBulkGallery: () -> Void
    let onSave: () -> Void
    let onCropComplete: (UIImage) -> Void
    var onSkip: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    let onMagicFill: () -> Void
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 1).id("form_top")
                        
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
                                ).equatable()
                                
                                if additionMode == .multiple {
                                    let currentItemIndex = totalBulkItems - (itemsRemaining ?? bulkImageQueue.count) + 1
                                    Text("ITEM \(currentItemIndex) OF \(totalBulkItems)")
                                        .font(.system(size: 10, weight: .bold)).tracking(2)
                                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))

                                }
                                
                                if (additionMode == .single ? selectedImage != nil : !bulkImageQueue.isEmpty) {
                                    Button(action: onMagicFill) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                            Text("AI AUTO-FILL")
                                            Image(systemName: "sparkles")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .poshMagicButton()
                                }
                                
                                DetailsSectionView(
                                    name: $name, category: $selectedCategory, brand: $brand,
                                    size: $size, tagsText: $tagsText, isExpanded: $isMetadataExpanded,
                                    showExpandButton: additionMode == .multiple, categories: categories
                                )
                                
                                Button(action: {
                                    onSave()
                                    // Give a tiny delay for saving to begin, then scroll if alert shows
                                }) {
                                    Text(isSaving ? "SAVING..." : (additionMode == .single ? "SAVE TO CLOSET" : (bulkImageQueue.count > 1 ? "SAVE & NEXT" : "SAVE & FINISH")))
                                        .tracking(2).frame(maxWidth: .infinity)
                                }
                                .poshButton()
                                .disabled(isSaving)
                                
                                if let onSkip = onSkip {
                                    Button(action: onSkip) {
                                        Text("SKIP THIS ITEM")
                                            .font(.system(size: 12, weight: .bold)).tracking(2)
                                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))

                                    }
                                    .padding(.top, 8)
                                }
                                
                                if let onCancel = onCancel {
                                    Button(action: onCancel) {
                                        Text("ABORT REVIEW")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(1)
                                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(20).padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: name) { _, newValue in
                    // Only scroll to top if the form was just reset (name cleared in Single mode)
                    if newValue.isEmpty && additionMode == .single && !isSaving {
                        withAnimation { proxy.scrollTo("form_top", anchor: .top) }
                    }
                }
                .onChange(of: bulkImageQueue.count) { oldValue, newValue in
                    // Scroll for bulk transitions (if count decreased)
                    if additionMode == .multiple && newValue < oldValue {
                        withAnimation { proxy.scrollTo("form_top", anchor: .top) }
                    }
                }
            }
        }
    }
}

struct ImageSectionView: View, Equatable {
    let image: UIImage?
    let showChangeButton: Bool
    let onTrigger: () -> Void
    
    // Manual Equatable implementation to help SwiftUI skip re-renders
    static func == (lhs: ImageSectionView, rhs: ImageSectionView) -> Bool {
        lhs.image === rhs.image && lhs.showChangeButton == rhs.showChangeButton
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let uiImage = image {
                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width - 40, height: 300)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16)).poshCard()
                
                if showChangeButton {
                    Button(action: onTrigger) {
                        Text("CHANGE PHOTO").font(.system(size: 12, weight: .bold)).tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink)

                    }
                }
            } else {
                Button(action: onTrigger) {
                    VStack(spacing: 20) {
                        Image(systemName: "plus").font(.system(size: 30, weight: .light)).foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                            .padding(20).background(Circle().stroke(PoshTheme.Colors.ink.opacity(0.2), lineWidth: 1))
                        Text("ADD PHOTOGRAPH").font(.system(size: 12, weight: .bold)).tracking(2).foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity).frame(height: 300)
                    .background(Color.white).cornerRadius(16).poshCard()
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
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(PoshTheme.Colors.ink)
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
            Text("CATEGORY").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(PoshTheme.Colors.ink.opacity(0.6))

            Menu {
                ForEach(categories) { cat in Button(cat.name) { selectedCategory = cat } }
            } label: {
                HStack {
                    Text(selectedCategory?.name ?? "Select Category").poshBody(size: 16)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                }
                .padding(.vertical, 12)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.ink.opacity(0.1)), alignment: .bottom)
            }
        }
    }
}

struct BulkEmptyStateView: View {
    let onOpenGallery: () -> Void
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 50, weight: .ultraLight)).foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
            Text("SELECT MULTIPLE GARMENTS").font(.system(size: 14, weight: .bold)).tracking(2).foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
            Button(action: onOpenGallery) { Text("OPEN GALLERY").tracking(2) }.poshButton()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 100)
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
    
    let onInitialImage: (UIImage) -> Void
    let onFinalImage: (UIImage) -> Void
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
                    onFinalImage(croppedImage)
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
                onInitialImage(image)
            }
        }
    }
    
    private func processSingle(_ item: PhotosPickerItem) {
        isProcessingImage = true
        // Use detached task with userInitiated priority to move work off the Main Actor
        Task.detached(priority: .userInitiated) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                await MainActor.run {
                    self.onInitialImage(img)
                    self.selectedPhotoItem = nil
                    self.isProcessingImage = false
                }
            } else {
                await MainActor.run {
                    self.isProcessingImage = false
                }
            }
        }
    }
    
    private func processBulk(_ items: [PhotosPickerItem]) {
        isProcessingImage = true
        // Use detached task for bulk processing to prevent UI freezing
        Task.detached(priority: .userInitiated) {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage.downsample(imageData: data, to: CGSize(width: 1500, height: 1500)) {
                    images.append(img)
                }
            }
            await MainActor.run {
                self.onBulkProcessed(images)
                self.selectedPhotoItems = []
                self.isProcessingImage = false
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
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
            
            TextField(placeholder, text: $text)
                .poshBody(size: 16)
                .padding(.vertical, 12)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.1)),
                    alignment: .bottom
                )
        }
    }
}

#Preview {
    AddItemView().modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}

// MARK: - Premium Explainer View

struct MagicFillExplainerView: View {
    let onUpgrade: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(PoshTheme.Colors.gold)
                        .padding(.top, 20)
                    
                    Text("AI MAGIC FILL")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(3)
                        .foregroundColor(PoshTheme.Colors.ink)
                }
                
                // Content
                VStack(spacing: 20) {
                    explainerRow(icon: "tag.fill", text: "Automatically identifies brands and sizes from your photos.")
                    explainerRow(icon: "list.bullet.indent", text: "Generates professional names and descriptive tags.")
                    explainerRow(icon: "folder.fill", text: "Catalogs your wardrobe 10x faster with AI enrichment.")
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // CTA
                VStack(spacing: 16) {
                    Button(action: onUpgrade) {
                        Text("UPGRADE TO UNLOCK")
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                    }
                    .poshButton()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("MAYBE LATER")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func explainerRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(PoshTheme.Colors.gold)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }
}
