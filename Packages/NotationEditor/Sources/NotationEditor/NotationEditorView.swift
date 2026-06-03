// NotationEditorView.swift
// Top-level SwiftUI view for the notation editor.
//
// Host app usage:
//
//   import NotationEditor
//
//   struct ContentView: View {
//       @StateObject var model = NotationEditorModel(renderer: VerovioRenderer())
//
//       var body: some View {
//           NotationEditorView(model: model)
//       }
//   }

import SwiftUI
import UniformTypeIdentifiers

public struct NotationEditorView: View {

    @ObservedObject public var model: NotationEditorModel
    @State private var showNewScoreSheet = false
    @State private var showFileImporter  = false
    @State private var showDetailPanel   = true

    public init(model: NotationEditorModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(
                isLoading:        model.isLoading,
                statusMessage:    model.statusMessage,
                hasScore:         model.score != nil,
                showDetailPanel:  $showDetailPanel,
                hasSelection:     model.selection.element != nil,
                canUndo:          model.canUndo,
                canRedo:          model.canRedo,
                zoomScale:        $model.zoomScale,
                onNew:            { showNewScoreSheet = true },
                onOpen:           { showFileImporter = true },
                onSave:           { model.save() },
                onSaveAs:         { model.saveAs() },
                onClearSelection: { model.clearSelection() },
                onUndo:           { model.undo() },
                onRedo:           { model.redo() }
            )
            Divider()

            HStack(spacing: 0) {
                ScoreCanvas(
                    svg:        model.svgOutput,
                    selectedID: model.selection.svgID,
                    onOpen:     { showFileImporter = true },
                    onSelect:   { svgID in
                        if svgID.isEmpty { model.clearSelection() }
                        else             { model.selectElement(svgID: svgID); showDetailPanel = true }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showDetailPanel {
                    Divider()
                    NoteDetailView(
                        selection:           model.selection,
                        onTranspose:         { model.transposeSelection(semitones: $0) },
                        onSetNoteType:       { model.setSelectionNoteType($0) },
                        onToggleDot:         { model.toggleDotOnSelection() },
                        onSetAccidental:     { model.setSelectionAccidental($0) },
                        onDelete:            { model.deleteSelection() },
                        onConvertRestToNote: { pitch in model.convertRestToNote(pitch: pitch) },
                        onSetBarline:        { model.setBarlineForSelection($0) }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress(.delete)        { model.deleteSelection(); return .handled }
        .onKeyPress(.deleteForward) { model.deleteSelection(); return .handled }
        .onKeyPress(.escape)        { model.clearSelection();  return .handled }
        .onKeyPress(.leftArrow,  phases: .down) { _ in
            model.selectPrevious(); showDetailPanel = true; return .handled
        }
        .onKeyPress(.rightArrow, phases: .down) { _ in
            model.selectNext();     showDetailPanel = true; return .handled
        }
        .onKeyPress(.upArrow,   phases: .down) { press in
            model.transposeSelection(semitones: press.modifiers.contains(.option) ? 12 : 1)
            return .handled
        }
        .onKeyPress(.downArrow, phases: .down) { press in
            model.transposeSelection(semitones: press.modifiers.contains(.option) ? -12 : -1)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456."), phases: .down) { press in
            let map: [Character: NoteType] = [
                "1": .whole, "2": .half, "3": .quarter,
                "4": .eighth, "5": .sixteenth, "6": .thirtySecond
            ]
            if let key = press.characters.first {
                if let type = map[key] { model.setSelectionNoteType(type); return .handled }
                if key == "." { model.toggleDotOnSelection(); return .handled }
            }
            return .ignored
        }
        .fileImporter(
            isPresented:             $showFileImporter,
            allowedContentTypes:     [.musicXML, .xml],
            allowsMultipleSelection: false,
            onCompletion:            model.handleImport
        )
        .sheet(isPresented: $showNewScoreSheet) {
            NewScoreSheet(isPresented: $showNewScoreSheet) { config in
                model.createNewScore(config: config)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDetailPanel)
    }
}
