// ContentView.swift
// Root view: toolbar + score display.
// All rendering state is owned by RendererModel.

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var model = RendererModel()
    @State private var showFileImporter = false

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(
                isLoading: model.isLoading,
                statusMessage: model.statusMessage,
                onOpen: { showFileImporter = true }
            )
            Divider()
            ScoreCanvas(svg: model.svgOutput, onOpen: { showFileImporter = true })
        }
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.musicXML, .xml],
            allowsMultipleSelection: false,
            onCompletion: model.handleImport
        )
    }
}

#Preview {
    ContentView()
}
