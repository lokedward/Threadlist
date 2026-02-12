// ContentView.swift
// Root view with navigation structure

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    init() {
        // 2.2. Style the Tab Bar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground() // Translucent/Transparent
        appearance.backgroundColor = UIColor(white: 1.0, alpha: 0.8) // Fixed White

        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial) // Frosted glass effect
        
        // Remove top border/shadow for a cleaner look
        appearance.shadowColor = .clear
        
        // Item colors
        // Manually defining UIColors to avoid SwiftUI bridging issues in init
        let ink = PoshTheme.Colors.uiInk
        let unselectedInk = PoshTheme.Colors.uiInk.withAlphaComponent(0.3)
        
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
        TabView(selection: $selectedTab) {
            // Tab 1: Wardrobe
            NavigationStack {
                HomeView(searchText: $searchText)
                    .navigationTitle("Wardrobe")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
                Text("Wardrobe")
            }
            .tag(0)
            
            // Tab 2: Curate (Action)
            AddItemView()
                .tabItem {
                    Image(systemName: "plus")
                    Text("Curate")
                }
                .tag(1)
            
            // Tab 3: Studio
            NavigationStack {
                StylistView()
                    .navigationTitle("Studio")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Studio")
            }
            .tag(2)
            
            // Tab 4: Account
            NavigationStack {
                SettingsView()
                    .navigationTitle("Account")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Account")
            }
            .tag(3)
        }
        .tint(PoshTheme.Colors.ink) // Selected color
        .preferredColorScheme(.light) // Enforce Light Mode globally
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
