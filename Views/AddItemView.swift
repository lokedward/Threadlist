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
                    ScrollableCropperView(image: image) { croppedImage in
                        selectedImage = croppedImage
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
                    
                    // Critical Fix: Wait for PhotosPicker to fully dismiss before presenting cropper
                    // Prevents "Unbalanced calls to begin/end appearance transitions" freeze
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                    
                    await MainActor.run {
                        imageToCrop = resizedImage
                        showingImageCropper = true
                        selectedPhotoItem = nil // Reset picker selection
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
