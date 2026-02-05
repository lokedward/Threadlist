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
        VStack(spacing: 0) {
            // Filter Bar
            HStack {
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
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOrder.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
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
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(filterCategory?.name ?? "All")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(filterCategory != nil ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                    .foregroundColor(filterCategory != nil ? .accentColor : .primary)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Results
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    if searchText.isEmpty {
                        Text("No items yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No results for \"\(searchText)\"")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemThumbnailView(item: item, size: .large)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    // Simulate a refresh delay
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Name, brand, or tag")
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
