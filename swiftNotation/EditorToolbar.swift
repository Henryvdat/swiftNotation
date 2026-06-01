// EditorToolbar.swift
// Top toolbar: file open button, loading indicator, status text.

import SwiftUI

struct EditorToolbar: View {
    let isLoading: Bool
    let statusMessage: String
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                Label("Open Score…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            // Mirror the ⌘O shortcut registered on ScoreCanvas's empty-state button
            // so it works regardless of which view has focus.
            .keyboardShortcut("o", modifiers: .command)

            // Animate the spinner in/out so it doesn't pop abruptly.
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
                    .transition(.opacity)
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("swiftNotation")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.default, value: isLoading)
    }
}

// MARK: - Previews

#Preview("Idle") {
    EditorToolbar(isLoading: false, statusMessage: "sample.musicxml", onOpen: {})
}

#Preview("Loading") {
    EditorToolbar(isLoading: true, statusMessage: "Rendering…", onOpen: {})
}
