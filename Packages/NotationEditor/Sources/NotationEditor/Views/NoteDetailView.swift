// Selection/NoteDetailView.swift
// Inspector + editor panel for the selected note or rest.

import SwiftUI

public struct NoteDetailView: View {
    public let selection:           SelectionState
    public let onTranspose:         (Int) -> Void
    public let onSetNoteType:       (NoteType) -> Void
    public let onToggleDot:         () -> Void
    public let onSetAccidental:     (Double?) -> Void
    public let onDelete:            () -> Void
    public let onConvertRestToNote: (Pitch) -> Void
    public let onSetBarline: (Barline?) -> Void

    // Local state for the "Add Note" pitch picker (rests only)
    @State private var pitchStep:   PitchStep = .c
    @State private var pitchOctave: Int = 4
    @State private var pitchAlter:  Double? = nil

    private var selectedPitch: Pitch {
        Pitch(step: pitchStep, octave: pitchOctave, alter: pitchAlter)
    }

    public init(
        selection: SelectionState,
        onTranspose: @escaping (Int) -> Void,
        onSetNoteType: @escaping (NoteType) -> Void,
        onToggleDot: @escaping () -> Void = {},
        onSetAccidental: @escaping (Double?) -> Void = { _ in },
        onDelete: @escaping () -> Void,
        onConvertRestToNote: @escaping (Pitch) -> Void = { _ in },
        onSetBarline: @escaping (Barline?) -> Void = { _ in }
    ) {
        self.selection           = selection
        self.onTranspose         = onTranspose
        self.onSetNoteType       = onSetNoteType
        self.onToggleDot         = onToggleDot
        self.onSetAccidental     = onSetAccidental
        self.onDelete            = onDelete
        self.onConvertRestToNote = onConvertRestToNote
        self.onSetBarline        = onSetBarline
    }

