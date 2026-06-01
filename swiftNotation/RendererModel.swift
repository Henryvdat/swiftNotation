// RendererModel.swift
// Observable model that owns the Verovio renderer and all score-loading state.
// All published properties are mutated on the MainActor (enforced by the class isolation).

import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class RendererModel: ObservableObject {

    // MARK: - Published state

    /// The SVG string for the currently displayed page, or empty when no score is loaded.
    @Published private(set) var svgOutput: String = ""

    /// Human-readable status shown in the toolbar.
    @Published private(set) var statusMessage: String = "Open a MusicXML file to begin."

    /// True while an async load/render operation is in flight.
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private

    private let verovio = VerovioRenderer()

    // MARK: - File loading

    /// Handle the result from SwiftUI's fileImporter.
    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            statusMessage = "Could not open file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await loadScore(from: url) }
        }
    }

    private func loadScore(from url: URL) async {
        isLoading = true
        statusMessage = "Loading \(url.lastPathComponent)…"

        do {
            let xml = try await readXMLFile(at: url)
            statusMessage = "Rendering…"
            try await verovio.load(musicXML: xml)
            let svg = try await verovio.renderPage(1)
            svgOutput = svg
            statusMessage = url.lastPathComponent
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            // Clear stale output so the empty-state placeholder is shown.
            svgOutput = ""
        }

        isLoading = false
    }

    /// Read a security-scoped file URL on a background thread.
    private func readXMLFile(at url: URL) async throws -> String {
        // Capture the URL value; the detached task runs off the main actor.
        let path = url
        return try await Task.detached(priority: .userInitiated) {
            let accessed = path.startAccessingSecurityScopedResource()
            defer { if accessed { path.stopAccessingSecurityScopedResource() } }
            return try String(contentsOf: path, encoding: .utf8)
        }.value
    }
}
