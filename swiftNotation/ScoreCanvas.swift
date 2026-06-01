// ScoreCanvas.swift
// Displays rendered SVG notation, or an empty-state prompt when no score is loaded.

import SwiftUI

struct ScoreCanvas: View {
    let svg: String
    let onOpen: () -> Void

    var body: some View {
        if svg.isEmpty {
            emptyState
        } else {
            ScoreWebView(svg: svg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No score loaded")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Open MusicXML File…", action: onOpen)
                .buttonStyle(.bordered)
                .keyboardShortcut("o", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Empty state") {
    ScoreCanvas(svg: "", onOpen: {})
        .frame(width: 600, height: 400)
}
