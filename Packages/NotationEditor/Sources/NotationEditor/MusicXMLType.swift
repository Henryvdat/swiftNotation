// MusicXMLType.swift
// Registers the MusicXML UTType so fileImporter can filter for .musicxml files.

import UniformTypeIdentifiers

public extension UTType {
    /// MusicXML score files (.musicxml).
    /// Matched by file extension — no Info.plist UTI declaration required.
    public static let musicXML: UTType = UTType(filenameExtension: "musicxml", conformingTo: .xml) ?? .xml
}
