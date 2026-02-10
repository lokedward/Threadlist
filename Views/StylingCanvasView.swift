// StylingCanvasView.swift
// View for generating AI-styled model photos with tier support

import SwiftUI

struct StylingCanvasView: View {
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
                colors: [PoshTheme.Colors.primaryAccentEnd.opacity(0.05), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            
            if let generated = generatedImage {
                // Show generated model photo
                VStack {
                    Image(uiImage: generated)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .poshCard()
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    
                    // Regenerate button
                    Button {
                        generatedImage = nil
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("TRY DIFFERENT LOOK")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    }
                    .padding(.bottom)
                }
            } else if selectedItems.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    
                    Text("SELECT PIECES TO START STYLING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                }
            } else if isGenerating {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(PoshTheme.Colors.primaryAccentStart)
                    
                    Text("GENERATING YOUR LOOK...")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                    
                    Text(stylistService.userTier == .free ? "Using free tier (SDXL)" : "Using premium quality")
                        .poshBody(size: 12)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .poshCard()
            } else {
                // Ready to generate - show mannequin + button
                VStack {
                    Spacer()
                    
                    // Model placeholder
                    Image(systemName: gender == .female ? "figure.stand.dress" : "figure.stand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 350)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.1))
                    
                    Spacer()
                    
                    // Usage info
                    if let remaining = stylistService.generationsRemaining {
                        Text("\(remaining) free generations remaining this month")
                            .poshBody(size: 12)
                            .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.7))
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
                    gender: gender == .female ? .female : .male
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
}

// MARK: - Upgrade Prompt

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                PoshTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("UPGRADE TO PREMIUM")
                            .poshHeadline(size: 24)
                            .multilineTextAlignment(.center)
                        
                        Text("Unlimited AI-Generated Looks")
                            .poshBody(size: 16)
                            .foregroundColor(PoshTheme.Colors.secondaryAccent)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "sparkles", text: "Unlimited AI generations")
                        FeatureRow(icon: "wand.and.stars", text: "Premium quality (Google Imagen)")
                        FeatureRow(icon: "clock.arrow.circlepath", text: "Save outfit history")
                        FeatureRow(icon: "bolt.fill", text: "Priority processing")
                    }
                    .padding()
                    .background(PoshTheme.Colors.cardBackground)
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
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
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
                            .foregroundColor(PoshTheme.Colors.secondaryAccent)
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
                .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                .frame(width: 24)
            
            Text(text)
                .poshBody(size: 14)
        }
    }
}

#Preview {
    StylingCanvasView(selectedItems: [], gender: .female)
}
