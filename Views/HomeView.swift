// HomeView.swift
// Main closet view with category shelves and FAB

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Binding var searchText: String
    @Binding var selectedTab: Int
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @State private var viewMode: ViewMode = .items
    
    enum ViewMode: String, CaseIterable {
        case items = "Items"
        case outfits = "Outfits"
    }

    // Computed property to check if the wardrobe is truly empty (no items in any category)
    private var isWardrobeEmpty: Bool {
        categories.allSatisfy { $0.items.isEmpty }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PoshTheme.Colors.canvas.ignoresSafeArea()
            
            if !hasCompletedOnboarding && isWardrobeEmpty {
                WelcomeOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                VStack(spacing: 0) {
                    // Segmented Picker
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.white)
                    
                    if viewMode == .items {
                         itemsView
                    } else {
                         outfitsView
                    }
                }
            }
        }
    }
    
    private var itemsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Your Closet")
                         .poshHeadline(size: 24)
                    Spacer()
                    NavigationLink(destination: SearchView()) {
                        Text("See All")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PoshTheme.Colors.ink)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(PoshTheme.Colors.ink.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)

                ForEach(categories) { category in
                    CategoryShelfView(category: category, selectedTab: $selectedTab)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
    }
    
    private var outfitsView: some View {
        ScrollView {
            if outfits.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
                    Text("NO SAVED LOOKS YET")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundColor(PoshTheme.Colors.ink.opacity(0.6))
                    Text("Visit the Studio to generate and save your favorite outfits.")
                        .poshBody(size: 14)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(0.8)
                    Spacer()
                }
                .frame(height: 400)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(outfits) { outfit in
                        if let imageID = outfit.generatedImageID,
                           let image = ImageStorageService.shared.loadImage(withID: imageID) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Placeholder for detail view
                                }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// Memory-retained EmptyClosetView removed in favor of WelcomeOnboardingView

#Preview {
    NavigationStack {
        HomeView(searchText: .constant(""), selectedTab: .constant(0))
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
