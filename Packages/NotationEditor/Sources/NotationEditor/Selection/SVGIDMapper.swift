// Selection/SVGIDMapper.swift
// Builds a lookup table from SVG element id → model Note or Rest.

import Foundation

public struct SVGIDMap {
    public enum Element {
        case note(Note)
        case rest(Rest)
    }
    public var table: [String: Element]

    public init() { table = [:] }
}

public struct SVGIDMapper {
    public init() {}

    public func buildMap(from score: Score) -> SVGIDMap {
        var result = SVGIDMap()
        for part in score.parts {
            for measure in part.measures {
                for element in measure.elements {
                    switch element {
                    case .note(let n):
                        result.table[n.svgID] = .note(n)
                    case .rest(let r):
                        result.table[r.svgID] = .rest(r)
                    default:
                        break
                    }
                }
            }
        }
        return result
    }
}
