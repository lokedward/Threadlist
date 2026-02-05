// SearchView.swift
// Global search across all items

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ClothingItem]
    
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newest
    @State private var filterCategory: Category?
    @State private var showingFilters = false
    
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    
    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case name = "Name A-Z"
    }
    
    private var filteredItems: [ClothingItem] {
        var items = allItems
        
        // Apply search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            items = items.filter { item in
                item.name.lowercased().contains(search) ||
                (item.brand?.lowercased().contains(search) ?? false) ||
                item.tags.contains { $0.lowercased().contains(search) }
            }
        }
        
        // Apply category filter
        if let category = filterCategory {
            items = items.filter { $0.category?.id == category.id }
        }
        
        // Apply sort
        switch sortOrder {
        case .newest:
            items.sort { $0.dateAdded > $1.dateAdded }
        case .oldest:
            items.sort { $0.dateAdded < $1.dateAdded }
        case .name:
            items.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        return items
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Bar
                HStack(spacing: 12) {
                    // Sort Picker
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(sortOrder.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PoshTheme.Colors.cardBackground)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 3)
                    }
                    
                    // Category Filter
                    Menu {
                        Button {
                            filterCategory = nil
                        } label: {
                            HStack {
                                Text("All Categories")
                                if filterCategory == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Divider()
                        
                        ForEach(categories) { category in
                            Button {
                                filterCategory = category
                            } label: {
                                HStack {
                                    Text(category.name)
                                    if filterCategory?.id == category.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 10, weight: .bold))
                            Text((filterCategory?.name ?? "ALL").uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(filterCategory != nil ? PoshTheme.Colors.primaryGradient : AnyLinearGradient(PoshTheme.Colors.cardBackground))
                        .foregroundColor(filterCategory != nil ? .white : PoshTheme.Colors.secondaryAccent)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 3)
                    }
                    
                    Spacer()
                    
                    Text("\(filteredItems.count) ITEMS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Results
                if filteredItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            Text(searchText.isEmpty ? "CLEAN SLATE" : "NO MATCHES FOUND")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                                .foregroundColor(PoshTheme.Colors.secondaryAccent)
                            
                            Text(searchText.isEmpty ? "Start typing to explore your collection" : "Try refining your search terms")
                                .poshBody(size: 14)
                                .opacity(0.6)
                        }
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    ItemThumbnailView(item: item, size: .large)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    .refreshable {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SEARCH COLLECTION")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
            }
        }
        .searchable(text: $searchText, prompt: "Name, brand, or tag")
    }
}

// Helper to make Menu background conditional easier
struct AnyLinearGradient: ShapeStyle {
    let colors: [Color]
    
    init(_ color: Color) {
        self.colors = [color, color]
    }
    
    func resolve(in proxy: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
