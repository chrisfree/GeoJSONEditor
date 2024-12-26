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
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        // These defaults assume a retina display MBP. Not exactly ideal.
        .defaultSize(width: 1512 * 0.9, height: 982 * 0.9)
    }
}
