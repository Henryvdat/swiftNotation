// Model/MusicXMLExporter.swift
// Serialises the internal Swift model back to a MusicXML 4 string.
//
// Output is score-partwise, UTF-8, with the standard MusicXML 4 DOCTYPE.
// The exporter aims for round-trip fidelity on the subset the importer reads.

import Foundation

// MARK: - Exporter

public struct MusicXMLExporter {

    // MARK: - Public entry point

    public func exportScore(_ score: Score) -> String {
        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">"#)
        lines.append(#"<score-partwise version="4.0">"#)

        if let title = score.title {
            lines.append(indent(1, "<work>"))
            lines.append(indent(2, "<work-title>\(escape(title))</work-title>"))
            lines.append(indent(1, "</work>"))
        }

        if let composer = score.composer {
            lines.append(indent(1, "<identification>"))
            lines.append(indent(2, #"<creator type="composer">\#(escape(composer))</creator>"#))
            lines.append(indent(1, "</identification>"))
        }

        lines.append(indent(1, "<part-list>"))
        for part in score.parts {
            lines.append(indent(2, #"<score-part id="\#(escape(part.xmlID))">"#))
            if let name = part.name {
                lines.append(indent(3, "<part-name>\(escape(name))</part-name>"))
            }
            if let abbr = part.abbreviation {
                lines.append(indent(3, "<part-abbreviation>\(escape(abbr))</part-abbreviation>"))
            }
            lines.append(indent(2, "</score-part>"))
        }
        lines.append(indent(1, "</part-list>"))

        for part in score.parts {
            lines.append(indent(1, #"<part id="\#(escape(part.xmlID))">"#))
            var runningDivisions = 4
            for measure in part.measures {
                if let d = measure.attributes?.divisions, d > 0 { runningDivisions = d }
                lines += exportMeasure(measure, indent: 2, divisions: runningDivisions)
            }
            lines.append(indent(1, "</part>"))
        }

        lines.append("</score-partwise>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Measure

    private func exportMeasure(_ measure: Measure, indent level: Int, divisions: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, #"<measure number="\#(measure.number)">"#))

        if let attrs = measure.attributes {
            lines += exportAttributes(attrs, indent: level + 1)
        }

        let elements = withAutoBeams(measure.elements, divisions: divisions)
        for element in elements {
            switch element {
            case .note(let note):
                lines += exportNote(note, indent: level + 1)
            case .rest(let rest):
                lines += exportRest(rest, indent: level + 1)
            case .barline(let barline):
                lines += exportBarline(barline, indent: level + 1)
            case .direction(let dir):
                lines += exportDirection(dir, indent: level + 1)
            }
        }

        lines.append(indent(level, "</measure>"))
        return lines
    }

    // MARK: - Auto-beaming

    /// Return elements with beam attributes computed for consecutive beamable notes
    /// within the same beat.  Only sets beams on notes whose `beams` array is empty
    /// (i.e. notes entered via the editor rather than imported with explicit beams).
    private func withAutoBeams(_ elements: [MusicElement], divisions: Int) -> [MusicElement] {
        guard divisions > 0 else { return elements }
        let beatTicks = divisions

        struct NoteItem {
            let elemIdx: Int
            let tickStart: Int
            let note: Note
        }

        // Collect beamable notes with their tick positions, skipping chord tones (they share a tick).
        var tick = 0
        var allItems: [NoteItem] = []
        for (i, elem) in elements.enumerated() {
            switch elem {
            case .note(let n) where !n.isChordTone:
                if let type_ = n.type, type_.canBeam {
                    allItems.append(NoteItem(elemIdx: i, tickStart: tick, note: n))
                }
                tick += n.duration
            case .note(let n):
                _ = n  // chord tone — no tick advance
            case .rest(let r):
                tick += r.duration
            default:
                break
            }
        }

        // Group items that are consecutive (no gap) and in the same beat.
        var groups: [[NoteItem]] = []
        var cur: [NoteItem] = []
        for item in allItems {
            let beat = item.tickStart / beatTicks
            if let prev = cur.last {
                let prevEnd  = prev.tickStart + prev.note.duration
                let prevBeat = prev.tickStart / beatTicks
                if prevEnd == item.tickStart && prevBeat == beat {
                    cur.append(item)
                    continue
                }
            }
            if cur.count >= 2 { groups.append(cur) }
            cur = [item]
        }
        if cur.count >= 2 { groups.append(cur) }

        // Build index: elemIdx → (position in group, group)
        var beamMap: [Int: (pos: Int, group: [NoteItem])] = [:]
        for group in groups {
            for (pos, item) in group.enumerated() {
                beamMap[item.elemIdx] = (pos, group)
            }
        }

        // Apply beams.
        var result = elements
        for i in 0..<result.count {
            guard case .note(var n) = result[i], !n.isChordTone else { continue }
            guard n.beams.isEmpty else { continue }  // preserve imported beams
            guard let (pos, group) = beamMap[i] else { continue }

            let isFirst = pos == 0
            let isLast  = pos == group.count - 1

            var newBeams: [Beam] = []

            // Primary beam (eighth-level).
            newBeams.append(Beam(number: 1, value: isFirst ? .begin : isLast ? .end : .continuing))

            // Secondary beam (sixteenth-level) for 16th and smaller notes.
            if let type_ = n.type, type_.relativeDuration <= 0.25 {
                let prevIs16 = pos > 0 && (group[pos - 1].note.type?.relativeDuration ?? 1) <= 0.25
                let nextIs16 = pos < group.count - 1 && (group[pos + 1].note.type?.relativeDuration ?? 1) <= 0.25

                let b2: BeamValue
                if isFirst      { b2 = nextIs16 ? .begin       : .forwardHook  }
                else if isLast  { b2 = prevIs16 ? .end         : .backwardHook }
                else if prevIs16 && nextIs16 { b2 = .continuing }
                else if prevIs16 { b2 = .end }
                else             { b2 = .begin }
                newBeams.append(Beam(number: 2, value: b2))
            }

            n.beams = newBeams
            result[i] = .note(n)
        }
        return result
    }

    // MARK: - Attributes

    private func exportAttributes(_ attrs: MeasureAttributes, indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, "<attributes>"))
        if let div = attrs.divisions {
            lines.append(indent(level + 1, "<divisions>\(div)</divisions>"))
        }
        if let fifths = attrs.keyFifths {
            lines.append(indent(level + 1, "<key>"))
            lines.append(indent(level + 2, "<fifths>\(fifths)</fifths>"))
            if let mode = attrs.keyMode {
                lines.append(indent(level + 2, "<mode>\(mode.rawValue)</mode>"))
            }
            lines.append(indent(level + 1, "</key>"))
        }
        if let beats = attrs.timeBeats, let bt = attrs.timeBeatType {
            lines.append(indent(level + 1, "<time>"))
            lines.append(indent(level + 2, "<beats>\(beats)</beats>"))
            lines.append(indent(level + 2, "<beat-type>\(bt)</beat-type>"))
            lines.append(indent(level + 1, "</time>"))
        }
        if let staves = attrs.staves {
            lines.append(indent(level + 1, "<staves>\(staves)</staves>"))
        }
        if let clef = attrs.clef {
            lines += exportClef(clef, indent: level + 1)
        }
        lines.append(indent(level, "</attributes>"))
        return lines
    }

    private func exportClef(_ clef: Clef, indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, "<clef>"))
        switch clef {
        case .treble:
            lines.append(indent(level + 1, "<sign>G</sign>"))
            lines.append(indent(level + 1, "<line>2</line>"))
        case .bass:
            lines.append(indent(level + 1, "<sign>F</sign>"))
            lines.append(indent(level + 1, "<line>4</line>"))
        case .alto:
            lines.append(indent(level + 1, "<sign>C</sign>"))
            lines.append(indent(level + 1, "<line>3</line>"))
        case .tenor:
            lines.append(indent(level + 1, "<sign>C</sign>"))
            lines.append(indent(level + 1, "<line>4</line>"))
        case .percussion:
            lines.append(indent(level + 1, "<sign>percussion</sign>"))
        case .tab:
            lines.append(indent(level + 1, "<sign>TAB</sign>"))
        case .custom(let sign, let line):
            lines.append(indent(level + 1, "<sign>\(sign)</sign>"))
            if let l = line { lines.append(indent(level + 1, "<line>\(l)</line>")) }
        }
        lines.append(indent(level, "</clef>"))
        return lines
    }

    // MARK: - Note

    private func exportNote(_ note: Note, indent level: Int) -> [String] {
        var lines: [String] = []
        // Write the note's stable svgID as the MusicXML id attribute.
        // Verovio reads this and uses it verbatim as the SVG element id,
        // giving us exact 1:1 model ↔ SVG mapping without order-based heuristics.
        lines.append(indent(level, "<note id=\"\(note.svgID)\">"))
        if note.isChordTone { lines.append(indent(level + 1, "<chord/>")) }

        lines.append(indent(level + 1, "<pitch>"))
        lines.append(indent(level + 2, "<step>\(note.pitch.step.rawValue)</step>"))
        if let alter = note.pitch.alter {
            lines.append(indent(level + 2, "<alter>\(formatDouble(alter))</alter>"))
        }
        lines.append(indent(level + 2, "<octave>\(note.pitch.octave)</octave>"))
        lines.append(indent(level + 1, "</pitch>"))

        lines.append(indent(level + 1, "<duration>\(note.duration)</duration>"))

        if let tie = note.tie {
            lines.append(indent(level + 1, #"<tie type="\#(tieString(tie))"/>"#))
        }

        lines.append(indent(level + 1, "<voice>\(note.voice)</voice>"))

        if let type_ = note.type {
            lines.append(indent(level + 1, "<type>\(type_.rawValue)</type>"))
        }
        for _ in 0 ..< note.dots { lines.append(indent(level + 1, "<dot/>")) }

        if let acc = note.accidental {
            lines.append(indent(level + 1, "<accidental>\(acc.rawValue)</accidental>"))
        }

        if let stem = note.stem {
            let stemStr: String
            switch stem {
            case .up:         stemStr = "up"
            case .down:       stemStr = "down"
            case .noStem:     stemStr = "none"
            case .doubleStem: stemStr = "double"
            }
            lines.append(indent(level + 1, "<stem>\(stemStr)</stem>"))
        }

        lines.append(indent(level + 1, "<staff>\(note.staff)</staff>"))

        for beam in note.beams {
            lines.append(indent(level + 1, #"<beam number="\#(beam.number)">\#(beam.value.rawValue)</beam>"#))
        }

        if !note.notations.isEmpty {
            lines += exportNotations(note.notations, indent: level + 1)
        }

        for lyric in note.lyrics {
            lines += exportLyric(lyric, indent: level + 1)
        }

        lines.append(indent(level, "</note>"))
        return lines
    }

    // MARK: - Rest

    private func exportRest(_ rest: Rest, indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, "<note id=\"\(rest.svgID)\">"))
        lines.append(indent(level + 1, rest.isFullMeasure ? #"<rest measure="yes"/>"# : "<rest/>"))
        lines.append(indent(level + 1, "<duration>\(rest.duration)</duration>"))
        lines.append(indent(level + 1, "<voice>\(rest.voice)</voice>"))
        if let type_ = rest.type {
            lines.append(indent(level + 1, "<type>\(type_.rawValue)</type>"))
        }
        for _ in 0 ..< rest.dots { lines.append(indent(level + 1, "<dot/>")) }
        lines.append(indent(level + 1, "<staff>\(rest.staff)</staff>"))
        lines.append(indent(level, "</note>"))
        return lines
    }

    // MARK: - Notations

    private func exportNotations(_ notations: [Notation], indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, "<notations>"))

        let isArticulation: (Notation) -> Bool = {
            switch $0 {
            case .accent, .strongAccent, .tenuto, .staccato,
                 .staccatissimo, .stress, .unstress: return true
            default: return false
            }
        }
        let articulations = notations.filter(isArticulation)

        for n in notations {
            switch n {
            case .tied(let kind):
                lines.append(indent(level + 1, #"<tied type="\#(tieString(kind))"/>"#))
            case .slur(let num, let kind):
                lines.append(indent(level + 1, #"<slur number="\#(num)" type="\#(slurString(kind))"/>"#))
            case .fermata:
                lines.append(indent(level + 1, "<fermata/>"))
            case .arpeggiate(let dir):
                if let d = dir {
                    lines.append(indent(level + 1, #"<arpeggiate direction="\#(d == .up ? "up" : "down")"/>"#))
                } else {
                    lines.append(indent(level + 1, "<arpeggiate/>"))
                }
            case .trill:
                lines.append(indent(level + 1, "<ornaments><trill-mark/></ornaments>"))
            case .turn:
                lines.append(indent(level + 1, "<ornaments><turn/></ornaments>"))
            case .mordent:
                lines.append(indent(level + 1, "<ornaments><mordent/></ornaments>"))
            case .invertedMordent:
                lines.append(indent(level + 1, "<ornaments><inverted-mordent/></ornaments>"))
            case .invertedTurn:
                lines.append(indent(level + 1, "<ornaments><inverted-turn/></ornaments>"))
            case .technicalFingering(let n):
                lines.append(indent(level + 1, "<technical><fingering>\(n)</fingering></technical>"))
            default:
                break
            }
        }

        if !articulations.isEmpty {
            lines.append(indent(level + 1, "<articulations>"))
            for n in articulations {
                switch n {
                case .accent:        lines.append(indent(level + 2, "<accent/>"))
                case .strongAccent:  lines.append(indent(level + 2, "<strong-accent/>"))
                case .tenuto:        lines.append(indent(level + 2, "<tenuto/>"))
                case .staccato:      lines.append(indent(level + 2, "<staccato/>"))
                case .staccatissimo: lines.append(indent(level + 2, "<staccatissimo/>"))
                case .stress:        lines.append(indent(level + 2, "<stress/>"))
                case .unstress:      lines.append(indent(level + 2, "<unstress/>"))
                default:             break
                }
            }
            lines.append(indent(level + 1, "</articulations>"))
        }

        lines.append(indent(level, "</notations>"))
        return lines
    }

    // MARK: - Lyric

    private func exportLyric(_ lyric: Lyric, indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, #"<lyric number="\#(escape(lyric.number))">"#))
        if let syllabic = lyric.syllabic {
            lines.append(indent(level + 1, "<syllabic>\(syllabic.rawValue)</syllabic>"))
        }
        lines.append(indent(level + 1, "<text>\(escape(lyric.text))</text>"))
        lines.append(indent(level, "</lyric>"))
        return lines
    }

    // MARK: - Barline

    private func exportBarline(_ barline: Barline, indent level: Int) -> [String] {
        var lines: [String] = []
        lines.append(indent(level, #"<barline location="\#(barline.location.rawValue)">"#))
        lines.append(indent(level + 1, "<bar-style>\(barline.style.rawValue)</bar-style>"))
        if let rep = barline.repeatDirection {
            lines.append(indent(level + 1, #"<repeat direction="\#(rep.rawValue)"/>"#))
        }
        lines.append(indent(level, "</barline>"))
        return lines
    }

    // MARK: - Direction

    private func exportDirection(_ dir: Direction, indent level: Int) -> [String] {
        var lines: [String] = []
        var openTag = "<direction"
        if let p = dir.placement {
            openTag += #" placement="\#(p == .above ? "above" : "below")""#
        }
        openTag += ">"
        lines.append(indent(level, openTag))
        lines.append(indent(level + 1, "<direction-type>"))

        for type_ in dir.types {
            switch type_ {
            case .dynamic(let d):
                lines.append(indent(level + 2, "<dynamics><\(d)/></dynamics>"))
            case .tempo(let bpm):
                lines.append(indent(level + 2, #"<sound tempo="\#(bpm)"/>"#))
            case .metronome(let beat, let bpm):
                lines.append(indent(level + 2, "<metronome>"))
                if let b = beat { lines.append(indent(level + 3, "<beat-unit>\(b.rawValue)</beat-unit>")) }
                if let b = bpm  { lines.append(indent(level + 3, "<per-minute>\(b)</per-minute>")) }
                lines.append(indent(level + 2, "</metronome>"))
            case .words(let text):
                lines.append(indent(level + 2, "<words>\(escape(text))</words>"))
            case .rehearsal(let text):
                lines.append(indent(level + 2, "<rehearsal>\(escape(text))</rehearsal>"))
            case .wedge(let kind):
                let t = kind == .crescendo ? "crescendo" : kind == .diminuendo ? "diminuendo" : "stop"
                lines.append(indent(level + 2, #"<wedge type="\#(t)"/>"#))
            case .pedal(let kind):
                let t: String
                switch kind {
                case .start:      t = "start"
                case .stop:       t = "stop"
                case .change:     t = "change"
                case .sostenuto:  t = "sostenuto"
                }
                lines.append(indent(level + 2, #"<pedal type="\#(t)"/>"#))
            case .segno:
                lines.append(indent(level + 2, "<segno/>"))
            case .coda:
                lines.append(indent(level + 2, "<coda/>"))
            case .dashes(let kind):
                lines.append(indent(level + 2, #"<dashes type="\#(kind == .start ? "start" : "stop")"/>"#))
            case .octaveShift(let kind):
                let t = kind == .up ? "up" : kind == .down ? "down" : "stop"
                lines.append(indent(level + 2, #"<octave-shift type="\#(t)"/>"#))
            }
        }

        lines.append(indent(level + 1, "</direction-type>"))
        if let staff = dir.staff   { lines.append(indent(level + 1, "<staff>\(staff)</staff>")) }
        if let offset = dir.offset { lines.append(indent(level + 1, "<offset>\(offset)</offset>")) }
        lines.append(indent(level, "</direction>"))
        return lines
    }

    // MARK: - Helpers

    private func indent(_ level: Int, _ text: String) -> String {
        String(repeating: "  ", count: level) + text
    }

    /// Escapes the five predefined XML entities.
    /// All five are escaped so the output is valid in both element content
    /// and in attribute values regardless of delimiter style.
    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'",  with: "&apos;")
    }

    private func tieString(_ kind: TieKind) -> String {
        kind == .start ? "start" : "stop"
    }

    private func slurString(_ kind: SlurKind) -> String {
        kind == .start ? "start" : "stop"
    }

    /// Formats a Double as an integer string when it has no fractional part.
    private func formatDouble(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}
