// ContentView.swift
// Root view with navigation structure

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PoshTheme.Colors.background.ignoresSafeArea()
                
                HomeView(searchText: $searchText, showingAddItem: $showingAddItem)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PoshHeader(title: "ThreadList")
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(PoshTheme.Colors.secondaryAccent)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            StylistView()
                        } label: {
                            Image(systemName: "hanger")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(PoshTheme.Colors.secondaryAccent)
                        }
                        
                        NavigationLink {
                            SearchView()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(PoshTheme.Colors.secondaryAccent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
