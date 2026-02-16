// BulkCompletionModalView.swift
// Confirmation modal shown after completing a bulk upload session

import SwiftUI

struct BulkCompletionModalView: View {
    let itemsAdded: Int
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Success Icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PoshTheme.Colors.gold.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(PoshTheme.Colors.gold)
                    }
                    .padding(.top, 20)
                    
                    Text(itemsAdded == 1 ? "ITEM ADDED" : "UPLOAD COMPLETE")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(3)
                        .foregroundColor(PoshTheme.Colors.ink)
                }
                
                // Summary
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(itemsAdded)")
                            .font(.system(size: 48, weight: .light, design: .serif))
                            .foregroundColor(PoshTheme.Colors.gold)
                        
                        Text(itemsAdded == 1 ? "ITEM" : "ITEMS")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(2)
                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            .padding(.top, 12)
                    }
                    
                    Text(itemsAdded == 1 ? "added to your wardrobe" : "added to your wardrobe")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.7))
                }
                
                Spacer()
                
                // CTA
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Text("VIEW WARDROBE")
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                }
                .poshButton()
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    BulkCompletionModalView(itemsAdded: 12, onDismiss: {})
}
