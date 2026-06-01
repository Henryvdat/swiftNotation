// VerovioRenderer.swift
// Swift facade over VerovioWrapper (ObjC++ → Verovio C++).
// All calls to VerovioWrapper are serialised on a private queue so they never
// race with each other, and the main thread is never blocked.

import Foundation

// VerovioWrapper is an ObjC class with no Swift Sendable annotation.
// All access is serialised on VerovioRenderer's private queue, so it is
// safe to capture across concurrency boundaries — we assert this with
// @unchecked Sendable.
extension VerovioWrapper: @unchecked Sendable {}

// MARK: - Error type

/// Errors that can arise during score loading or rendering.
enum VerovioError: LocalizedError {
    case loadFailed(String)
    case renderFailed(String)
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .loadFailed(let msg):   return "Load failed: \(msg)"
        case .renderFailed(let msg): return "Render failed: \(msg)"
        case .notLoaded:             return "No score is loaded"
        }
    }
}

// MARK: - Renderer

/// Wraps `VerovioWrapper` and exposes a clean async/await Swift API.
///
/// `VerovioWrapper` is not thread-safe; all access is serialised on `queue`.
/// The renderer itself is not `Sendable` — callers should hold it on a single
/// actor (typically `@MainActor` via `RendererModel`).
final class VerovioRenderer {

    // The wrapper and queue are both created at init time and never replaced,
    // so they are safe to reference from inside queue.async blocks via strong
    // capture rather than `weak self`.  Using a strong capture also prevents
    // the continuation-leak that occurs when `weak self` becomes nil before
    // the block executes.
    private let wrapper = VerovioWrapper()
    private let queue = DispatchQueue(label: "com.swiftnotation.verovio.render",
                                      qos: .userInitiated)

    // MARK: - Public API

    /// Load a MusicXML string. Must be called before `renderPage(_:)`.
    func load(musicXML: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [wrapper] in
                do {
                    try wrapper.loadMusicXML(musicXML)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: VerovioError.loadFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Render a single page to an SVG string. `page` is 1-based.
    func renderPage(_ page: Int = 1) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [wrapper] in
                do {
                    let svg = try wrapper.renderPage(page)
                    continuation.resume(returning: svg)
                } catch {
                    continuation.resume(throwing: VerovioError.renderFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Total number of pages in the currently loaded score.
    /// Accessing this from any actor is safe because the value is read
    /// on the serial render queue where all mutations also occur.
    var pageCount: Int {
        get async {
            await withCheckedContinuation { continuation in
                queue.async { [wrapper] in
                    continuation.resume(returning: Int(wrapper.pageCount))
                }
            }
        }
    }

    /// Override Verovio layout options with a JSON string.
    /// Example: `"{\"scale\": 40, \"adjustPageHeight\": true}"`
    func setOptions(_ json: String) {
        queue.async { [wrapper] in wrapper.setOptionsJSON(json) }
    }
}
