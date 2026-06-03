// Model/ScoreImporter.swift
// Protocol that abstracts the MusicXML → Score conversion step.
// Conforming types are injected into NotationEditorModel so the package
// never hard-codes a specific parser (Foundation or mx).

import Foundation

/// Converts a raw MusicXML string into the internal `Score` model.
/// Must be `Sendable` so instances can be safely captured by `Task.detached`.
public protocol ScoreImporter: Sendable {
    func importScore(from xml: String) throws -> Score
}
