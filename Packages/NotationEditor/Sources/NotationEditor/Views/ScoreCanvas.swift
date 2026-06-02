// ScoreCanvas.swift
// Displays rendered SVG notation, or an empty-state prompt when no score is loaded.

import SwiftUI

public struct ScoreCanvas: View {
    public let svg: String
    public let selectedID: String?
    public let onOpen: () -> Void
    public let onSelect: (String) -> Void

    public init(svg: String, selectedID: String?, onOpen: @escaping () -> Void, onSelect: @escaping (String) -> Void) {
        self.svg = svg; self.selectedID = selectedID; self.onOpen = onOpen; self.onSelect = onSelect
    }

    public var body: some View {
        if svg.isEmpty {
            emptyState
        } else {
            ScoreWebView(svg: svg, selectedID: selectedID, onSelect: onSelect)
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

#Preview("Empty state") {
    ScoreCanvas(svg: "", selectedID: nil, onOpen: {}, onSelect: { _ in })
        .frame(width: 600, height: 400)
}
