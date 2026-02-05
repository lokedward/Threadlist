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
                    // In a production app with a backend, this would trigger a data sync
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                }
            }
            
            // Floating Action Button
            Button {
                showingAddItem = true
            } label: {
                Image(systemName: "plus")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }
}

struct EmptyClosetView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tshirt")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Your closet is empty")
                .font(.title2.weight(.medium))
                .foregroundColor(.secondary)
            
            Text("Tap the + button to add your first item")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
            
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
