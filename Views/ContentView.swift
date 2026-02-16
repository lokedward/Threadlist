// ContentView.swift
// Root view with navigation structure

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var preselectedCategory: String? = nil
    
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
        let gold = PoshTheme.Colors.uiGold
        let ink = PoshTheme.Colors.uiInk
        let unselectedInk = PoshTheme.Colors.uiInk.withAlphaComponent(0.3)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselectedInk
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedInk]
        
        itemAppearance.selected.iconColor = gold
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
                HomeView(searchText: $searchText, selectedTab: $selectedTab, preselectedCategory: $preselectedCategory)
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
            AddItemView(preselectedCategoryName: preselectedCategory)
                .tabItem {
                    Image(systemName: "plus")
                    Text("Curate")
                }
                .tag(1)
            
            // Tab 3: Studio
            NavigationStack {
                StylistView()
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Studio")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .tag(3)
        }
        .tint(PoshTheme.Colors.gold) // Selected color
        .preferredColorScheme(.light) // Enforce Light Mode globally
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear preselected category when leaving the Curate tab
            if oldValue == 1 && newValue != 1 {
                preselectedCategory = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
