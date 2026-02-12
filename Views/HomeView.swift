// HomeView.swift
// Main closet view with category shelves and FAB

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Binding var searchText: String
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(categories) { category in
                            CategoryShelfView(category: category)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
            
            // Floating Action Button
            NavigationLink {
                AddItemView()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(PoshTheme.Colors.ink)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            .padding(24)
        }
    }
}

// Memory-retained EmptyClosetView removed in favor of WelcomeOnboardingView

#Preview {
    NavigationStack {
        HomeView(searchText: .constant(""))
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
