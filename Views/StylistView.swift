// StylistView.swift
// Main container for the AI Stylist feature

import SwiftUI
import SwiftData

struct StylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.dateAdded, order: .reverse) private var items: [ClothingItem]
    
    @State private var selectedItems: Set<UUID> = []
    @State private var showingSelection = true
    @State private var selectedTab: StylistTab = .closet
    
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
    
    @AppStorage("stylistModelGender") private var genderRaw = "female"
    
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
                .overlay {
                    if isStyling {
                        ProcessingOverlayView(message: dynamicLoadingMessage)
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
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
                
                // Consolidated Bottom Drawer
                VStack(spacing: 0) {
                    Divider()
                        .background(PoshTheme.Colors.ink.opacity(0.1))
                    
                    // Tab Bar
                    HStack(spacing: 0) {
                        ForEach(StylistTab.allCases) { tab in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                    showingSelection = true
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                                        .tracking(1)
                                        .foregroundColor(selectedTab == tab ? PoshTheme.Colors.gold : PoshTheme.Colors.ink.opacity(0.4))
                                    
                                    // Underline
                                    Rectangle()
                                        .fill(selectedTab == tab ? PoshTheme.Colors.gold : Color.clear)
                                        .frame(height: 2)
                                        .padding(.horizontal, 20)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Collapse/Expand toggle
                        Button {
                            withAnimation(.spring()) {
                                showingSelection.toggle()
                            }
                        } label: {
                            Image(systemName: showingSelection ? "chevron.down" : "chevron.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    if showingSelection {
                        Group {
                            switch selectedTab {
                            case .closet:
                                ItemSelectionGridView(
                                    items: items,
                                    selectedItems: $selectedItems
                                )
                                .padding(.top, 4)
                            case .styling:
                                StylingTabView(onStyleMe: {
                                    performAISuggestion()
                                })
                            case .profile:
                                ProfileTabView()
                            }
                        }
                        .frame(maxHeight: 350)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
