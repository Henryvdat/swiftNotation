// swiftNotationTests.swift
// Unit tests for Stage 3: MusicXML importer, exporter, and round-trip fidelity.

import Testing
import NotationEditor
@testable import swiftNotation

// MARK: - Importer tests

@MainActor
struct ImporterTests {

    let importer = MusicXMLImporter()

    // MARK: Title / metadata

    @Test func parsesMovementTitle() throws {
        let score = try importer.importScore(from: sampleXML)
        #expect(score.title == "SwiftNotation Sample")
    }

    @Test func parsesPartList() throws {
        let score = try importer.importScore(from: sampleXML)
        #expect(score.parts.count == 1)
        #expect(score.parts[0].xmlID == "P1")
        #expect(score.parts[0].name  == "Piano")
    }

    // MARK: Measures

    @Test func parsesMeasureCount() throws {
        let score = try importer.importScore(from: sampleXML)
        #expect(score.parts[0].measures.count == 4)
    }

    @Test func parsesFirstMeasureAttributes() throws {
        let score  = try importer.importScore(from: sampleXML)
        let attrs  = try #require(score.parts[0].measures[0].attributes)
        #expect(attrs.divisions    == 1)
        #expect(attrs.keyFifths    == 0)
        #expect(attrs.timeBeats    == 4)
        #expect(attrs.timeBeatType == 4)
        #expect(attrs.clef         == .treble)
    }

    // MARK: Notes

    @Test func parsesFirstMeasureNotes() throws {
        let score    = try importer.importScore(from: sampleXML)
        let elements = score.parts[0].measures[0].elements
        // Measure 1: C5 D5 E5 F5
        let notes = elements.compactMap { if case .note(let n) = $0 { return n }; return nil }
        #expect(notes.count == 4)
        #expect(notes[0].pitch.step   == .c)
        #expect(notes[0].pitch.octave == 5)
        #expect(notes[0].type         == .quarter)
        #expect(notes[0].duration     == 1)

        #expect(notes[3].pitch.step   == .f)
        #expect(notes[3].pitch.octave == 5)
    }

    @Test func parsesMeasure2Notes() throws {
        let score  = try importer.importScore(from: sampleXML)
        let notes  = noteElements(in: score.parts[0].measures[1])
        #expect(notes.count == 4)
        #expect(notes[0].pitch.step == .g)
        #expect(notes[3].pitch.step == .c)
        #expect(notes[3].pitch.octave == 6)
    }

    @Test func parsesHalfNoteInMeasure4() throws {
        let score = try importer.importScore(from: sampleXML)
        let notes = noteElements(in: score.parts[0].measures[3])
        let half  = notes.first { $0.type == .half }
        #expect(half != nil)
        #expect(half?.duration == 2)
        #expect(half?.pitch.step == .c)
    }

    // MARK: Barlines

    @Test func parsesBarlineInMeasure4() throws {
        let score    = try importer.importScore(from: sampleXML)
        let elements = score.parts[0].measures[3].elements
        let barlines = elements.compactMap { if case .barline(let b) = $0 { return b }; return nil }
        #expect(barlines.count == 1)
        #expect(barlines[0].location == .right)
        #expect(barlines[0].style    == .lightHeavy)
    }

    // MARK: Error handling

    @Test func throwsOnMalformedXML() throws {
        #expect(throws: (any Error).self) {
            try importer.importScore(from: "not xml at all <<>>")
        }
    }

    @Test func throwsOnMissingRoot() throws {
        #expect(throws: (any Error).self) {
            try importer.importScore(from: "<wrong-root/>")
        }
    }
}

// MARK: - Exporter tests

@MainActor
struct ExporterTests {

    let importer = MusicXMLImporter()
    let exporter = MusicXMLExporter()

    @Test func exportedXMLIsValidXML() throws {
        let score  = try importer.importScore(from: sampleXML)
        let xml    = exporter.exportScore(score)
        // If the exporter produced valid XML the importer can re-parse it.
        let score2 = try importer.importScore(from: xml)
        #expect(score2.parts.count == score.parts.count)
    }

