// Model/ScoreModel.swift
// Internal Swift representation of a MusicXML score.
//
// All types are value types (struct/enum) so mutations copy cleanly and
// undo stacks can snapshot the whole model cheaply.
//
// Architecture rule: UI and renderer both derive from this model.
// Never reach into raw XML or SVG from SwiftUI views.

import Foundation

// MARK: - Top-level score

/// The root of the score hierarchy.
public struct Score: Identifiable, Equatable {
    public let id: UUID
    public var title: String?
    public var composer: String?
    public var parts: [Part]

    public init(id: UUID = UUID(), title: String? = nil, composer: String? = nil, parts: [Part] = []) {
        self.id       = id
        self.title    = title
        self.composer = composer
        self.parts    = parts
    }
}

// MARK: - Part

public struct Part: Identifiable, Equatable {
    public let id: UUID
    /// Matches the MusicXML `id` attribute (e.g. "P1").
    public var xmlID: String
    public var name: String?
    public var abbreviation: String?
    public var measures: [Measure]

    public init(id: UUID = UUID(), xmlID: String, name: String? = nil,
                abbreviation: String? = nil, measures: [Measure] = []) {
        self.id           = id
        self.xmlID        = xmlID
        self.name         = name
        self.abbreviation = abbreviation
        self.measures     = measures
    }
}

// MARK: - Measure

public struct Measure: Identifiable, Equatable {
    public let id: UUID
    public var number: Int
    public var attributes: MeasureAttributes?
    public var elements: [MusicElement]

    public init(id: UUID = UUID(), number: Int, attributes: MeasureAttributes? = nil, elements: [MusicElement] = []) {
        self.id         = id
        self.number     = number
        self.attributes = attributes
        self.elements   = elements
    }
}

public struct MeasureAttributes: Equatable {
    public var divisions: Int?
    public var keyFifths: Int?
    public var keyMode: KeyMode?
    public var timeBeats: Int?
    public var timeBeatType: Int?
    public var clef: Clef?
    public var staves: Int?

    public init(divisions: Int? = nil, keyFifths: Int? = nil, keyMode: KeyMode? = nil,
                timeBeats: Int? = nil, timeBeatType: Int? = nil,
                clef: Clef? = nil, staves: Int? = nil) {
        self.divisions    = divisions
        self.keyFifths    = keyFifths
        self.keyMode      = keyMode
        self.timeBeats    = timeBeats
        self.timeBeatType = timeBeatType
        self.clef         = clef
        self.staves       = staves
    }
}

public enum KeyMode: String, Equatable, Hashable, CaseIterable {
    case major, minor, dorian, phrygian, lydian, mixolydian, aeolian, locrian
    case unknown = "none"
}

public enum Clef: Equatable, Hashable {
    case treble, bass, alto, tenor, percussion, tab
    case custom(sign: String, line: Int?)
}

// MARK: - Music elements

public enum MusicElement: Equatable {
    case note(Note)
    case rest(Rest)
    case barline(Barline)
    case direction(Direction)
}

// MARK: - Note

public struct Note: Identifiable, Equatable {
    public let id: UUID
    /// Verovio SVG element id — derived from `id` so it is always valid.
    public var svgID: String { "n-\(id.uuidString.lowercased())" }

    public var pitch: Pitch
    public var duration: Int
    public var type: NoteType?
    public var dots: Int
    public var voice: Int
    public var staff: Int
    /// True when this note sounds simultaneously with the immediately preceding note.
    /// Matches the MusicXML `<chord/>` child element.
    public var isChordTone: Bool
    public var tie: TieKind?
    public var accidental: Accidental?
    public var stem: StemDirection?
    public var beams: [Beam]
    public var notations: [Notation]
    public var lyrics: [Lyric]

    public init(id: UUID = UUID(), pitch: Pitch, duration: Int, type: NoteType? = nil,
                dots: Int = 0, voice: Int = 1, staff: Int = 1,
                isChordTone: Bool = false,
                tie: TieKind? = nil, accidental: Accidental? = nil,
                stem: StemDirection? = nil, beams: [Beam] = [],
                notations: [Notation] = [], lyrics: [Lyric] = []) {
        self.id          = id
        self.pitch       = pitch
        self.duration    = duration
        self.type        = type
        self.dots        = dots
        self.voice       = voice
        self.staff       = staff
        self.isChordTone = isChordTone
        self.tie         = tie
        self.accidental  = accidental
        self.stem        = stem
        self.beams       = beams
        self.notations   = notations
        self.lyrics      = lyrics
    }
}

