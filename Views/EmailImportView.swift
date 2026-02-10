// EmailImportView.swift
// Onboarding flow for Gmail-based wardrobe import

import SwiftUI

struct EmailImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = EmailOnboardingService.shared
    @State private var showingTimeRangeSelection = false
    @State private var selectedRange: TimeRange = .sixMonths
    @State private var showingUpgradePrompt = false
    @State private var importedItems: [ClothingItem] = []
    @State private var showingReviewScreen = false
    
    // User tier (get from app state)
    let userTier: GenerationTier
    
    var body: some View {
        ZStack {
            if service.isProcessing {
                processingView
            } else if showingReviewScreen {
                reviewScreen
            } else {
                introductionView
            }
        }
        .alert("Upgrade Required", isPresented: $showingUpgradePrompt) {
            Button("Upgrade to Premium") {
                // TODO: Navigate to subscription screen
            }
            Button("Use 6 Months", role: .cancel) {
                selectedRange = .sixMonths
                showingUpgradePrompt = false
            }
        } message: {
            Text("Import from the last 2 years with Premium! Get unlimited AI styling, extended email import, and more.")
        }
    }
    
    // MARK: - Introduction Screen
    
    private var introductionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundColor(PoshTheme.Colors.primaryAccentStart)
            
            // Title
            Text("Import from Gmail")
                .font(PoshTheme.Typography.headline(size: 24))
                .foregroundColor(PoshTheme.Colors.headline)
            
            // Description
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "magnifyingglass",
                    text: "We'll search for order confirmations"
                )
                FeatureRow(
                    icon: "photo.fill",
                    text: "Extract product images automatically"
                )
                FeatureRow(
                    icon: "lock.shield.fill",
                    text: "Processed securely on your device"
                )
                FeatureRow(
                    icon: "clock.fill",
                    text: "Access expires in 1 hour"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Time range selector
            VStack(spacing: 16) {
                Button {
                    selectedRange = .sixMonths
                    showingTimeRangeSelection = false
                    startImport()
                } label: {
                    TimeRangeOption(
                        range: .sixMonths,
                        isSelected: selectedRange == .sixMonths && !showingTimeRangeSelection,
                        isPremium: false
                    )
                }
                
                Button {
                    if userTier == .premium {
                        selectedRange = .twoYears
                        showingTimeRangeSelection = false
                        startImport()
                    } else {
                        showingUpgradePrompt = true
                    }
                } label: {
                    TimeRangeOption(
                        range: .twoYears,
                        isSelected: selectedRange == .twoYears && !showingTimeRangeSelection,
                        isPremium: true,
                        isLocked: userTier == .free
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Manual upload alternative
            Button {
                // TODO: Navigate to manual upload flow
                dismiss()
            } label: {
                Text("Prefer not to connect? Upload manually instead")
                    .font(.system(size: 13))
                    .foregroundColor(PoshTheme.Colors.secondaryAccent)
            }
            .padding(.bottom, 8)
            
            // Cancel
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(PoshTheme.Colors.body)
            .padding(.bottom, 32)
        }
        .background(PoshTheme.Colors.background)
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Progress indicator
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(PoshTheme.Colors.primaryAccentStart)
                
                if let progress = service.progress {
                    Text(progress.phase.displayText)
                        .font(PoshTheme.Typography.headline(size: 18))
                        .foregroundColor(PoshTheme.Colors.headline)
                    
                    if progress.totalEmails > 0 {
                        Text("\(progress.processedEmails) of \(progress.totalEmails) emails")
                            .font(.system(size: 14))
                            .foregroundColor(PoshTheme.Colors.body)
                        
                        ProgressView(value: progress.percentComplete)
                            .tint(PoshTheme.Colors.primaryAccentStart)
                            .frame(width: 200)
                    }
                }
            }
            
            Spacer()
            
            // Privacy note
            Text("Access will auto-revoke when complete")
                .font(.system(size: 12))
                .foregroundColor(PoshTheme.Colors.body)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PoshTheme.Colors.background)
    }
    
    // MARK: - Review Screen
    
    private var reviewScreen: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Found \(importedItems.count) items!")
                    .font(PoshTheme.Typography.headline(size: 24))
                    .foregroundColor(PoshTheme.Colors.headline)
                
                Text("Review and add to your wardrobe")
                    .font(.system(size: 14))
                    .foregroundColor(PoshTheme.Colors.body)
            }
            .padding(.top, 32)
            
            // Grid of items
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(importedItems, id: \.id) { item in
                        ImportedItemCard(item: item)
                    }
                }
                .padding(.horizontal, 24)
            }
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    // TODO: Add all items to wardrobe
                    dismiss()
                } label: {
                    Text("Add All to Wardrobe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PoshTheme.Colors.primaryAccentStart)
                        .cornerRadius(12)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(PoshTheme.Colors.body)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(PoshTheme.Colors.background)
    }
    
    // MARK: - Actions
    
    private func startImport() {
        Task {
            do {
                importedItems = try await service.importFromGmail(
                    timeRange: selectedRange,
                    userTier: userTier
                )
                showingReviewScreen = true
            } catch {
                // Show error
                print("Import failed: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

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
                .font(.system(size: 14))
                .foregroundColor(PoshTheme.Colors.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TimeRangeOption: View {
    let range: TimeRange
    let isSelected: Bool
    let isPremium: Bool
    var isLocked: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(range.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PoshTheme.Colors.headline)
                    
                    if isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                    }
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(PoshTheme.Colors.body)
                    }
                }
                
                Text(isPremium ? "More complete wardrobe" : "Fastest, captures recent items")
                    .font(.system(size: 12))
                    .foregroundColor(PoshTheme.Colors.body)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PoshTheme.Colors.primaryAccentStart)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? PoshTheme.Colors.primaryAccentStart.opacity(0.1) : PoshTheme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? PoshTheme.Colors.primaryAccentStart : Color.clear, lineWidth: 2)
        )
    }
}

struct ImportedItemCard: View {
    let item: ClothingItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            if let image = ImageStorageService.shared.loadImage(withID: item.imageID) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            }
            
            // Name
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(PoshTheme.Colors.headline)
                .lineLimit(2)
            
            // Brand
            if let brand = item.brand {
                Text(brand)
                    .font(.system(size: 10))
                    .foregroundColor(PoshTheme.Colors.body)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailImportView(userTier: .free)
}
