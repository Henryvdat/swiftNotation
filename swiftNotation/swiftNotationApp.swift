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
            // Remove the system "New" item — single-document viewer.
            CommandGroup(replacing: .newItem) { }

            // Undo / Redo — delegate to the focused window's RendererModel
            // via the standard macOS UndoManager key equivalents.
            // The actual ⌘Z / ⌘⇧Z shortcuts are handled in ContentView via
            // EditorToolbar buttons; these entries keep the Edit menu correct.
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
    }
}
