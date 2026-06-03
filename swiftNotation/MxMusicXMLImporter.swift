// MxMusicXMLImporter.swift
// Converts MxWrapper's transfer objects into the NotationEditor Score model.
// Lives in the app target so it can reference both MxWrapper (ObjC) and
// the NotationEditor package without creating a circular dependency.
//
// Usage:
//   let model = NotationEditorModel(renderer: VerovioRenderer(),
//                                   importer: MxMusicXMLImporter())

import Foundation
import NotationEditor

/// A `ScoreImporter` backed by the mx C++ MusicXML library.
public struct MxMusicXMLImporter: ScoreImporter {

    public init() {}

    public func importScore(from xml: String) throws -> Score {
        // Swift auto-bridges the ObjC `error:(NSError **)` parameter to a
        // throwing Swift method, so we call it with `try` (no error: argument).
        do {
            let transfer = try MxWrapper.parseXML(xml)
            return try buildScore(from: transfer)
        } catch {
            throw MxImportError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - Score

    private func buildScore(from t: MxScoreTransfer) throws -> Score {
        var score = Score()
        score.title    = t.title.flatMap { $0.isEmpty ? nil : $0 }
        score.composer = t.composer.flatMap { $0.isEmpty ? nil : $0 }
        let tpq = Int(t.ticksPerQuarter)
        for partTransfer in t.parts {
            score.parts.append(buildPart(from: partTransfer, ticksPerQuarter: tpq))
        }
        return score
    }

    // MARK: - Part

    private func buildPart(from t: MxPartTransfer, ticksPerQuarter: Int) -> Part {
        var part = Part(xmlID: t.xmlID.isEmpty ? "P1" : t.xmlID)
        part.name         = t.name.flatMap { $0.isEmpty ? nil : $0 }
        part.abbreviation = t.abbreviation.flatMap { $0.isEmpty ? nil : $0 }

        var runningAttributes = MeasureAttributes()
        // Use mx's ticksPerQuarter as divisions so exported round-trip durations are consistent.
        runningAttributes.divisions = ticksPerQuarter

        for measureTransfer in t.measures {
            part.measures.append(buildMeasure(from: measureTransfer,
                                              attributes: &runningAttributes))
        }
        return part
    }

    // MARK: - Measure

    private func buildMeasure(from t: MxMeasureTransfer,
                               attributes: inout MeasureAttributes) -> Measure {
        var measure = Measure(number: Int(t.number))

        if t.hasClef, let clef = parseClef(sign: t.clefSign, line: Int(t.clefLine)) {
            attributes.clef = clef
        }
        if t.hasKey {
            attributes.keyFifths = Int(t.keyFifths)
            attributes.keyMode   = KeyMode(rawValue: t.keyMode) ?? .major
        }
        if t.hasTime {
            attributes.timeBeats    = Int(t.timeBeats)
            attributes.timeBeatType = Int(t.timeBeatType)
        }
        if t.hasClef || t.hasKey || t.hasTime {
            measure.attributes = attributes
        }

        // Notes — use single-letter locals so they never shadow MusicElement cases.
        for n in t.notes {
            if n.isRest {
                let r = Rest(
                    duration:      Int(n.durationTicks),
                    type:          NoteType(rawValue: n.noteType),
                    dots:          Int(n.dots),
                    voice:         n.voice > 0 ? Int(n.voice) : 1,
                    staff:         n.staff > 0 ? Int(n.staff) : 1,
                    isFullMeasure: n.isMeasureRest
                )
                measure.elements.append(MusicElement.rest(r))
            } else {
                guard let step = PitchStep(rawValue: n.step) else { continue }
                let pitch = Pitch(step:   step,
                                  octave: Int(n.octave),
                                  alter:  n.hasAlter ? n.alter : nil)
                let note = Note(
                    pitch:       pitch,
                    duration:    Int(n.durationTicks),
                    type:        NoteType(rawValue: n.noteType),
                    dots:        Int(n.dots),
                    voice:       n.voice > 0 ? Int(n.voice) : 1,
                    staff:       n.staff > 0 ? Int(n.staff) : 1,
                    isChordTone: n.isChord,
                    tie:         parseTie(start: n.isTieStart, stop: n.isTieStop),
                    accidental:  n.accidental.isEmpty ? nil : Accidental(rawValue: n.accidental),
                    stem:        parseStem(n.stemDirection)
                )
                measure.elements.append(MusicElement.note(note))
            }
        }

        // Barlines
        for b in t.barlines {
            let location = BarlineLocation(rawValue: b.location) ?? .right
            let style    = BarlineStyle(rawValue: b.barlineType) ?? .regular
            var bl       = Barline(location: location, style: style)
            if b.isRepeat {
                bl.repeatDirection = RepeatDirection(rawValue: b.repeatDirection)
            }
            measure.elements.append(MusicElement.barline(bl))
        }

        return measure
    }

    // MARK: - Helpers

    private func parseClef(sign: String, line: Int) -> Clef? {
        switch sign {
        case "G":          return .treble
        case "F":          return .bass
        case "C":
            switch line {
            case 3:        return .alto
            case 4:        return .tenor
            default:       return .custom(sign: "C", line: line)
            }
        case "percussion": return .percussion
        case "TAB":        return .tab
        default:           return sign.isEmpty ? nil : .custom(sign: sign, line: line)
        }
    }

    private func parseTie(start: Bool, stop: Bool) -> TieKind? {
        if start { return .start }
        if stop  { return .stop }
        return nil
    }

    private func parseStem(_ s: String) -> StemDirection? {
        switch s {
        case "up":   return .up
        case "down": return .down
        case "none": return .noStem
        default:     return nil
        }
    }
}

// MARK: - Error

public enum MxImportError: LocalizedError {
    case parseFailed(String)
    public var errorDescription: String? {
        if case .parseFailed(let msg) = self { return "mx parse failed: \(msg)" }
        return nil
    }
}
