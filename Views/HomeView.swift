// HomeView.swift
// Main closet view with category shelves and FAB

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Binding var searchText: String
    @Binding var showingAddItem: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Persistent Branding Header with subtle tint
            PoshHeader()
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(PoshTheme.Colors.stone) // Subtle "Stone" tint for depth
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(PoshTheme.Colors.border), alignment: .bottom)
            
            ZStack(alignment: .bottomTrailing) {
                if categories.isEmpty {
                    EmptyClosetView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(categories) { category in
                                if !category.items.isEmpty {
                                    CategoryShelfView(category: category)
                                }
                            }
                            
                            // Show empty state if all categories are empty
                            if categories.allSatisfy({ $0.items.isEmpty }) {
                                EmptyClosetView()
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        // Simulate a refresh delay to show the spinning animation
                        try? await Task.sleep(nanoseconds: 800_000_000)
                    }
                }
            }
        }
    }
}

struct EmptyClosetView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tshirt")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(PoshTheme.Colors.ink.opacity(0.3))
            
            Text("Your closet is empty")
                .poshHeadline(size: 20)
            
            Text("Tap the + button to add your first item")
                .poshBody(size: 14)
                .opacity(0.7)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    NavigationStack {
        HomeView(searchText: .constant(""), showingAddItem: .constant(false))
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
