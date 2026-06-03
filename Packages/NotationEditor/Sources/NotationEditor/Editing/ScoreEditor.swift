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

    /// Replace the rest at `svgID` with a note of the given pitch.
    /// Duration, dots, voice, and staff are preserved from the rest.
    /// Returns nil if svgID is not found or the element is not a rest.
    public static func convertRestToNote(
        svgID: String,
        pitch: Pitch = Pitch(step: .c, octave: 4),
        in score: Score
    ) -> Score? {
        guard let p = path(forSvgID: svgID, in: score) else { return nil }
        var result = score
        let element = result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex]
        guard case .rest(let r) = element else { return nil }
        let note = Note(
            pitch:    pitch,
            duration: r.duration,
            type:     r.type,
            dots:     r.dots,
            voice:    r.voice,
            staff:    r.staff
        )
        result.parts[p.partIndex].measures[p.measureIndex].elements[p.elementIndex] = .note(note)
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