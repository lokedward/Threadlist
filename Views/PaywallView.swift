// PaywallView.swift
// A luxurious, editorial-style paywall for Threaddit subscriptions

import SwiftUI

struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    
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
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundColor(PoshTheme.Colors.gold)
            
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
            benefitRow(icon: "sparkles", title: "Smart Magic Fill", subtitle: "Instant AI enrichment for all your garments.")
            benefitRow(icon: "wand.and.stars", title: "Photorealistic Outfits", subtitle: "Unlimited AI model looks for every occasion.")
            benefitRow(icon: "envelope.fill", title: "Automatic Imports", subtitle: "Scan your inbox for seamless wardrobe tracking.")
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
            tierCard(
                tier: .boutique,
                price: "$3.99 / mo",
                tagline: "The Everyday Enthusiast",
                isPopular: true
            )
            
            tierCard(
                tier: .atelier,
                price: "$9.99 / mo",
                tagline: "The Fashion Professional",
                isPopular: false
            )
        }
        .padding(.horizontal, 20)
    }
    
    private func tierCard(tier: SubscriptionTier, price: String, tagline: String, isPopular: Bool) -> some View {
        Button {
            subscriptionService.upgrade(to: tier)
            dismiss()
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
                    
                    Text("SELECT →")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.gold)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .stroke(isPopular ? PoshTheme.Colors.gold : PoshTheme.Colors.border, lineWidth: isPopular ? 2 : 0.5)
            )
            .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("SECURE PAYMENT VIA APP STORE")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
            
            Text("Restore Purchases")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                .underline()
        }
    }
}

#Preview {
    PaywallView()
}
