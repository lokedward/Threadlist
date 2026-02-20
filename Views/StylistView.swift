// StylistView.swift
// Main container for the AI Stylist feature

import SwiftUI
import SwiftData

struct StylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.dateAdded, order: .reverse) private var items: [ClothingItem]
    
    @ObservedObject private var subscription = SubscriptionService.shared
    
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
    

    @State private var showPaywall = false
    @State private var showingUsagePopup = false
    
    @State private var dynamicLoadingMessage = "STYLIST IS THINKING..."
    
    // Onboarding State
    @AppStorage("hasCompletedStudioOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    
    @AppStorage("stylistModelGender") private var genderRaw = "female"
    
    // Computed property to sync local state with AppStorage
    private var modelGender: Gender {
        genderRaw == "male" ? .male : .female
    }
    
    var body: some View {
        mainContent
            .sheet(isPresented: $showingOnboarding) {
                StudioOnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    selectedTab = .closet
                }, showPaywall: $showPaywall)
            }
            .onAppear {
                // Show onboarding for first-time users who just unlocked the Studio
                if !hasCompletedOnboarding && items.count >= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingOnboarding = true
                    }
                }
            }
    }
    
    private var mainContent: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            if items.count < 3 {
                // Lockout Screen
                StudioLockoutView(itemCount: items.count)
            } else {
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
                        .padding(.top, 12)
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
                                case .model:
                                    ProfileTabView(showPaywall: $showPaywall)
                                }
                            }
                            .frame(maxHeight: 350)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .background(PoshTheme.Colors.canvas)
                    .poshCard()
                    .padding(.horizontal)
                    .padding(.bottom)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let swipeDistance = value.translation.height
                                if swipeDistance > 50 && showingSelection {
                                    // Swipe down -> Collapse
                                    withAnimation(.spring()) {
                                        showingSelection = false
                                    }
                                } else if swipeDistance < -50 && !showingSelection {
                                    // Swipe up -> Expand
                                    withAnimation(.spring()) {
                                        showingSelection = true
                                    }
                                }
                            }
                    )
                }
                .allowsHitTesting(!isStyling)
                
                if showingUsagePopup {
                    Color.black.opacity(0.01)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showingUsagePopup = false } }
                    
                    VStack {
                        HStack {
                            Spacer()
                            usagePopupView
                                .padding(.top, 50)
                                .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)), removal: .opacity))
                    .zIndex(100)
                }
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingUsagePopup.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(PoshTheme.Colors.gold)
                        
                        Text("\(subscription.remainingGenerations)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PoshTheme.Colors.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .stroke(PoshTheme.Colors.gold.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .opacity(items.count >= 3 ? 1 : 0)
            }
        }
    }
    
    private var usagePopupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STYLE ME LIMITS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(PoshTheme.Colors.gold)
                
                if subscription.currentTier == .atelier {
                    Text("Unlimited looks available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(PoshTheme.Colors.ink)
                } else {
                    let used = subscription.currentTier.limitPeriod == .monthly ? subscription.monthlyGenerationCount : subscription.generationCount
                    let limit = subscription.currentTier.styleMeLimit
                    
                    Text("\(limit - used) of \(limit) looks available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(PoshTheme.Colors.ink)
                }
            }
            
            if subscription.currentTier != .atelier {
                Divider()
                    .background(PoshTheme.Colors.ink.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("PREMIUM TIER")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                    
                    HStack {
                        Text(subscription.currentTier == .free ? "Boutique Plus" : "Atelier Elite")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(subscription.currentTier == .free ? "50 / mo" : "Unlimited")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PoshTheme.Colors.gold)
                    }
                    
                    Button {
                        showingUsagePopup = false
                        showPaywall = true
                    } label: {
                        Text("UPGRADE NOW")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .underline()
                            .foregroundColor(PoshTheme.Colors.ink)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .poshCard()
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
    }
    
    private func performAISuggestion() {
        // Guard against multiple taps/executions
        guard !isStyling, !isGenerating else { return }
        
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
                // 1. Pick the items & get the visual description in one go
                let (suggestedIDs, visualDescription) = try await StylistService.shared.suggestOutfit(for: targetOccasion, availableItems: items)
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.selectedItems = suggestedIDs
                        self.showingSelection = false
                    }
                }
                
                // 2. Generate the Inspo Image
                let selectedClothingItems = items.filter { suggestedIDs.contains($0.id) }
                if !selectedClothingItems.isEmpty {
                    // We keep the same original styling message throughout the whole process 
                    // to avoid the "double loading" message flip.
                    
                    let image = try await StylistService.shared.generateModelPhoto(
                        items: selectedClothingItems,
                        gender: modelGender,
                        preComputedDescription: visualDescription
                    )
                    
                    await MainActor.run {
                        withAnimation(.spring()) {
                            self.generatedImage = image
                            self.isStyling = false // Dismiss global overlay only when done
                            self.isSaved = false
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
