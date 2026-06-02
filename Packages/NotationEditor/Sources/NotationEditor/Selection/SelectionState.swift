// Selection/SelectionState.swift

import Foundation

public enum SelectedElement: Equatable {
    case note(Note)
    case rest(Rest)

    public var svgID: String? {
        switch self {
        case .note(let n): return n.svgID
        case .rest(let r): return r.svgID
        }
    }

    public var summary: String {
        switch self {
        case .note(let n):
            return "\(n.pitch.displayName)  \(n.type?.rawValue ?? "?")  voice \(n.voice)"
        case .rest(let r):
            return "Rest  \(r.type?.rawValue ?? "?")  voice \(r.voice)"
        }
    }
}

public struct SelectionState: Equatable {
    public var element: SelectedElement?

    public init(element: SelectedElement? = nil) {
        self.element = element
    }

    public var isNoteSelected: Bool {
        if case .note = element { return true }
        return false
    }

    public var selectedNote: Note? {
        if case .note(let n) = element { return n }
        return nil
    }

    public var selectedRest: Rest? {
        if case .rest(let r) = element { return r }
        return nil
    }

    public var svgID: String? { element?.svgID }

    public mutating func clear() { element = nil }
}
