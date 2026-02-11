// ContentView.swift
// Root view with navigation structure

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var showingAddItem = false
    
    @State private var selectedTab = 0
    @State private var previousTab = 0
    
    init() {
        // 2.2. Style the Tab Bar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground() // Translucent/Transparent
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial) // Frosted glass effect
        
        // Remove top border/shadow for a cleaner look
        appearance.shadowColor = .clear
        
        // Item colors
        let ink = UIColor(PoshTheme.Colors.ink)
        let unselectedInk = UIColor(PoshTheme.Colors.ink.opacity(0.3))
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselectedInk
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedInk]
        
        itemAppearance.selected.iconColor = ink
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: ink]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 1 {
                    // Tab 2 "Curate" - Trigger Add Action
                    showingAddItem = true
                } else {
                    selectedTab = newValue
                    previousTab = newValue
                }
            }
        )) {
            // Tab 1: Wardrobe
            NavigationStack {
                HomeView(searchText: $searchText, showingAddItem: $showingAddItem)
                    .navigationTitle("Wardrobe")
                    .navigationBarTitleDisplayMode(.hidden) // Custom header usually, or standard? Using hidden for now as per "Typography as UI" pivot likely prefers clean headers.
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
                Text("Wardrobe")
            }
            .tag(0)
            
            // Tab 2: Curate (Action)
            Text("") // Dummy view
                .tabItem {
                    Image(systemName: "plus")
                    Text("Curate")
                }
                .tag(1)
            
            // Tab 3: Atelier
            NavigationStack {
                StylistView()
                    .navigationTitle("Atelier")
                    .navigationBarTitleDisplayMode(.hidden)
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Atelier")
            }
            .tag(2)
            
            // Tab 4: Account
            NavigationStack {
                SettingsView()
                    .navigationTitle("Account")
                    .navigationBarTitleDisplayMode(.hidden)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Account")
            }
            .tag(3)
        }
        .accentColor(PoshTheme.Colors.ink) // Selected color
        .fullScreenCover(isPresented: $showingAddItem) {
            AddItemView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
