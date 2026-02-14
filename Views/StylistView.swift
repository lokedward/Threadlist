// StylistView.swift
// Main container for the AI Stylist feature

import SwiftUI
import SwiftData

struct StylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.dateAdded, order: .reverse) private var items: [ClothingItem]
    
    @State private var selectedItems: Set<UUID> = []
    
    // AI Suggestion State
    @AppStorage("stylistOccasion") private var occasionRaw = StylistOccasion.casual.rawValue
    @AppStorage("stylistCustomOccasion") private var customOccasion = ""
    @State private var isStyling = false
    
    // Generation State (Shared with Canvas)
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var isSaved = false
    
    @State private var stylistMessage: String?
    @State private var showMessage = false
    @State private var showPaywall = false
    
    @State private var dynamicLoadingMessage = "STYLIST IS THINKING..."
    
    // Computed property to sync local state with AppStorage
    private var modelGender: Gender {
        genderRaw == "male" ? .male : .female
    }
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Styling Canvas
                StylingCanvasView(
                    selectedItems: items.filter { selectedItems.contains($0.id) },
                    gender: modelGender,
                    generatedImage: $generatedImage,
                    isGenerating: $isGenerating,
                    isSaved: $isSaved
                )
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if !isStyling && !isGenerating {
                        Button {
                            showingMagicPopup = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(PoshTheme.Colors.ink)
                                    .frame(width: 56, height: 56)
                                    .goldGlow()
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundColor(PoshTheme.Colors.gold)
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay {
                    if isStyling {
                        ProcessingOverlayView(message: dynamicLoadingMessage)
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
                .sheet(isPresented: $showingMagicPopup) {
                    StylistAIPopupView(onStyleMe: {
                        performAISuggestion()
                    })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                
                // Stylist Message Overlay
                if showMessage, let message = stylistMessage {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 14))
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                            
                            Text(message)
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .italic()
                                .foregroundColor(PoshTheme.Colors.ink)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeOut) { showMessage = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                                    .padding(8)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            PoshTheme.Colors.stone
                                .overlay(
                                    Rectangle()
                                        .stroke(PoshTheme.Colors.ink.opacity(0.05), lineWidth: 1)
                                )
                        )
                        .poshCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    .zIndex(10)
                }
                
                // Bottom Selection Drawer/Grid
                VStack(spacing: 0) {
                    Divider()
                        .background(PoshTheme.Colors.ink.opacity(0.1))
                    
                    
                    HStack {
                        HStack(spacing: 6) {
                            Text("YOUR CLOSET")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            if !selectedItems.isEmpty {
                                Text("(\(selectedItems.count))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(PoshTheme.Colors.ink)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring()) {
                                showingSelection.toggle()
                            }
                        } label: {
                            Image(systemName: showingSelection ? "chevron.down" : "chevron.up")
                                .foregroundColor(PoshTheme.Colors.ink)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.5))
                    
                    if showingSelection {
                        ItemSelectionGridView(
                            items: items,
                            selectedItems: $selectedItems
                        )
                        .transition(.move(edge: .bottom))
                        .frame(maxHeight: 350)
                    }
                }
                .background(.ultraThinMaterial)
                .poshCard()
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("THE STUDIO").poshHeadline(size: 18)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(PoshTheme.Colors.ink)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            StylistSettingsView()
            .presentationDetents([.medium, .large])
        }
    }
    
    private func performAISuggestion() {
        // Check Limit
        if !SubscriptionService.shared.canPerformStyleMe() {
            showPaywall = true
            return
        }
        
        let targetOccasion = occasionRaw == StylistOccasion.custom.rawValue ? customOccasion : occasionRaw
        
        dynamicLoadingMessage = LoadingMessageService.shared.randomMessage(for: .styling)
        isStyling = true
        generatedImage = nil // Reset canvas
        
        Task {
            do {
                // 1. Pick the items
                let (suggestedIDs, explanation) = try await StylistService.shared.suggestOutfit(for: targetOccasion, availableItems: items)
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.selectedItems = suggestedIDs
                        self.showingSelection = false
                        self.stylistMessage = explanation
                    }
                }
                
                // 2. Generate the Inspo Image
                let selectedClothingItems = items.filter { suggestedIDs.contains($0.id) }
                if !selectedClothingItems.isEmpty {
                    await MainActor.run {
                        self.dynamicLoadingMessage = LoadingMessageService.shared.randomMessage(for: .generation)
                        self.isStyling = false
                        self.isGenerating = true
                    }
                    
                    let image = try await StylistService.shared.generateModelPhoto(
                        items: selectedClothingItems,
                        gender: modelGender
                    )
                    
                    await MainActor.run {
                        withAnimation(.spring()) {
                            self.generatedImage = image
                            self.isGenerating = false
                            self.isSaved = false
                            SubscriptionService.shared.recordGeneration()
                        }
                        
                        // Show the message with a slight delay after image appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.spring()) {
                                self.showMessage = true
                            }
                            
                            // Auto-dismiss after 6 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                                withAnimation(.easeOut) {
                                    if self.stylistMessage == explanation {
                                        self.showMessage = false
                                    }
                                }
                            }
                        }
                        
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } else {
                    await MainActor.run {
                        self.isStyling = false
                    }
                }
                
            } catch {
                print("❌ Styling Error: \(error)")
                await MainActor.run {
                    self.isStyling = false
                    self.isGenerating = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StylistView()
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