// MARK: - Rest

public struct Rest: Identifiable, Equatable {
    public let id: UUID
    public var svgID: String { "r-\(id.uuidString.lowercased())" }
    public var duration: Int
    public var type: NoteType?
    public var dots: Int
    public var voice: Int
    public var staff: Int
    public var isFullMeasure: Bool

    public init(id: UUID = UUID(), duration: Int, type: NoteType? = nil,
                dots: Int = 0, voice: Int = 1, staff: Int = 1, isFullMeasure: Bool = false) {
        self.id            = id
        self.duration      = duration
        self.type          = type
        self.dots          = dots
        self.voice         = voice
        self.staff         = staff
        self.isFullMeasure = isFullMeasure
    }
}

// MARK: - Pitch

public struct Pitch: Equatable, Hashable {
    public var step: PitchStep
    public var octave: Int
    public var alter: Double?

    public init(step: PitchStep, octave: Int, alter: Double? = nil) {
        self.step   = step
        self.octave = octave
        self.alter  = alter
    }

    /// MIDI pitch number. Middle C (C4) = 60.
    public var midiPitch: Int {
        let semitones: [PitchStep: Int] = [
            .c: 0, .d: 2, .e: 4, .f: 5, .g: 7, .a: 9, .b: 11
        ]
        let clampedOctave = max(0, min(9, octave))
        let base = (clampedOctave + 1) * 12 + (semitones[step] ?? 0)
        return base + Int(alter ?? 0)
    }

    /// Scientific pitch notation, e.g. "C♯5".
    public var displayName: String {
        let acc: String
        switch alter {
        case  2.0:  acc = "𝄪"
        case  1.5:  acc = "3/4♯"
        case  1.0:  acc = "♯"
        case  0.5:  acc = "½♯"
        case -0.5:  acc = "½♭"
        case -1.0:  acc = "♭"
        case -1.5:  acc = "3/4♭"
        case -2.0:  acc = "𝄫"
        default:    acc = ""
        }
        return "\(step.rawValue)\(acc)\(octave)"
    }

    /// Return a new Pitch transposed by `semitones`.
    public func transposed(by semitones: Int) -> Pitch {
        Pitch(midiPitch: midiPitch + semitones)
    }

    /// Construct a Pitch from a MIDI pitch number (uses sharps).
    public init(midiPitch midi: Int) {
        let octave = (midi / 12) - 1
        let pc     = ((midi % 12) + 12) % 12
        let table: [(PitchStep, Double?)] = [
            (.c, nil), (.c, 1.0), (.d, nil), (.d, 1.0), (.e, nil),
            (.f, nil), (.f, 1.0), (.g, nil), (.g, 1.0), (.a, nil),
            (.a, 1.0), (.b, nil),
        ]
        let (step, alter) = table[pc]
        self.init(step: step, octave: octave, alter: alter)
    }
}

public enum PitchStep: String, Equatable, Hashable, CaseIterable {
    case c = "C", d = "D", e = "E", f = "F", g = "G", a = "A", b = "B"
}

// MARK: - Note types / durations

public enum NoteType: String, Equatable, CaseIterable {
    case maxima, long, breve, whole, half, quarter, eighth
    case sixteenth    = "16th"
    case thirtySecond = "32nd"
    case sixtyFourth  = "64th"
    case hundredTwentyEighth    = "128th"
    case twoHundredFiftySixth   = "256th"
    case fiveHundredTwelfth     = "512th"
    case thousandTwentyFourth   = "1024th"

    public var canBeam: Bool {
        switch self {
        case .maxima, .long, .breve, .whole, .half, .quarter: return false
        default: return true
        }
    }

