// swift-tools-version: 5.9
// NotationEditor — reusable MusicXML notation editor package.
//
// Host app integration:
//   1. In Xcode: File > Add Package Dependencies > Add Local… → select this directory
//   2. In the host target, import NotationEditor
//   3. Provide a concrete ScoreRenderer (e.g. VerovioRenderer) and create a NotationEditorModel
//   4. Embed NotationEditorView in your SwiftUI hierarchy

import PackageDescription

let package = Package(
    name: "NotationEditor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "NotationEditor",
            targets: ["NotationEditor"]
        ),
    ],
    targets: [
        .target(
            name: "NotationEditor",
            path: "Sources/NotationEditor"
        ),
    ]
)
