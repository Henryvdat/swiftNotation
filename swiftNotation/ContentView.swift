// ContentView.swift
// Thin host-app wrapper — creates a VerovioRenderer and hands it to
// NotationEditorView (from the NotationEditor package).

import SwiftUI
import NotationEditor

struct ContentView: View {

    @StateObject private var model = NotationEditorModel(renderer: VerovioRenderer())

    var body: some View {
        NotationEditorView(model: model)
    }
}

#Preview { ContentView() }
