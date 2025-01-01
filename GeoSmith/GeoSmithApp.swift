//
//  geoJSONEditorApp.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/16/24.
//

import SwiftUI
import SwiftData

@main
struct GeoSmithApp: App {
    @Environment(\.openWindow) var openWindow
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1512 * 0.9, height: 982 * 0.9)
        .commands {
            // Add File menu commands
            CommandGroup(after: .newItem) {
                Button("Import GeoJSON...") {
                    // TODO: Implement import
                }
                .keyboardShortcut("i", modifiers: [.command])
                
                Button("Export GeoJSON...") {
                    // TODO: Implement export
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
            
            // Add Help menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About GeoSmith") {
                    openWindow(id: "about")
                }
            }
            
            // Remove unnecessary command groups
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
        }
        
        WindowGroup("About GeoSmith", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 300, height: 250)
    }
    
}
