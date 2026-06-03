// Editing/ScoreEditor.swift
// Pure functions for mutating the Score model.
//
// Every function takes a Score value and returns an Optional<Score>.
// nil means the operation was a no-op (e.g. the svgID wasn't found).
// Returning a new value rather than mutating in place makes undo trivial:
// the caller just pushes the old score onto a stack.

import Foundation

// MARK: - Score path

/// Location of an element within the score hierarchy.
public struct ScorePath: Equatable {
    public let partIndex:    Int
    public let measureIndex: Int
    public let elementIndex: Int
}

// MARK: - Editor

public enum ScoreEditor {

    // MARK: - Path lookup

    /// Find the path to the element with the given svgID.
    public static func path(forSvgID svgID: String, in score: Score) -> ScorePath? {
        for (pi, part) in score.parts.enumerated() {
            for (mi, measure) in part.measures.enumerated() {
                for (ei, element) in measure.elements.enumerated() {
                    switch element {
                    case .note(let n) where n.svgID == svgID:
                        return ScorePath(partIndex: pi, measureIndex: mi, elementIndex: ei)
                    case .rest(let r) where r.svgID == svgID:
                        return ScorePath(partIndex: pi, measureIndex: mi, elementIndex: ei)
                    default:
                        break
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Delete

    /// Replace the selected note with a rest of the same duration, or remove
    /// a single note from a chord (converting to a solo note if only one remains).
    /// Returns nil if svgID not found.
    public static func delete(svgID: String, from score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]

        switch element {
        case .note(let n):
            // Replace the note with a rest of identical duration/voice/staff.
            let rest = Rest(duration: n.duration, type: n.type, dots: n.dots,
                            voice: n.voice, staff: n.staff)
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .rest(rest)

        case .rest:
            // Deleting a rest is a no-op — silences can't be removed without
            // disrupting measure duration.  Return nil so the caller knows.
            return nil


        default:
            return nil
        }

        return result
    }

    // MARK: - Transpose

    /// Move the note at `svgID` by the given number of semitones.
    public static func transpose(svgID: String, semitones: Int, in score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score

        func transposedNote(_ note: Note, by semitones: Int) -> Note {
            var n = note
            n.pitch = note.pitch.transposed(by: semitones)
            n.accidental = nil   // clear notated accidental; re-derive at Stage 5+
            return n
        }

        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]
        switch element {
        case .note(let n):
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] =
                .note(transposedNote(n, by: semitones))

        default:
            return nil
        }

        return result
    }

    // MARK: - Set note type (duration symbol)

    /// Change the visual note type (whole, half, quarter…).
    /// Does NOT adjust the `duration` in divisions — that would require
    /// rebalancing the measure, which is a Stage 6 concern.
    public static func setNoteType(_ type: NoteType, forSvgID svgID: String, in score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]

        // Only 8th-note duration and smaller can carry beam groups.
        let canBeam = type.canBeam

        func updatedNote(_ note: Note) -> Note {
            var n = note
            n.type  = type
            n.dots  = 0
            if !canBeam { n.beams = [] }
            return n
        }
        func updatedRest(_ rest: Rest) -> Rest {
            var r = rest; r.type = type; r.dots = 0; return r
        }

        switch element {
        case .note(let n):
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] =
                .note(updatedNote(n))
        case .rest(let r):
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] =
                .rest(updatedRest(r))

        default:
            return nil
        }

