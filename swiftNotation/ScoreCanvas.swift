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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No score loaded")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Open MusicXML File", action: onOpen)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ScoreCanvas(svg: "", onOpen: {})
}
