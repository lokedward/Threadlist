// PaywallView.swift
// A luxurious, editorial-style paywall for Threaddit subscriptions
// Connected to StoreKit 2 for App Store compliance

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    headerSection
                    benefitsSection
                    tierSelectionSection
                    footerSection
                }
                .padding(.vertical, 40)
            }
            
            if isPurchasing {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.8)))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .disabled(isPurchasing)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("ELEVATE YOUR STYLE")
                    .poshHeadline(size: 28)
                    .multilineTextAlignment(.center)
                
                Text("Unlock the full potential of your digital walk-in.")
                    .poshBody(size: 16)
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            benefitRow(icon: "infinity", title: "Unlimited Wardrobe", subtitle: "Digitize every piece, from couture to core.")
            benefitRow(icon: "wand.and.stars", title: "Photorealistic Outfits", subtitle: "Unlimited AI model looks for every occasion.")
            benefitRow(icon: "crown.fill", title: "Premium Branding", subtitle: "Exclusive high-end model aesthetics.")
        }
        .padding(.horizontal, 30)
    }
    
    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(PoshTheme.Colors.gold)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(PoshTheme.Colors.ink)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var tierSelectionSection: some View {
        VStack(spacing: 16) {
            if !subscriptionService.isLoaded {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("CONSULTING THE ATELIER...")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else if let error = subscriptionService.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(PoshTheme.Colors.gold)
                    Text(error.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                    Button {
                        Task { await subscriptionService.fetchProducts() }
                    } label: {
                        Text("RETRY CONNECTION")
                            .font(.system(size: 11, weight: .bold))
                            .underline()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .foregroundColor(PoshTheme.Colors.ink)
            } else {
                #if DEBUG
                if subscriptionService.products.isEmpty {
                    VStack(spacing: 8) {
                        Text("DEVELOPER PREVIEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(PoshTheme.Colors.gold)
                        
                        tierCard(
                            tier: .boutique,
                            price: "$3.99",
                            tagline: "The Everyday Enthusiast",
                            isPopular: true
                        )
                        
                        tierCard(
                            tier: .atelier,
                            price: "$6.99",
                            tagline: "The Fashion Professional",
                            isPopular: false
                        )
                    }
                } else {
                    tierSelectionSectionContent
                }
                #else
                tierSelectionSectionContent
                #endif
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var tierSelectionSectionContent: some View {
        tierCard(
            tier: .boutique,
            price: priceFor(.boutique),
            tagline: "The Everyday Enthusiast",
            isPopular: true
        )
        
        tierCard(
            tier: .atelier,
            price: priceFor(.atelier),
            tagline: "The Fashion Professional",
            isPopular: false
        )
    }
    
    private func priceFor(_ tier: SubscriptionTier) -> String {
        guard let productId = tier.productId,
              let product = subscriptionService.products.first(where: { $0.id == productId }) else {
            return "Unavailable"
        }
        return product.displayPrice
    }
    
    private func tierCard(tier: SubscriptionTier, price: String, tagline: String, isPopular: Bool) -> some View {
        Button {
            handlePurchase(tier)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tier.rawValue.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .tracking(3)
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Spacer()
                    
                    if isPopular {
                        Text("POPULAR")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PoshTheme.Colors.gold)
                            .foregroundColor(.white)
                    }
                    
                    if subscriptionService.currentTier == tier {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(PoshTheme.Colors.gold)
                    }
                }
                
                Text(tagline)
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                
                HStack(alignment: .bottom) {
                    Text(price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Spacer()
                    
                    Text(subscriptionService.currentTier == tier ? "ACTIVE" : "SELECT →")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(PoshTheme.Colors.canvas)
            .overlay(
                Rectangle()
                    .stroke(isPopular ? PoshTheme.Colors.gold : PoshTheme.Colors.border, lineWidth: isPopular ? 2 : 0.5)
            )
            .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(subscriptionService.currentTier == tier)
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("SECURE PAYMENT VIA APP STORE")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
            
            HStack(spacing: 24) {
                Button {
                    handleRestore()
                } label: {
                    Text("Restore Purchases")
                        .underline()
                }
                
                Link("Privacy Policy", destination: URL(string: "https://www.threadlist.app/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://www.threadlist.app/terms")!)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
        }
    }
    
    private func handlePurchase(_ tier: SubscriptionTier) {
        isPurchasing = true
        Task {
            do {
                try await subscriptionService.purchase(tier)
                if subscriptionService.currentTier == tier {
                    dismiss()
                }
            } catch {
                print("❌ Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
    
    private func handleRestore() {
        isPurchasing = true
        Task {
            await subscriptionService.restorePurchases()
            isPurchasing = false
            if subscriptionService.currentTier != .free {
                dismiss()
            }
        }
    }
}

#Preview {
    PaywallView()
}
