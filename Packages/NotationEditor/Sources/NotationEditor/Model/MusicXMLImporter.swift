// Model/MusicXMLImporter.swift
// Parses a MusicXML 4 string into the internal Swift model.
//
// Uses Foundation's XMLDocument (tree-based, macOS only).
//
// Swift 6 / Xcode 26 note:
//   SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor makes Foundation's XMLDocument
//   and XMLElement methods implicitly @MainActor, so this importer runs on the
//   main actor.  Parsing is fast CPU-only work, but for very large scores a
//   future improvement is to switch to XMLParser (SAX, nonisolated) and deliver
//   the completed Score back via continuation.  Tracked in PLAN.md Stage 6.
//
// Namespace note:
//   XPath predicates silently return nil when the document uses a default XML
//   namespace (xmlns="…"), which some notation apps add.  If files from Sibelius
//   or Finale fail to import, namespace stripping or manual traversal will be
//   needed.  Tracked in PLAN.md Stage 6.

import Foundation

// MARK: - Error

public enum ImportError: LocalizedError {
    case invalidEncoding
    case malformedXML(String)
    case missingRootElement

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:         return "XML string is not valid UTF-8"
        case .malformedXML(let msg):   return "Malformed XML: \(msg)"
        case .missingRootElement:      return "Could not find <score-partwise> root element"
        }
    }
}

// MARK: - Internal parse result

/// Typed result of parsing a single `<note>` element.
/// Replaces the old 4-tuple `(Note?, Bool, Rest?, Direction?)` which had 2⁴
/// possible nil-combinations, only a few of which were valid.
private enum NoteParseResult {
    case note(Note, isChord: Bool)
    case rest(Rest)
    case ignored
}

// MARK: - Importer

/// Converts a raw MusicXML string to a `Score` value.
public struct MusicXMLImporter {

    // MARK: - Public entry point

    public func importScore(from xml: String) throws -> Score {
        // Strip any default XML namespace (e.g. xmlns="http://...") from the root element
        // before parsing.  Sibelius and Finale exports often include one, and Foundation's
        // XPath predicates silently return nil for documents with a default namespace.
        let strippedXML = xml.replacingOccurrences(
            of: #"\s+xmlns\s*=\s*"[^"]*""#,
            with: "",
            options: .regularExpression
        )

        guard let data = strippedXML.data(using: .utf8) else { throw ImportError.invalidEncoding }

        let doc: XMLDocument
        do {
            doc = try XMLDocument(data: data, options: [.nodePreserveWhitespace])
        } catch {
            throw ImportError.malformedXML(error.localizedDescription)
        }

        guard let root = doc.rootElement() else { throw ImportError.missingRootElement }

        let rootName = root.name ?? ""
        guard rootName == "score-partwise" || rootName == "score-timewise" else {
            throw ImportError.missingRootElement
        }

        var score = Score()
        score.title    = root.stringValue(forXPath: "work/work-title")
                      ?? root.stringValue(forXPath: "movement-title")
        score.composer = root.stringValue(forXPath: "identification/creator[@type='composer']")

        let partMeta = parsePartList(root)

        for partEl in root.childElements(forName: "part") {
            if let part = parsePart(partEl, meta: partMeta) {
                score.parts.append(part)
            }
        }

        return score
    }

    // MARK: - Part list

    private func parsePartList(
        _ root: XMLElement
    ) -> [String: (name: String?, abbr: String?)] {
        var map: [String: (String?, String?)] = [:]
        for sp in root.elements(forXPath: "part-list/score-part") ?? [] {
            guard let xmlID = sp.attribute(forName: "id")?.stringValue else { continue }
            let name = sp.stringValue(forXPath: "part-name")
            let abbr = sp.stringValue(forXPath: "part-abbreviation")
            map[xmlID] = (name, abbr)
        }
        return map
    }

    // MARK: - Part

    private func parsePart(
        _ el: XMLElement,
        meta: [String: (name: String?, abbr: String?)]
    ) -> Part? {
        guard let xmlID = el.attribute(forName: "id")?.stringValue else { return nil }
        var part = Part(xmlID: xmlID)
        part.name         = meta[xmlID]?.name
        part.abbreviation = meta[xmlID]?.abbr

        var currentAttributes = MeasureAttributes()

        for measureEl in el.childElements(forName: "measure") {
            if let measure = parseMeasure(measureEl, attributes: &currentAttributes) {
                part.measures.append(measure)
            }
        }

        return part
    }

