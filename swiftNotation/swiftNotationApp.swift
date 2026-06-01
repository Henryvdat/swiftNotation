// swiftNotationApp.swift

import SwiftUI

@main
struct swiftNotationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1024, height: 768)
        .commands {
            CommandGroup(replacing: .newItem) { }   // remove New menu item (not needed yet)
        }
    }
}