    @Test func exportedTitleRoundTrips() throws {
        let score  = try importer.importScore(from: sampleXML)
        let xml    = exporter.exportScore(score)
        let score2 = try importer.importScore(from: xml)
        #expect(score2.title == score.title)
    }

    @Test func exportedMeasureCountRoundTrips() throws {
        let score   = try importer.importScore(from: sampleXML)
        let xml     = exporter.exportScore(score)
        let score2  = try importer.importScore(from: xml)
        let part1   = score.parts[0]
        let part2   = score2.parts[0]
        #expect(part2.measures.count == part1.measures.count)
    }

    @Test func exportedNoteCountRoundTrips() throws {
        let score  = try importer.importScore(from: sampleXML)
        let xml    = exporter.exportScore(score)
        let score2 = try importer.importScore(from: xml)
        let originalNotes = score.parts[0].measures.flatMap  { noteElements(in: $0) }
        let roundTripped  = score2.parts[0].measures.flatMap { noteElements(in: $0) }
        #expect(roundTripped.count == originalNotes.count)
    }

    @Test func exportedPitchesRoundTrip() throws {
        let score  = try importer.importScore(from: sampleXML)
        let xml    = exporter.exportScore(score)
        let score2 = try importer.importScore(from: xml)
        let orig   = score.parts[0].measures.flatMap  { noteElements(in: $0) }.map(\.pitch)
        let rt     = score2.parts[0].measures.flatMap { noteElements(in: $0) }.map(\.pitch)
        #expect(rt == orig)
    }

    @Test func exportedAttributesRoundTrip() throws {
        let score  = try importer.importScore(from: sampleXML)
        let xml    = exporter.exportScore(score)
        let score2 = try importer.importScore(from: xml)
        let a1     = score.parts[0].measures[0].attributes
        let a2     = score2.parts[0].measures[0].attributes
        #expect(a2?.divisions    == a1?.divisions)
        #expect(a2?.timeBeats    == a1?.timeBeats)
        #expect(a2?.timeBeatType == a1?.timeBeatType)
        #expect(a2?.keyFifths    == a1?.keyFifths)
        #expect(a2?.clef         == a1?.clef)
    }
}

// MARK: - Model logic tests

@MainActor
struct ScoreModelTests {

    @Test func pitchMidiC4() {
        let p = Pitch(step: .c, octave: 4, alter: nil)
        #expect(p.midiPitch == 60)
    }

    @Test func pitchMidiA4() {
        let p = Pitch(step: .a, octave: 4, alter: nil)
        #expect(p.midiPitch == 69)
    }

    @Test func pitchMidiCSharp5() {
        let p = Pitch(step: .c, octave: 5, alter: 1.0)
        #expect(p.midiPitch == 73)
    }

    @Test func pitchDisplayNameC5() {
        let p = Pitch(step: .c, octave: 5, alter: nil)
        #expect(p.displayName == "C5")
    }

    @Test func noteTypeRelativeDuration() {
        #expect(NoteType.whole.relativeDuration   == 4.0)
        #expect(NoteType.half.relativeDuration    == 2.0)
        #expect(NoteType.quarter.relativeDuration == 1.0)
        #expect(NoteType.eighth.relativeDuration  == 0.5)
    }
}

// MARK: - Helpers

private func noteElements(in measure: Measure) -> [Note] {
    measure.elements.compactMap {
        if case .note(let n) = $0 { return n }
        return nil
    }
}

// MARK: - Sample XML

private let sampleXML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <movement-title>SwiftNotation Sample</movement-title>
  <identification>
    <encoding>
      <software>swiftNotation</software>
      <encoding-date>2026-05-31</encoding-date>
    </encoding>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>G</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>B</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>6</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="3">
      <note><pitch><step>B</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="4">
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
      <barline location="right"><bar-style>light-heavy</bar-style></barline>
    </measure>
  </part>
</score-partwise>
"""
