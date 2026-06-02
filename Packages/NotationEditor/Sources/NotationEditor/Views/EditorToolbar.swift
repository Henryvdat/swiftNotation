// EditorToolbar.swift
// Top toolbar: open, save, undo/redo, zoom, loading indicator, inspector toggle.

import SwiftUI

public struct EditorToolbar: View {
    public let isLoading:      Bool
    public let statusMessage:  String
    public let hasScore:       Bool
    @Binding public var showDetailPanel: Bool
    public let hasSelection:   Bool
    public let canUndo:        Bool
    public let canRedo:        Bool
    @Binding public var zoomScale: Double
    public let onOpen:         () -> Void
    public let onSave:         () -> Void
    public let onSaveAs:       () -> Void
    public let onClearSelection: () -> Void
    public let onUndo:         () -> Void
    public let onRedo:         () -> Void

    public init(isLoading: Bool, statusMessage: String, hasScore: Bool,
                showDetailPanel: Binding<Bool>, hasSelection: Bool,
                canUndo: Bool, canRedo: Bool, zoomScale: Binding<Double>,
                onOpen: @escaping () -> Void, onSave: @escaping () -> Void,
                onSaveAs: @escaping () -> Void, onClearSelection: @escaping () -> Void,
                onUndo: @escaping () -> Void, onRedo: @escaping () -> Void) {
        self.isLoading = isLoading; self.statusMessage = statusMessage
        self.hasScore = hasScore; self._showDetailPanel = showDetailPanel
        self.hasSelection = hasSelection; self.canUndo = canUndo; self.canRedo = canRedo
        self._zoomScale = zoomScale; self.onOpen = onOpen; self.onSave = onSave
        self.onSaveAs = onSaveAs; self.onClearSelection = onClearSelection
        self.onUndo = onUndo; self.onRedo = onRedo
    }


    public var body: some View {
        HStack(spacing: 8) {
            // Open
            Button(action: onOpen) {
                Label("Open…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: .command)

            // Save
            Button(action: onSave) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!hasScore)
            .help("Save (⌘S)")
            .keyboardShortcut("s", modifiers: .command)

            Divider().frame(height: 20)

            // Undo / Redo
            Button(action: onUndo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!canUndo)
            .help("Undo (⌘Z)")

            Button(action: onRedo) {
                Label("Redo", systemImage: "arrow.uturn.forward")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!canRedo)
            .help("Redo (⌘⇧Z)")

            Divider().frame(height: 20)

            // Loading indicator
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
                    .transition(.opacity)
            }

            // Status
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Zoom
            HStack(spacing: 4) {
                Button { zoomScale = max(10,  zoomScale - 10) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Zoom out")
                .disabled(!hasScore)

                Text("\(Int(zoomScale))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)

                Button { zoomScale = min(150, zoomScale + 10) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Zoom in")
                .disabled(!hasScore)
            }

            Divider().frame(height: 20)

            // Clear selection
            if hasSelection {
                Button(action: onClearSelection) {
                    Label("Clear", systemImage: "xmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Clear selection (Escape)")
                .transition(.opacity)
            }

            // Inspector toggle
            Button { showDetailPanel.toggle() } label: {
                Label("Inspector", systemImage: "sidebar.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(showDetailPanel ? "Hide inspector" : "Show inspector")
            .keyboardShortcut("i", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.default, value: isLoading)
        .animation(.default, value: hasSelection)
    }
}

#Preview {
    EditorToolbar(
        isLoading: false, statusMessage: "sample.musicxml", hasScore: true,
        showDetailPanel: .constant(true),
        hasSelection: true, canUndo: true, canRedo: false,
        zoomScale: .constant(40),
        onOpen: {}, onSave: {}, onSaveAs: {},
        onClearSelection: {}, onUndo: {}, onRedo: {}
    )
}
