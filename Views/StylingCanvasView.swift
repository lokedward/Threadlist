// StylingCanvasView.swift
// View for generating AI-styled model photos with tier support

import SwiftUI

struct StylingCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    let selectedItems: [ClothingItem]
    let gender: Gender
    
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showUpgradePrompt = false
    
    let stylistService = StylistService.shared
    
    var body: some View {
        ZStack {
            // Background gradient
            RadialGradient(
                colors: [PoshTheme.Colors.ink.opacity(0.05), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            
            if let generated = generatedImage {
                // Show generated model photo
                VStack(spacing: 8) {
                    ZoomableImageView(image: generated)
                        .frame(maxHeight: 500) // Contain the zoomable area
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .poshCard()
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text("Pinch to zoom • Double tap to reset")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                        .padding(.bottom, 8)
                    
                    // Regenerate button
                    HStack(spacing: 16) {
                        Button {
                            generatedImage = nil
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20))
                                Text("RETRY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                            }
                            .foregroundColor(PoshTheme.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .poshCard()
                        }
                        
                        Button {
                            saveOutfit()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "heart")
                                    .font(.system(size: 20))
                                Text("SAVE LOOK")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                            }
                            .foregroundColor(Color.white) // Use direct white
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PoshTheme.Colors.ink)
                            .cornerRadius(0) // Posh style
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else if selectedItems.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Text("SELECT PIECES TO START STYLING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                }
            } else if isGenerating {
                // Loading state
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(PoshTheme.Colors.ink)
                    
                    VStack(spacing: 8) {
                        Text("CREATING YOUR LOOK")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundColor(PoshTheme.Colors.ink)
                        
                        Text(stylistService.userTier == .free ? "Using 1 of 3 daily generations" : "Premium quality generation")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
                .background(PoshTheme.Colors.stone)
                .poshCard()
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // Ready to generate - show mannequin + button
                VStack {
                    Spacer()
                    
                    // Model placeholder
                    Image(systemName: gender == .female ? "figure.stand.dress" : "figure.stand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 350)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.1))
                    
                    Spacer()
                    
                    // Usage info
                    if let remaining = stylistService.generationsRemaining {
                        Text("\(remaining) free generations remaining today")
                            .poshBody(size: 12)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                            .padding(.bottom, 8)
                    }
                    
                    // Generate Button
                    Button {
                        generateLook()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                            Text(stylistService.userTier == .free ? "GENERATE LOOK (FREE)" : "GENERATE LOOK")
                                .tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .poshButton()
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            
            // Error overlay
            if let error = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: error.contains("limit") ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                            .foregroundColor(error.contains("limit") ? .orange : .red)
                        Text(error)
                            .poshBody(size: 12)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .poshCard()
                    .padding()
                    .transition(.move(edge: .bottom))
                    .onTapGesture {
                        if error.contains("limit") {
                            showUpgradePrompt = true
                        }
                    }
                }
                .onAppear {
                    if !error.contains("limit") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                errorMessage = nil
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView()
        }
    }
    
    private func generateLook() {
        guard !selectedItems.isEmpty else { return }
        
        errorMessage = nil
        isGenerating = true
        
        Task {
            do {
                let image = try await StylistService.shared.generateModelPhoto(
                    items: selectedItems,
                    gender: gender
                )
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        generatedImage = image
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    withAnimation {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func saveOutfit() {
        guard let image = generatedImage else { return }
        
        Task {
            // Save image to disk
            if let imageID = ImageStorageService.shared.saveImage(image) {
                // Create Outfit
                let outfit = Outfit(generatedImageID: imageID, items: selectedItems)
                modelContext.insert(outfit)
                
                await MainActor.run {
                    generatedImage = nil
                    // Ideally show success toast
                }
            }
        }
    }
}

// MARK: - Upgrade Prompt

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                PoshTheme.Colors.canvas.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("UPGRADE TO PREMIUM")
                            .poshHeadline(size: 24)
                            .multilineTextAlignment(.center)
                        
                        Text("Unlimited AI-Generated Looks")
                            .poshBody(size: 16)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "sparkles", text: "Unlimited AI generations")
                        FeatureRow(icon: "wand.and.stars", text: "Premium quality (Google Imagen)")
                        FeatureRow(icon: "clock.arrow.circlepath", text: "Save outfit history")
                        FeatureRow(icon: "bolt.fill", text: "Priority processing")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .poshCard()
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // CTA
                    VStack(spacing: 16) {
                        Button {
                            // TODO: Implement IAP
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Text("START FREE TRIAL")
                                    .tracking(2)
                                Text("Then $4.99/month")
                                    .font(.system(size: 10))
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .poshButton()
                        .padding(.horizontal, 24)
                        
                        Button("Maybe Later") {
                            dismiss()
                        }
                        .poshBody(size: 14)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(PoshTheme.Colors.ink)
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(PoshTheme.Colors.ink)
                .frame(width: 24)
            
            Text(text)
                .poshBody(size: 14)
        }
    }
}

#Preview {
    StylingCanvasView(selectedItems: [], gender: .female)
}
