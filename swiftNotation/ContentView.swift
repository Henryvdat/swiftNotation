// ContentView.swift
// Root view: toolbar + score display.
// All rendering state is owned by RendererModel; file I/O is async/await.

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var renderer = RendererModel()
    @State private var svgOutput: String = ""
    @State private var statusMessage: String = "Open a MusicXML file to begin."
    @State private var isLoading: Bool = false
    @State private var showFileImporter: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(
                isLoading: isLoading,
                statusMessage: statusMessage,
                onOpen: { showFileImporter = true }
            )
            Divider()
            ScoreCanvas(svg: svgOutput, onOpen: { showFileImporter = true })
        }
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "musicxml") ?? .xml, .xml],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
    }

    // MARK: - File handling

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            statusMessage = "Error: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await loadScore(from: url) }
        }
    }

    @MainActor
    private func loadScore(from url: URL) async {
        isLoading = true
        statusMessage = "Loading \(url.lastPathComponent)…"

        do {
            let xml = try await readFile(at: url)
            statusMessage = "Rendering…"
            try await renderer.verovio.load(musicXML: xml)
            let svg = try await renderer.verovio.renderPage(1)
            svgOutput = svg
            statusMessage = url.lastPathComponent
        } catch {
            statusMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func readFile(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            return try String(contentsOf: url, encoding: .utf8)
        }.value
    }
}

#Preview {
    ContentView()
}
