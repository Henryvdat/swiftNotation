// ScoreRenderer.swift
// Protocol that decouples the editor from the concrete rendering engine.
//
// Host apps implement this protocol using their renderer of choice
// (e.g. Verovio via ObjC++ bridge).  The package never imports Verovio
// directly, keeping it free of C++ dependencies.
//
// Usage:
//   final class VerovioRenderer: ScoreRenderer { … }
//   let model = NotationEditorModel(renderer: VerovioRenderer())
//   NotationEditorView(model: model)

import Foundation

/// An asynchronous score renderer.
///
/// Implementations are expected to be reference types (`class` or `actor`)
/// because loading state is inherently mutable and shared.
public protocol ScoreRenderer: AnyObject {

    /// Load (or reload) MusicXML source.  Must be callable multiple times.
    func load(musicXML: String) async throws

    /// Render a single page and return its raw SVG string.
    /// Page numbers are 1-based.
    func renderPage(_ page: Int) async throws -> String

    /// Apply a JSON options string (Verovio option format or equivalent).
    func setOptions(_ json: String)

    /// Number of pages in the current document.  0 before any document is loaded.
    var pageCount: Int { get async }
}
