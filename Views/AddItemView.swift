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
    @State private var croppingItem: CroppableImage?

    
    // Metadata
    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var brand = ""
    @State private var size = ""
    @State private var tagsText = ""
    
    @State private var isSaving = false
    @State private var isProcessingImage = false
    
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
                        
                        HStack {
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
                    selectedImage = croppedImage
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
                    // Prevents "Unbalanced calls to begin/end appearance transitions" freeze
                    try? await Task.sleep(nanoseconds: AppConstants.Animation.processingDelay)
                    
                    await MainActor.run {
                        croppingItem = CroppableImage(image: downsampledImage)
                        selectedPhotoItem = nil // Reset picker selection
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
        
        // Parse tags
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
                    dismiss()
                }
            } catch {
                print("Error saving item: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}





#Preview {
    AddItemView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
