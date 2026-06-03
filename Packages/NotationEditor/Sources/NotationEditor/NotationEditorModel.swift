// NotationEditorModel.swift
// Observable model for the NotationEditorView.
//
// The concrete renderer is injected via the ScoreRenderer protocol so the
// package never depends on Verovio or any C++ libraries.
//
// Host app usage:
//   let renderer = VerovioRenderer()   // conforms to ScoreRenderer
//   let model    = NotationEditorModel(renderer: renderer)
//   NotationEditorView(model: model)

import SwiftUI
import Combine

@MainActor
public final class NotationEditorModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var svgOutput:    String = ""
    @Published public private(set) var score:        Score?
    @Published public var selection:                 SelectionState = SelectionState()
    @Published public private(set) var statusMessage: String = "Open a MusicXML file to begin."
    @Published public private(set) var isLoading:    Bool = false
    @Published public private(set) var canUndo:      Bool = false
    @Published public private(set) var canRedo:      Bool = false

    /// Renderer scale (10–150, default 40).  Changes trigger a re-render.
    @Published public var zoomScale: Double = 40 {
        didSet {
            let clamped = max(10, min(150, zoomScale))
            if clamped != zoomScale { zoomScale = clamped; return }
            renderer.setOptions("{\"scale\": \(Int(zoomScale))}")
            Task { await rerender() }
        }
    }

    @Published public private(set) var currentFileURL: URL?

    // MARK: - Private

    private let renderer: any ScoreRenderer
    private let importer: any ScoreImporter
    private let mapper   = SVGIDMapper()
    private var idMap:    SVGIDMap?
    private var undoStack: [Score] = []
    private var redoStack: [Score] = []

    // MARK: - Init

    /// - Parameters:
    ///   - renderer: Verovio (or any other) renderer conforming to `ScoreRenderer`.
    ///   - importer: Parser to use when loading MusicXML files.
    ///               Defaults to `MusicXMLImporter` (Foundation-based).
    ///               Pass an `MxMusicXMLImporter` from the host app for full mx-backed parsing.
    public init(renderer: any ScoreRenderer, importer: (any ScoreImporter)? = nil) {
        self.renderer = renderer
        self.importer = importer ?? MusicXMLImporter()
    }

    // MARK: - New score

    public func createNewScore(config: NewScoreConfig) {
        let divisions = 4   // ticks per quarter note
        var attrs = MeasureAttributes()
        attrs.divisions    = divisions
        attrs.keyFifths    = config.keyFifths
        attrs.keyMode      = config.keyMode
        attrs.timeBeats    = config.timeBeats
        attrs.timeBeatType = config.timeBeatType
        attrs.clef         = config.clef

        // Full-measure rest duration: beats × (4 ticks/quarter) × (4 quarters/whole) ÷ beatType
        let measureDuration = (config.timeBeats * 16) / config.timeBeatType

        var measures: [Measure] = []
        for i in 1...max(1, config.measureCount) {
            var m = Measure(number: i)
            if i == 1 { m.attributes = attrs }
            m.elements = [.rest(Rest(duration: measureDuration, voice: 1, staff: 1, isFullMeasure: true))]
            measures.append(m)
        }

        var part = Part(xmlID: "P1")
        part.name = config.partName.isEmpty ? nil : config.partName
        part.measures = measures

        var newScore = Score()
        newScore.title    = config.title.isEmpty    ? nil : config.title
        newScore.composer = config.composer.isEmpty ? nil : config.composer
        newScore.parts    = [part]

        selection.clear()
        undoStack.removeAll(); redoStack.removeAll()
        updateUndoRedoState()
        currentFileURL = nil
        score          = newScore
        statusMessage  = newScore.title ?? "New Score"
        Task { await rerender() }
    }

    // MARK: - File loading

    public func handleImport(_ result: Result<[URL], Error>) {
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
        selection.clear()
        undoStack.removeAll(); redoStack.removeAll()
        updateUndoRedoState()
        currentFileURL = url
        statusMessage  = "Loading \(url.lastPathComponent)…"

        do {
            let xml = try await readXMLFile(at: url)

            // Parse and re-export on a background thread so the main thread stays
            // responsive.  Both MusicXMLImporter and MusicXMLExporter are pure
            // value-type operations with no UI dependencies.
            let imp = importer   // capture value/reference for detached task
            let (parsedScore, xmlWithIDs): (Score, String) =
                try await Task.detached(priority: .userInitiated) {
                    let s = try imp.importScore(from: xml)
                    let x = MusicXMLExporter().exportScore(s)
                    return (s, x)
                }.value

            statusMessage = "Rendering…"
            renderer.setOptions("{\"scale\": \(Int(zoomScale))}")
            try await renderer.load(musicXML: xmlWithIDs)
            let svg = try await renderAllPages()

            score     = parsedScore
            idMap     = mapper.buildMap(from: parsedScore)
            svgOutput = svg
            statusMessage = url.lastPathComponent
        } catch {
            statusMessage  = "Error: \(error.localizedDescription)"
            svgOutput = ""; score = nil; idMap = nil; currentFileURL = nil
        }

        isLoading = false
    }

    // MARK: - Save

    public func save() {
        if let url = currentFileURL { writeScore(to: url) }
        else                        { saveAs() }
    }

    public func saveAs() {
        guard let score else { return }
        let xml   = MusicXMLExporter().exportScore(score)
        #if os(macOS)
        let panel = NSSavePanel()
        panel.title                = "Save MusicXML"
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "score.musicxml"
        panel.allowedContentTypes  = [.xml]
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.currentFileURL = url
            self?.writeScore(to: url, xml: xml)
        }
        #endif
    }

    private func writeScore(to url: URL, xml: String? = nil) {
        guard let score else { return }
        let content = xml ?? MusicXMLExporter().exportScore(score)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Saved to \(url.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Selection

    public func selectElement(svgID: String) {
        guard let map = idMap else { return }
        let element: SelectedElement?
        if let modelElement = map.table[svgID] {
            switch modelElement {
            case .note(let n): element = .note(n)
            case .rest(let r): element = .rest(r)
            }
        } else {
            element = nil
        }
        Task { @MainActor [weak self] in self?.selection.element = element }
    }

    public func clearSelection() {
        Task { @MainActor [weak self] in self?.selection.clear() }
    }

    // MARK: - Editing


    public func convertRestToNote(pitch: Pitch = Pitch(step: .c, octave: 4)) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.convertRestToNote(svgID: svgID, pitch: pitch, in: current)
        else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func deleteSelection() {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.delete(svgID: svgID, from: current) else { return }
        applyEdit(updated, clearingSelection: true)
    }

    public func transposeSelection(semitones: Int) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.transpose(svgID: svgID, semitones: semitones, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func setSelectionNoteType(_ type: NoteType) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.setNoteType(type, forSvgID: svgID, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func setSelectionPitch(_ pitch: Pitch) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.setPitch(pitch, forSvgID: svgID, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func setSelectionAccidental(_ alter: Double?) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.setAccidental(alter, svgID: svgID, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func setBarlineForSelection(_ barline: Barline?) {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.setBarline(barline, forMeasureContaining: svgID, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func toggleDotOnSelection() {
        guard let svgID = selection.svgID, let current = score else { return }
        guard let updated = ScoreEditor.toggleDot(svgID: svgID, in: current) else { return }
        applyEdit(updated, clearingSelection: false)
    }

    public func selectNext() {
        guard let current = score else { return }
        selectAdjacent(in: current, forward: true)
    }

    public func selectPrevious() {
        guard let current = score else { return }
        selectAdjacent(in: current, forward: false)
    }

    // MARK: - Undo / Redo

    public func undo() {
        guard let prev = undoStack.popLast(), let current = score else { return }
        redoStack.append(current)
        applyScoreChange(prev, clearingSelection: true)
    }

    public func redo() {
        guard let next = redoStack.popLast(), let current = score else { return }
        undoStack.append(current)
        applyScoreChange(next, clearingSelection: true)
    }

    // MARK: - Re-render

    public func rerender() async {
        guard let score else { return }
        isLoading = true
        do {
            let xml = MusicXMLExporter().exportScore(score)
            try await renderer.load(musicXML: xml)
            let svg  = try await renderAllPages()
            idMap    = mapper.buildMap(from: score)
            svgOutput = svg
        } catch {
            statusMessage = "Render error: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Private helpers

    private func renderAllPages() async throws -> String {
        let count = await renderer.pageCount
        var pages: [String] = []
        for page in 1...max(1, count) {
            let svg = try await renderer.renderPage(page)
            pages.append("<div class=\"score-page\">\(svg)</div>")
        }
        return pages.joined(separator: "\n")
    }

    private func applyEdit(_ newScore: Score, clearingSelection: Bool) {
        guard let current = score else { return }
        undoStack.append(current)
        redoStack.removeAll()
        applyScoreChange(newScore, clearingSelection: clearingSelection)
    }

    private func applyScoreChange(_ newScore: Score, clearingSelection: Bool) {
        let previousSvgID = selection.svgID
        if clearingSelection { selection.clear() }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.score = newScore
            self.updateUndoRedoState()
            await self.rerender()
            if !clearingSelection, let svgID = previousSvgID {
                self.selectElement(svgID: svgID)
            }
        }
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func selectAdjacent(in score: Score, forward: Bool) {
        var ids: [String] = []
        for part in score.parts {
            for measure in part.measures {
                for element in measure.elements {
                    switch element {
                    case .note(let n): ids.append(n.svgID)
                    case .rest(let r): ids.append(r.svgID)
                    default: break
                    }
                }
            }
        }
        guard !ids.isEmpty else { return }
        if let currentID = selection.svgID, let idx = ids.firstIndex(of: currentID) {
            let nextIdx = forward ? idx + 1 : idx - 1
            guard nextIdx >= 0 && nextIdx < ids.count else { return }
            selectElement(svgID: ids[nextIdx])
        } else {
            selectElement(svgID: forward ? ids[0] : ids[ids.count - 1])
        }
    }

    private func readXMLFile(at url: URL) async throws -> String {
        let path = url
        return try await Task.detached(priority: .userInitiated) {
            let accessed = path.startAccessingSecurityScopedResource()
            defer { if accessed { path.stopAccessingSecurityScopedResource() } }
            return try String(contentsOf: path, encoding: .utf8)
        }.value
    }
}
