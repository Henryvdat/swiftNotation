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
                Label("Open Score", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
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
    }
}

#Preview {
    EditorToolbar(isLoading: false, statusMessage: "sample.musicxml", onOpen: {})
}
