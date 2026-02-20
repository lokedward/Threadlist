// ThreadListApp.swift
// Main entry point for the ThreadList iOS app

import SwiftUI
import SwiftData
// import GoogleSignIn

@main
struct ThreadListApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClothingItem.self,
            Category.self,
            Outfit.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Seed default categories on first launch
            Task { @MainActor in
                try? ClosetDataService.shared.seedInitialData(context: container.mainContext)
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        /*
        // Restore previous Google Sign-In state
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Google Sign-In restore failed: \(error.localizedDescription)")
            }
        }
        */
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                /*
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                */
        }
        .modelContainer(sharedModelContainer)
    }
}