        return result
    }

    // MARK: - Set pitch

    /// Directly set the pitch of the note at `svgID`.
    public static func setPitch(_ pitch: Pitch, forSvgID svgID: String, in score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]

        switch element {
        case .note(let n):
            var updated = n; updated.pitch = pitch; updated.accidental = nil
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .note(updated)

        default:
            return nil
        }

        return result
    }

    // MARK: - Convert rest to note

    /// Replace the rest at `svgID` with a note of the given pitch, using the
    /// rest's current type as the note duration.  Any remaining time in the
    /// rest is filled with one or more properly-typed rests so the measure
    /// stays rhythmically complete and further notes can be entered.
    ///
    /// If the rest has no type set (e.g. a full-measure rest before any
    /// duration has been chosen), a quarter note is assumed.
    public static func convertRestToNote(
        svgID: String,
        pitch: Pitch = Pitch(step: .c, octave: 4),
        in score: Score
    ) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]
        guard case .rest(let r) = element else { return nil }

        let divisions = findDivisions(partIndex: p.partIndex, measureIndex: p.measureIndex, in: score)
        let noteType  = r.type ?? .quarter
        let noteDots  = r.type != nil ? r.dots : 0
        let noteTicks = min(tickDuration(for: noteType, dots: noteDots, divisions: divisions),
                            r.duration)

        guard noteTicks > 0 else { return nil }

        let note = Note(
            pitch:    pitch,
            duration: noteTicks,
            type:     noteType,
            dots:     noteDots,
            voice:    r.voice,
            staff:    r.staff
        )

        result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .note(note)

        // Fill any remaining time with decomposed rests so the measure stays complete.
        let remaining = r.duration - noteTicks
        if remaining > 0 {
            let tail = fillRests(duration: remaining, voice: r.voice, staff: r.staff, divisions: divisions)
            result.parts[p.partIndex].measures[p.measureIndex].elements
                .insert(contentsOf: tail, at: p.elementIndex + 1)
        }

        return result
    }

    // MARK: - Duration helpers

    /// Number of ticks for a note type with the given dot count, given the
    /// measure's divisions (ticks per quarter note).
    public static func tickDuration(for type: NoteType, dots: Int, divisions: Int) -> Int {
        var ticks    = type.relativeDuration * Double(divisions)
        var dotValue = ticks / 2.0
        for _ in 0..<max(0, dots) { ticks += dotValue; dotValue /= 2.0 }
        return Int(ticks.rounded())
    }

    /// Walk backward from `measureIndex` to find the most recent `divisions` setting.
    private static func findDivisions(partIndex: Int, measureIndex: Int, in score: Score) -> Int {
        guard partIndex < score.parts.count else { return 4 }
        let measures = score.parts[partIndex].measures
        for mi in stride(from: min(measureIndex, measures.count - 1), through: 0, by: -1) {
            if let div = measures[mi].attributes?.divisions, div > 0 { return div }
        }
        return 4
    }

    /// Decompose `duration` ticks into the fewest properly-typed rests,
    /// using a greedy largest-first algorithm (dotted values tried before plain).
    private static func fillRests(duration: Int, voice: Int, staff: Int, divisions: Int) -> [MusicElement] {
        let types: [NoteType] = [.whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond, .sixtyFourth]
        var remaining = duration
        var result: [MusicElement] = []
        while remaining > 0 {
            var placed = false
            outerLoop: for type_ in types {
                for dots in [1, 0] {
                    let d = tickDuration(for: type_, dots: dots, divisions: divisions)
                    if d > 0 && d <= remaining {
                        result.append(.rest(Rest(duration: d, type: type_, dots: dots, voice: voice, staff: staff)))
                        remaining -= d
                        placed = true
                        break outerLoop
                    }
                }
            }
            if !placed { break }
        }
        return result
    }

    // MARK: - Toggle dot

    /// Toggle the augmentation dot on the note or rest at `svgID`.
    public static func toggleDot(svgID: String, in score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]
        switch element {
        case .note(let n):
            var updated = n; updated.dots = n.dots > 0 ? 0 : 1
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .note(updated)
        case .rest(let r):
            var updated = r; updated.dots = r.dots > 0 ? 0 : 1
            result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .rest(updated)
        default:
            return nil
        }
        return result
    }

    // MARK: - Set barline

    /// Set or remove an explicit barline on the measure containing `svgID`.
    /// Pass `nil` to revert the measure's right barline to the implicit single barline.
    /// Providing a `Barline` with `location: .left` sets the left (forward-repeat) barline;
    /// all other values set the right barline.
    public static func setBarline(
        _ barline: Barline?,
        forMeasureContaining svgID: String,
        in score: Score
    ) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let targetLocation: BarlineLocation = barline?.location ?? .right

        // Remove any existing explicit barline at that location.
        result.parts[p.partIndex].measures[p.measureIndex].elements.removeAll {
            if case .barline(let b) = $0, b.location == targetLocation { return true }
            return false
        }

        if let barline {
            result.parts[p.partIndex].measures[p.measureIndex].elements.append(.barline(barline))
        }

        return result
    }

    // MARK: - Set accidental

    /// Change only the `alter` component of the note at `svgID`, keeping step and octave.
    /// Pass `nil` for natural. Returns nil if the element is not a note.
    public static func setAccidental(_ alter: Double?, svgID: String, in score: Score) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]
        guard case .note(let n) = element else { return nil }
        var updated = n
        updated.pitch = Pitch(step: n.pitch.step, octave: n.pitch.octave, alter: alter)
        // Set the explicit accidental element so Verovio always renders the symbol.
        // For natural: only emit the natural sign if the note was previously altered so
        // the sign cancels a prior sharp/flat in the same measure.
        switch alter {
        case 1.0:  updated.accidental = .sharp
        case -1.0: updated.accidental = .flat
        case nil:
            let wasAltered = n.pitch.alter != nil && n.pitch.alter != 0
            updated.accidental = wasAltered ? .natural : nil
        default:
            updated.accidental = nil
        }
        result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .note(updated)
        return result
    }

}