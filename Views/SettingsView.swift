// SettingsView.swift
// Settings menu with appearance and data management

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Removed colorScheme environment

    
    // Removed AppearanceMode AppStorage

    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedStudioOnboarding") private var hasCompletedStudioOnboarding = false
    
    @State private var showingClearConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingEmailImport = false
    @State private var showPaywall = false
    
    @Query private var allItems: [ClothingItem]
    @Query private var allCategories: [Category]
    @Query private var allOutfits: [Outfit]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                PoshTheme.Colors.canvas.ignoresSafeArea()
                
                // Subtle Background Branding
                Image("brand_logo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100)
                    .foregroundColor(PoshTheme.Colors.ink)
                    .opacity(0.12) // Increased for better visibility as "black on light"
                    .padding(.bottom, 60)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Membership Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("MEMBERSHIP")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(SubscriptionService.shared.currentTier.rawValue.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .tracking(1)
                                            .foregroundColor(PoshTheme.Colors.ink)
                                        
                                        Text(SubscriptionService.shared.currentTier == .free ? "Upgrade for unlimited wardrobe" : "Premium Member")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(SubscriptionService.shared.currentTier == .free ? "UPGRADE" : "MANAGE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(PoshTheme.Colors.gold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(PoshTheme.Colors.gold.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)

                        // Categories Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ORGANIZATION")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            NavigationLink {
                                CategoryManagementView()
                            } label: {
                                HStack {
                                    Label("ADD/REMOVE CATEGORIES", systemImage: "folder")
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(PoshTheme.Colors.gold)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            
                            /*
                            // Email Import Button
                            Button {
                                if SubscriptionService.shared.currentTier.canImportEmail {
                                    showingEmailImport = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                HStack {
                                    Label("IMPORT FROM GMAIL", systemImage: "envelope.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(1)
                                    
                                    if !SubscriptionService.shared.currentTier.canImportEmail {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(PoshTheme.Colors.gold)
                                    }
                                    
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(PoshTheme.Colors.gold)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            */
                        }
                        .padding(.horizontal)
                        
                        // Appearance Section Removed

                        
                        // Stats Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ARCHIVE STATISTICS")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            VStack(spacing: 20) {
                                let totalGarments = allItems.count
                                let limit = SubscriptionService.shared.currentTier.wardrobeLimit
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("TOTAL GARMENTS")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(1)
                                            .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                                        Spacer()
                                        if let limit = limit {
                                            Text("\(totalGarments) / \(limit)")
                                                .font(.system(size: 13, weight: .bold))
                                        } else {
                                            Text("\(totalGarments) / UNLIMITED")
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                    }
                                    
                                    if let limit = limit {
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(PoshTheme.Colors.ink.opacity(0.05))
                                                    .frame(height: 6)
                                                
                                                Capsule()
                                                    .fill(totalGarments >= limit ? Color.red : PoshTheme.Colors.gold)
                                                    .frame(width: geo.size.width * min(1.0, CGFloat(totalGarments) / CGFloat(limit)), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                }
                                
                                Divider().opacity(0.5)
                                
                                PoshDetailRow(label: "CATEGORIES", value: "\(allCategories.count)")
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Data Management Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DATA & PRIVACY")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            
                            VStack(spacing: 0) {
                                Button {
                                    exportData()
                                } label: {
                                    HStack {
                                        Label("EXPORT CATEGORIES (JSON)", systemImage: "square.and.arrow.up")
                                            .font(.system(size: 13, weight: .semibold))
                                            .tracking(1)
                                        Spacer()
                                    }
                                    .padding()
                                }
                                
                                Divider().padding(.horizontal)
                                
                                Button(role: .destructive) {
                                    showingClearConfirmation = true
                                } label: {
                                    HStack {
                                        Label("CLEAR ALL DATA", systemImage: "trash")
                                            .font(.system(size: 13, weight: .bold))
                                            .tracking(1)
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // About
                        VStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Text("THREADLIST")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(3)
                                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.8))
                                Text("VERSION 1.0.0")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                            }
                            
                            HStack(spacing: 20) {
                                Link("PRIVACY", destination: URL(string: "https://www.threadlist.app/privacy")!)
                                Link("TERMS", destination: URL(string: "https://www.threadlist.app/terms")!)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(PoshTheme.Colors.gold)
                        }
                        .padding(.top, 40)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS").font(.system(size: 14, weight: .bold)).tracking(2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.ink)
                }
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Clear All", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your clothing items and custom categories. This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            /*
            .sheet(isPresented: $showingEmailImport) {
                EmailImportView()
            }
            */
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }

    }
    
    private func exportData() {
        var exportData: [[String: Any]] = []
        
        for item in allItems {
            var itemDict: [String: Any] = [
                "id": item.id.uuidString,
                "name": item.name,
                "dateAdded": ISO8601DateFormatter().string(from: item.dateAdded),
                "tags": item.tags
            ]
            
            if let brand = item.brand {
                itemDict["brand"] = brand
            }
            if let size = item.size {
                itemDict["size"] = size
            }
            if let category = item.category {
                itemDict["category"] = category.name
            }
            
            exportData.append(itemDict)
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("threadlist_export.json")
            try jsonData.write(to: tempURL)
            
            exportURL = tempURL
            showingExportSheet = true
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func clearAllData() {
        // Delete all images
        for item in allItems {
            ImageStorageService.shared.deleteImage(withID: item.imageID)
        }
        
        // Delete all items
        for item in allItems {
            modelContext.delete(item)
        }
        
        // Delete custom categories (keep defaults)
        for category in allCategories {
            modelContext.delete(category)
        }
        
        // Delete all outfits
        for outfit in allOutfits {
            if let imageID = outfit.generatedImageID {
                ImageStorageService.shared.deleteImage(withID: imageID)
            }
            modelContext.delete(outfit)
        }
        
        // Re-seed defaults
        let defaultCategories = ["Tops", "Bottoms", "Outerwear", "Shoes", "Accessories"]
        for (index, name) in defaultCategories.enumerated() {
            let category = Category(name: name, displayOrder: index)
            modelContext.insert(category)
        }
        
        // Reset onboarding state
        hasCompletedOnboarding = false
        hasCompletedStudioOnboarding = false
    }
}

// AppearanceMode enum removed


// Share sheet for exporting
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