    public var relativeDuration: Double {
        switch self {
        case .maxima:                return 32
        case .long:                  return 16
        case .breve:                 return 8
        case .whole:                 return 4
        case .half:                  return 2
        case .quarter:               return 1
        case .eighth:                return 0.5
        case .sixteenth:             return 0.25
        case .thirtySecond:          return 0.125
        case .sixtyFourth:           return 0.0625
        case .hundredTwentyEighth:   return 0.03125
        case .twoHundredFiftySixth:  return 0.015625
        case .fiveHundredTwelfth:    return 0.0078125
        case .thousandTwentyFourth:  return 0.00390625
        }
    }
}

// MARK: - Articulation / notations

public enum TieKind: Equatable { case start, stop }

public enum Accidental: String, Equatable {
    case sharp, flat, natural
    case doubleSharp    = "double-sharp"
    case flatFlat       = "flat-flat"
    case naturalSharp   = "natural-sharp"
    case naturalFlat    = "natural-flat"
    case quarterFlat    = "quarter-flat"
    case quarterSharp   = "quarter-sharp"
    case threeQuartersFlat  = "three-quarters-flat"
    case threeQuartersSharp = "three-quarters-sharp"
}

public enum StemDirection: Equatable {
    case up, down, noStem, doubleStem
}

public struct Beam: Equatable {
    public var number: Int
    public var value: BeamValue
    public init(number: Int, value: BeamValue) {
        self.number = number; self.value = value
    }
}

public enum BeamValue: String, Equatable {
    case begin, continuing = "continue", end
    case forwardHook  = "forward hook"
    case backwardHook = "backward hook"
}

public enum Notation: Equatable {
    case tied(TieKind)
    case slur(number: Int, kind: SlurKind)
    case fermata
    case accent
    case strongAccent
    case tenuto
    case staccato
    case staccatissimo
    case stress
    case unstress
    case trill
    case turn
    case mordent
    case invertedMordent
    case invertedTurn
    case arpeggiate(ArpDirection?)
    case technicalFingering(Int)
}

public enum SlurKind: Equatable { case start, stop }
public enum ArpDirection: Equatable { case up, down }

// MARK: - Lyric

public struct Lyric: Equatable {
    public var number: String
    public var text: String
    public var syllabic: SyllabicKind?
    public init(number: String, text: String, syllabic: SyllabicKind? = nil) {
        self.number   = number
        self.text     = text
        self.syllabic = syllabic
    }
}

public enum SyllabicKind: String, Equatable { case single, begin, middle, end }

// MARK: - Barline

public struct Barline: Equatable {
    public var location: BarlineLocation
    public var style: BarlineStyle
    public var repeatDirection: RepeatDirection?
    public init(location: BarlineLocation = .right, style: BarlineStyle = .regular,
                repeatDirection: RepeatDirection? = nil) {
        self.location        = location
        self.style           = style
        self.repeatDirection = repeatDirection
    }
}

public enum BarlineLocation: String, Equatable { case left, right, middle }
public enum BarlineStyle: String, Equatable {
    case regular, dotted, dashed, heavy
    case lightLight  = "light-light"
    case lightHeavy  = "light-heavy"
    case heavyLight  = "heavy-light"
    case heavyHeavy  = "heavy-heavy"
    case tick, short, none
}
public enum RepeatDirection: String, Equatable { case forward, backward }

// MARK: - Direction

public struct Direction: Equatable {
    public var placement: DirectionPlacement?
    public var types: [DirectionType]
    public var offset: Int?
    public var staff: Int?
    public init(placement: DirectionPlacement? = nil, types: [DirectionType] = [],
                offset: Int? = nil, staff: Int? = nil) {
        self.placement = placement
        self.types     = types
        self.offset    = offset
        self.staff     = staff
    }
}

public enum DirectionPlacement: Equatable { case above, below }

public enum DirectionType: Equatable {
    case dynamic(String)
    case tempo(Int)
    case metronome(beat: NoteType?, perMinute: Int?)
    case words(String)
    case rehearsal(String)
    case wedge(WedgeKind)
    case pedal(PedalKind)
    case octaveShift(OctaveShiftKind)
    case segno
    case coda
    case dashes(DashesKind)
}

public enum WedgeKind: Equatable     { case crescendo, diminuendo, stop }
public enum PedalKind: Equatable     { case start, stop, change, sostenuto }
public enum OctaveShiftKind: Equatable { case up, down, stop }
public enum DashesKind: Equatable    { case start, stop }
