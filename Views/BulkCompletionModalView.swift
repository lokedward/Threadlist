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
            
            VStack(spacing: 40) {
                // Success Icon
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(PoshTheme.Colors.gold)
                    .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text(itemsAdded == 1 ? "ITEM ADDED" : "UPLOAD COMPLETE")
                        .poshHeadline(size: 16)
                    
                    Rectangle()
                        .fill(PoshTheme.Colors.gold)
                        .frame(width: 30, height: 1)
                }
                
                // Summary
                VStack(spacing: 16) {
                    Text("\(itemsAdded)")
                        .font(PoshTheme.Typography.headline(size: 72))
                        .foregroundColor(PoshTheme.Colors.ink)
                    
                    Text(itemsAdded == 1 ? "NEW PIECE SECURED" : "NEW PIECES SECURED")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                }
                
                Spacer()
                
                // CTA
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Text("ADD MORE")
                        .frame(maxWidth: .infinity)
                }
                .poshButton()
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    BulkCompletionModalView(itemsAdded: 12, onDismiss: {})
}
