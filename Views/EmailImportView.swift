// EmailImportView.swift
// Onboarding flow for Gmail-based wardrobe import

import SwiftUI

struct EmailImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = EmailOnboardingService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingTimeRangeSelection = false
    @State private var selectedRange: TimeRange = .sixMonths
    @State private var showingUpgradePrompt = false
    @State private var importedItems: [EmailProductItem] = []
    @State private var showingReviewScreen = false
    @State private var showingBulkAddFlow = false
    @State private var showingPaywall = false
    
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
        .onChange(of: showingBulkAddFlow) { oldValue, newValue in
            // If we were showing the bulk flow and now we're not, 
            // it means the user either finished or cancelled, so we should return to main navigation.
            if oldValue == true && newValue == false {
                dismiss()
            }
        }
        .alert("Upgrade Required", isPresented: $showingUpgradePrompt) {
            Button("Upgrade to Premium") {
                showingPaywall = true
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
                .foregroundColor(PoshTheme.Colors.ink)
            
            // Title
            Text("Import from Gmail")
                .font(PoshTheme.Typography.headline(size: 24))
                .foregroundColor(PoshTheme.Colors.headline)
            
            // Description
            VStack(spacing: 12) {
                EmailFeatureRow(
                    icon: "magnifyingglass",
                    text: "We'll search for order confirmations"
                )
                EmailFeatureRow(
                    icon: "photo.fill",
                    text: "Extract product images automatically"
                )
                EmailFeatureRow(
                    icon: "lock.shield.fill",
                    text: "Processed securely on your device"
                )
                EmailFeatureRow(
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
                    if subscriptionService.currentTier != .free {
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
                        isLocked: subscriptionService.currentTier == .free
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
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
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
        .background(PoshTheme.Colors.canvas)
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Progress indicator
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(PoshTheme.Colors.ink)
                
                if let progress = service.progress {
                    // Main phase text
                    Text(progress.phase.displayText)
                        .font(PoshTheme.Typography.headline(size: 18))
                        .foregroundColor(PoshTheme.Colors.headline)
                    
                    // Detail message (retailer being processed)
                    if let detailMessage = progress.detailMessage {
                        Text(detailMessage)
                            .font(.system(size: 14))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    if progress.totalEmails > 0 {
                        // Progress bar
                        ProgressView(value: progress.percentComplete)
                            .tint(PoshTheme.Colors.ink)
                            .frame(width: 200)
                        
                        // Email count
                        Text("\(progress.processedEmails) of \(progress.totalEmails) emails")
                            .font(.system(size: 13))
                            .foregroundColor(PoshTheme.Colors.body)
                        
                        // Found items count
                        if progress.foundItems > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                
                                Text("Found \(progress.foundItems) item\(progress.foundItems == 1 ? "" : "s")")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
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
        .background(PoshTheme.Colors.canvas)
    }
    
    // MARK: - Review Screen
    
    // MARK: - Review Screen (Transition)
    
    private var reviewScreen: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .padding(.top, 20)
                
                Text("Found \(importedItems.count) items")
                    .font(PoshTheme.Typography.headline(size: 24))
                    .foregroundColor(PoshTheme.Colors.headline)
            }
            .padding(.bottom, 10)
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button {
                    showingBulkAddFlow = true
                } label: {
                    Text("Review & Add All")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PoshTheme.Colors.ink)
                        .cornerRadius(12)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(PoshTheme.Colors.body)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PoshTheme.Colors.canvas)
        .fullScreenCover(isPresented: $showingBulkAddFlow) {
            AddItemView(prefilledItems: importedItems)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Actions
    
    private func startImport() {
        Task {
            do {
                importedItems = try await service.importFromGmail(
                    timeRange: selectedRange
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

struct EmailFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(PoshTheme.Colors.ink)
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
                            .foregroundColor(PoshTheme.Colors.ink)
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
                    .foregroundColor(PoshTheme.Colors.ink)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? PoshTheme.Colors.ink.opacity(0.1) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? PoshTheme.Colors.ink : Color.clear, lineWidth: 2)
        )
    }
}



// MARK: - Preview

#Preview {
    EmailImportView()
}
