// swiftNotationApp.swift

import SwiftUI

@main
struct SwiftNotationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1024, height: 768)
        .commands {
            // "New" is not applicable to a single-document score viewer.
            CommandGroup(replacing: .newItem) { }
        }
    }
}
