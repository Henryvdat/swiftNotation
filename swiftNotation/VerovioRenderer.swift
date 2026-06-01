// VerovioRenderer.swift
// Swift facade over VerovioWrapper (ObjC++ → Verovio C++).
// Runs rendering off the main thread and delivers results on the main actor.

import Foundation

/// Errors that can arise during score loading or rendering.
enum VerovioError: LocalizedError {
    case loadFailed(String)
    case renderFailed(String)
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .loadFailed(let msg):  return "Load failed: \(msg)"
        case .renderFailed(let msg): return "Render failed: \(msg)"
        case .notLoaded:            return "No score loaded"
        }
    }
}

/// Wraps VerovioWrapper and exposes a clean async Swift API.
final class VerovioRenderer {

    private let wrapper = VerovioWrapper()
    private let queue = DispatchQueue(label: "verovio.render", qos: .userInitiated)

    // MARK: - API

    /// Load a MusicXML string. Call before rendering.
    func load(musicXML: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.wrapper.loadMusicXML(musicXML)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: VerovioError.loadFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Render a single page to SVG. `page` is 1-based.
    func renderPage(_ page: Int = 1) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return }
                do {
                    let svg = try self.wrapper.renderPage(page)
                    continuation.resume(returning: svg)
                } catch {
                    continuation.resume(throwing: VerovioError.renderFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Total pages in the currently loaded score.
    var pageCount: Int { Int(wrapper.pageCount) }

    /// Override Verovio layout options with a JSON string.
    func setOptions(_ json: String) {
        queue.async { [weak self] in self?.wrapper.setOptionsJSON(json) }
    }
}