    // MARK: - Measure

    private func parseMeasure(
        _ el: XMLElement,
        attributes: inout MeasureAttributes
    ) -> Measure? {
        let number = Int(el.attribute(forName: "number")?.stringValue ?? "0") ?? 0
        var measure = Measure(number: number)

        for child in el.children ?? [] {
            guard let childEl = child as? XMLElement else { continue }
            switch childEl.name ?? "" {
            case "attributes":
                parseAttributes(childEl, into: &attributes)
                measure.attributes = attributes

            case "note":
                switch parseNoteElement(childEl) {
                case .note(let note, isChord: let isChord):
                    var n = note
                    n.isChordTone = isChord
                    measure.elements.append(.note(n))

                case .rest(let rest):
                    measure.elements.append(.rest(rest))

                case .ignored:
                    break
                }

            case "barline":
                if let barline = parseBarline(childEl) {
                    measure.elements.append(MusicElement.barline(barline))
                }

            case "direction":
                if let dir = parseDirection(childEl) {
                    measure.elements.append(MusicElement.direction(dir))
                }

            default:
                break
            }
        }

        return measure
    }

    // MARK: - Attributes

    private func parseAttributes(_ el: XMLElement, into attrs: inout MeasureAttributes) {
        if let v = el.intValue(forXPath: "divisions")      { attrs.divisions    = v }
        if let v = el.intValue(forXPath: "key/fifths")     { attrs.keyFifths    = v }
        if let v = el.stringValue(forXPath: "key/mode")    { attrs.keyMode      = KeyMode(rawValue: v) }
        if let v = el.intValue(forXPath: "time/beats")     { attrs.timeBeats    = v }
        if let v = el.intValue(forXPath: "time/beat-type") { attrs.timeBeatType = v }
        if let v = el.intValue(forXPath: "staves")         { attrs.staves       = v }

        if let clefEl = (el.elements(forXPath: "clef") ?? []).first {
            attrs.clef = parseClef(clefEl)
        }
    }