    public var body: some View {
        Group {
            if let element = selection.element {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            switch element {
                            case .note(let note): noteContent(note)
                            case .rest(let rest): restContent(rest)
                            }
                        }
                        .padding(16)
                    }

                    Divider()
                    editingToolbar(element: element)
                }
            } else {
                emptyState
            }
        }
        .frame(width: 220)
        .background(.background)
    }

    // MARK: - Note content

    @ViewBuilder
    private func noteContent(_ note: Note) -> some View {
        sectionHeader("Note")
        row("Pitch",    note.pitch.displayName)
        row("MIDI",     "\(note.pitch.midiPitch)")
        row("Duration", durationString(type: note.type, dots: note.dots, duration: note.duration))
        row("Voice",    "\(note.voice)")
        row("Staff",    "\(note.staff)")
        if let tie = note.tie         { row("Tie",        tie == .start ? "start" : "stop") }
        if let acc = note.accidental  { row("Accidental", acc.rawValue) }
        if let stem = note.stem       { row("Stem",       stemString(stem)) }

        if !note.notations.isEmpty {
            sectionHeader("Notations")
            ForEach(note.notations.indices, id: \.self) {
                row("", notationString(note.notations[$0]))
            }
        }
        if !note.lyrics.isEmpty {
            sectionHeader("Lyrics")
            ForEach(note.lyrics.indices, id: \.self) {
                row(note.lyrics[$0].number, note.lyrics[$0].text)
            }
        }
    }

    // MARK: - Rest content

    @ViewBuilder
    private func restContent(_ rest: Rest) -> some View {
        sectionHeader("Rest")
        row("Duration", durationString(type: rest.type, dots: rest.dots, duration: rest.duration))
        row("Voice",    "\(rest.voice)")
        row("Staff",    "\(rest.staff)")
        if rest.isFullMeasure { row("", "Full measure") }
    }

    // MARK: - Editing toolbar

    @ViewBuilder
    private func editingToolbar(element: SelectedElement) -> some View {
        // The currently active alteration — note's pitch.alter, or the rest picker's local state
        let activeAlter: Double? = {
            if case .note(let n) = element { return n.pitch.alter }
            return pitchAlter
        }()

        VStack(spacing: 6) {

            // Transpose (notes only)
            if case .note = element {
                HStack(spacing: 2) {
                    fillButton("↓8ve", help: "Octave down (⌥↓)")   { onTranspose(-12) }
                    fillButton("↓",    help: "Semitone down (↓)")   { onTranspose(-1)  }
                    fillButton("↑",    help: "Semitone up (↑)")     { onTranspose(1)   }
                    fillButton("↑8ve", help: "Octave up (⌥↑)")      { onTranspose(12)  }
                }
            }

            // Step picker (rests only — the pitch to insert)
            if case .rest = element {
                HStack(spacing: 2) {
                    ForEach(PitchStep.allCases, id: \.self) { step in
                        fillButton(step.rawValue, help: step.rawValue) { pitchStep = step }
                            .tint(pitchStep == step ? .blue : nil)
                    }
                }
            }

            // Accidentals — always visible
            // For notes: sets pitch.alter.  For rests: updates local pitchAlter state.
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    fillButton("♭", help: "Flat") {
                        if case .note = element { onSetAccidental(-1.0) } else { pitchAlter = -1.0 }
                    }
                    .tint(activeAlter == -1.0 ? .blue : nil)

                    fillButton("♮", help: "Natural") {
                        if case .note = element { onSetAccidental(nil) } else { pitchAlter = nil }
                    }
                    .tint((activeAlter == nil || activeAlter == 0) ? .blue : nil)

                    fillButton("♯", help: "Sharp") {
                        if case .note = element { onSetAccidental(1.0) } else { pitchAlter = 1.0 }
                    }
                    .tint(activeAlter == 1.0 ? .blue : nil)
                }
                .frame(maxWidth: .infinity)

                // Octave stepper lives in the accidental row for rests
                if case .rest = element {
                    HStack(spacing: 3) {
                        Button("−") { pitchOctave = max(0, pitchOctave - 1) }
                            .font(.system(size: 11, weight: .medium))
                            .frame(minWidth: 22, minHeight: 22)
                            .buttonStyle(.bordered)
                            .help("Octave down")
                        Text("\(pitchOctave)")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 16, alignment: .center)
                        Button("+") { pitchOctave = min(9, pitchOctave + 1) }
                            .font(.system(size: 11, weight: .medium))
                            .frame(minWidth: 22, minHeight: 22)
                            .buttonStyle(.bordered)
                            .help("Octave up")
                    }
                }
            }

            // Duration (always) + dot toggle at the end
            HStack(spacing: 2) {
                ForEach(editableDurations, id: \.self) { type in
                    fillButton(durationSymbol(type), help: type.rawValue) { onSetNoteType(type) }
                        .opacity(isCurrentType(element: element, type: type) ? 1 : 0.5)
                }
                fillButton("·", help: "Toggle dotted (.)") { onToggleDot() }
                    .font(.system(size: 14, weight: .bold))
                    .opacity(isDotted(element: element) ? 1 : 0.35)
            }

            Divider()

            // Add Note (rests only)
            if case .rest = element {
                Button(action: { onConvertRestToNote(selectedPitch) }) {
                    Label("Add \(selectedPitch.displayName)", systemImage: "music.note")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            // Delete (notes only)
            if case .note = element {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Note", systemImage: "trash")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Divider()

            // Barline (always — applies to the measure containing the selected element)
            Text("BARLINE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            HStack(spacing: 2) {
                fillButton("|",    help: "Regular (single) barline")   { onSetBarline(nil) }
                fillButton("‖",    help: "Double barline")              { onSetBarline(Barline(location: .right, style: .lightLight)) }
                fillButton("‖|",   help: "Final barline")               { onSetBarline(Barline(location: .right, style: .lightHeavy)) }
                fillButton("| |",  help: "Heavy barline")               { onSetBarline(Barline(location: .right, style: .heavy)) }
            }
            HStack(spacing: 2) {
                fillButton("⋯",    help: "Dotted barline")              { onSetBarline(Barline(location: .right, style: .dotted)) }
                fillButton("╌",    help: "Dashed barline")              { onSetBarline(Barline(location: .right, style: .dashed)) }
                fillButton(":|",   help: "Backward repeat (end)")       { onSetBarline(Barline(location: .right, style: .lightHeavy, repeatDirection: .backward)) }
                fillButton("|:",   help: "Forward repeat (start)")      { onSetBarline(Barline(location: .left, style: .heavyLight, repeatDirection: .forward)) }
            }
        }
        .padding(12)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Click a note to\ninspect and edit it")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Reusable components

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
            }
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 2)
        Divider()
    }

    /// Button that expands to fill equal share of available horizontal space.
    @ViewBuilder
    private func fillButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.bordered)
        .help(help)
    }

    // MARK: - Formatting helpers

    private func durationString(type: NoteType?, dots: Int, duration: Int) -> String {
        var s = type?.rawValue ?? "\(duration) div."
        if dots > 0 { s += String(repeating: ".", count: dots) }
        return s
    }

    private func stemString(_ stem: StemDirection) -> String {
        switch stem {
        case .up: return "up"; case .down: return "down"
        case .noStem: return "none"; case .doubleStem: return "double"
        }
    }

    private func notationString(_ notation: Notation) -> String {
        switch notation {
        case .tied(let k):              return "tie \(k == .start ? "start" : "stop")"
        case .slur(let n, let k):       return "slur \(n) \(k == .start ? "start" : "stop")"
        case .fermata:                  return "fermata"
        case .accent:                   return "accent"
        case .strongAccent:             return "marcato"
        case .tenuto:                   return "tenuto"
        case .staccato:                 return "staccato"
        case .staccatissimo:            return "staccatissimo"
        case .stress:                   return "stress"
        case .unstress:                 return "unstress"
        case .trill:                    return "trill"
        case .turn:                     return "turn"
        case .mordent:                  return "mordent"
        case .invertedMordent:          return "inverted mordent"
        case .invertedTurn:             return "inverted turn"
        case .arpeggiate(let d):        return d == nil ? "arpeggio" : "arpeggio \(d! == .up ? "↑" : "↓")"
        case .technicalFingering(let n): return "fingering \(n)"
        }
    }

    private let editableDurations: [NoteType] = [
        .whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond
    ]

    private func durationSymbol(_ type: NoteType) -> String {
        switch type {
        case .whole:        return "𝅝"
        case .half:         return "𝅗𝅥"
        case .quarter:      return "♩"
        case .eighth:       return "♪"
        case .sixteenth:    return "𝅘𝅥𝅯"
        case .thirtySecond: return "𝅘𝅥𝅰"
        default:            return type.rawValue
        }
    }

    private func isCurrentType(element: SelectedElement, type: NoteType) -> Bool {
        switch element {
        case .note(let n): return n.type == type
        case .rest(let r): return r.type == type
        }
    }

    private func isDotted(element: SelectedElement) -> Bool {
        switch element {
        case .note(let n): return n.dots > 0
        case .rest(let r): return r.dots > 0
        }
    }
}

// MARK: - Preview

#Preview("Note selected") {
    let note = Note(
        pitch: Pitch(step: .c, octave: 5, alter: 1.0),
        duration: 1, type: .quarter,
        notations: [.accent, .slur(number: 1, kind: .start)]
    )
    NoteDetailView(
        selection: SelectionState(element: .note(note)),
        onTranspose: { _ in }, onSetNoteType: { _ in }, onDelete: {}
    )
    .frame(height: 500)
}

#Preview("Rest selected") {
    let rest = Rest(duration: 4, type: .quarter, voice: 1, staff: 1)
    NoteDetailView(
        selection: SelectionState(element: .rest(rest)),
        onTranspose: { _ in }, onSetNoteType: { _ in }, onDelete: {}
    )
    .frame(height: 500)
}