    private func parseClef(_ el: XMLElement) -> Clef? {
        let sign = el.stringValue(forXPath: "sign") ?? ""
        let line = el.intValue(forXPath: "line")
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

    // MARK: - Note element

    private func parseNoteElement(_ el: XMLElement) -> NoteParseResult {
        let isChord = !el.childElements(forName: "chord").isEmpty
        let isRest  = !el.childElements(forName: "rest").isEmpty
        let isGrace = !el.childElements(forName: "grace").isEmpty
        let duration = el.intValue(forXPath: "duration") ?? 0
        let voice    = el.intValue(forXPath: "voice")    ?? 1
        let staff    = el.intValue(forXPath: "staff")    ?? 1
        let noteType = el.stringValue(forXPath: "type").flatMap { NoteType(rawValue: $0) }
        let dots     = (el.elements(forXPath: "dot") ?? []).count

        if isRest {
            let restEl = el.childElements(forName: "rest").first
            let isFull = restEl?.attribute(forName: "measure")?.stringValue == "yes"
            let rest   = Rest(duration: duration, type: noteType, dots: dots,
                              voice: voice, staff: staff, isFullMeasure: isFull)
            // svgID is now a computed property derived from rest.id — no assignment needed.
            return .rest(rest)
        }

        guard let pitchEl = el.childElements(forName: "pitch").first,
              let stepStr = pitchEl.stringValue(forXPath: "step"),
              let step    = PitchStep(rawValue: stepStr),
              let octave  = pitchEl.intValue(forXPath: "octave")
        else {
            return .ignored
        }

        let pitch = Pitch(step: step, octave: octave, alter: pitchEl.doubleValue(forXPath: "alter"))

        var tie: TieKind?
        if let tieEl = el.childElements(forName: "tie").first {
            tie = TieKind(rawValue: tieEl.attribute(forName: "type")?.stringValue ?? "")
        }

        var stem: StemDirection?
        if let stemStr = el.stringValue(forXPath: "stem") {
            switch stemStr {
            case "up":     stem = .up
            case "down":   stem = .down
            case "none":   stem = .noStem
            case "double": stem = .doubleStem
            default:       break
            }
        }

        let beams: [Beam] = (el.elements(forXPath: "beam") ?? []).compactMap { beamEl in
            let num = Int(beamEl.attribute(forName: "number")?.stringValue ?? "1") ?? 1
            guard let val = BeamValue(rawValue: beamEl.stringValue ?? "") else { return nil }
            return Beam(number: num, value: val)
        }

        let notations: [Notation] = el.childElements(forName: "notations").first
            .map { parseNotations($0) } ?? []

        let lyrics: [Lyric] = el.childElements(forName: "lyric").compactMap { parseLyric($0) }

        let note = Note(
            pitch: pitch,
            duration: duration,
            type: noteType,
            dots: dots,
            voice: voice,
            staff: staff,
            tie: tie,
            accidental: el.stringValue(forXPath: "accidental").flatMap { Accidental(rawValue: $0) },
            stem: stem,
            beams: beams,
            notations: notations,
            lyrics: lyrics
        )
        // svgID is now a computed property derived from note.id — no assignment needed.
        _ = isGrace   // grace notes parsed but duration is 0; handle in Stage 5

        return .note(note, isChord: isChord)
    }

    // MARK: - Notations

    private func parseNotations(_ el: XMLElement) -> [Notation] {
        var result: [Notation] = []

        for child in el.children ?? [] {
            guard let childEl = child as? XMLElement else { continue }
            switch childEl.name ?? "" {
            case "tied":
                if let t = TieKind(rawValue: childEl.attribute(forName: "type")?.stringValue ?? "") {
                    result.append(.tied(t))
                }
            case "slur":
                let num = Int(childEl.attribute(forName: "number")?.stringValue ?? "1") ?? 1
                if let k = SlurKind(rawValue: childEl.attribute(forName: "type")?.stringValue ?? "") {
                    result.append(.slur(number: num, kind: k))
                }
            case "fermata":
                result.append(.fermata)
            case "articulations":
                for artChild in childEl.children ?? [] {
                    guard let artEl = artChild as? XMLElement else { continue }
                    switch artEl.name ?? "" {
                    case "accent":          result.append(.accent)
                    case "strong-accent":   result.append(.strongAccent)
                    case "tenuto":          result.append(.tenuto)
                    case "staccato":        result.append(.staccato)
                    case "staccatissimo":   result.append(.staccatissimo)
                    case "stress":          result.append(.stress)
                    case "unstress":        result.append(.unstress)
                    default:                break
                    }
                }
            case "ornaments":
                for ornChild in childEl.children ?? [] {
                    guard let ornEl = ornChild as? XMLElement else { continue }
                    switch ornEl.name ?? "" {
                    case "trill-mark":       result.append(.trill)
                    case "turn":             result.append(.turn)
                    case "mordent":          result.append(.mordent)
                    case "inverted-mordent": result.append(.invertedMordent)
                    case "inverted-turn":    result.append(.invertedTurn)
                    default:                 break
                    }
                }
            case "technical":
                for techChild in childEl.children ?? [] {
                    guard let techEl = techChild as? XMLElement else { continue }
                    if techEl.name == "fingering", let n = Int(techEl.stringValue ?? "") {
                        result.append(.technicalFingering(n))
                    }
                }
            case "arpeggiate":
                let arpDir: ArpDirection?
                switch childEl.attribute(forName: "direction")?.stringValue {
                case "up":   arpDir = .up
                case "down": arpDir = .down
                default:     arpDir = nil
                }
                result.append(.arpeggiate(arpDir))
            default:
                break
            }
        }
        return result
    }

    // MARK: - Lyric

    private func parseLyric(_ el: XMLElement) -> Lyric? {
        guard let text = el.stringValue(forXPath: "text") else { return nil }
        // MusicXML lyric number is a string — can be "1" or named e.g. "verse".
        let number   = el.attribute(forName: "number")?.stringValue ?? "1"
        let syllabic = el.stringValue(forXPath: "syllabic").flatMap { SyllabicKind(rawValue: $0) }
        return Lyric(number: number, text: text, syllabic: syllabic)
    }

    // MARK: - Barline

    private func parseBarline(_ el: XMLElement) -> Barline? {
        let location     = BarlineLocation(rawValue: el.attribute(forName: "location")?.stringValue ?? "right") ?? .right
        let style        = BarlineStyle(rawValue: el.stringValue(forXPath: "bar-style") ?? "regular") ?? .regular
        var barline      = Barline(location: location, style: style)

        if let repEl = el.childElements(forName: "repeat").first {
            barline.repeatDirection = RepeatDirection(rawValue:
                repEl.attribute(forName: "direction")?.stringValue ?? "")
        }

        return barline
    }

    // MARK: - Direction

    private func parseDirection(_ el: XMLElement) -> Direction? {
        let placement: DirectionPlacement?
        switch el.attribute(forName: "placement")?.stringValue {
        case "above": placement = .above
        case "below": placement = .below
        default:      placement = nil
        }

        var direction = Direction(placement: placement)
        direction.staff  = el.intValue(forXPath: "staff")
        direction.offset = el.intValue(forXPath: "offset")

        for dtChild in el.childElements(forName: "direction-type") {
            for child in dtChild.children ?? [] {
                guard let childEl = child as? XMLElement else { continue }
                switch childEl.name ?? "" {
                case "dynamics":
                    for dynChild in childEl.children ?? [] {
                        if let name = (dynChild as? XMLElement)?.name {
                            direction.types.append(.dynamic(name))
                        }
                    }
                case "metronome":
                    let beat = childEl.stringValue(forXPath: "beat-unit").flatMap { NoteType(rawValue: $0) }
                    let bpm  = childEl.intValue(forXPath: "per-minute")
                    direction.types.append(.metronome(beat: beat, perMinute: bpm))
                case "words":
                    if let text = childEl.stringValue { direction.types.append(.words(text)) }
                case "rehearsal":
                    if let text = childEl.stringValue { direction.types.append(.rehearsal(text)) }
                case "wedge":
                    let wk: WedgeKind
                    switch childEl.attribute(forName: "type")?.stringValue {
                    case "crescendo":  wk = .crescendo
                    case "diminuendo": wk = .diminuendo
                    default:           wk = .stop
                    }
                    direction.types.append(.wedge(wk))
                case "segno": direction.types.append(.segno)
                case "coda":  direction.types.append(.coda)
                case "pedal":
                    let pk: PedalKind
                    switch childEl.attribute(forName: "type")?.stringValue {
                    case "stop":       pk = .stop
                    case "change":     pk = .change
                    case "sostenuto":  pk = .sostenuto
                    default:           pk = .start
                    }
                    direction.types.append(.pedal(pk))
                default: break
                }
            }
        }

        // <sound tempo="120"/> may appear directly inside <direction>
        if let soundEl = el.childElements(forName: "sound").first,
           let tempoStr = soundEl.attribute(forName: "tempo")?.stringValue,
           let tempoDouble = Double(tempoStr) {
            direction.types.append(.tempo(Int(tempoDouble)))
        }

        return direction.types.isEmpty ? nil : direction
    }
}

// MARK: - TieKind / SlurKind from string

private extension TieKind {
    init?(rawValue: String) {
        switch rawValue {
        case "start": self = .start
        case "stop":  self = .stop
        default:      return nil
        }
    }
}

private extension SlurKind {
    init?(rawValue: String) {
        switch rawValue {
        case "start": self = .start
        case "stop":  self = .stop
        default:      return nil
        }
    }
}

// MARK: - XMLElement helpers

private extension XMLElement {

    /// Direct child elements with the given element name.
    /// Faster than XPath for structural navigation.
    func childElements(forName name: String) -> [XMLElement] {
        children?.compactMap { $0 as? XMLElement }.filter { $0.name == name } ?? []
    }

    func stringValue(forXPath xpath: String) -> String? {
        (try? nodes(forXPath: xpath))?.first?.stringValue
    }

    func intValue(forXPath xpath: String) -> Int? {
        stringValue(forXPath: xpath).flatMap { Int($0) }
    }

    func doubleValue(forXPath xpath: String) -> Double? {
        stringValue(forXPath: xpath).flatMap { Double($0) }
    }

    func elements(forXPath xpath: String) -> [XMLElement]? {
        (try? nodes(forXPath: xpath))?.compactMap { $0 as? XMLElement }
    }
}
