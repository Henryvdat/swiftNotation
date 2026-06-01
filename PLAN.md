# SwiftNotation — MusicXML 4 Notation Editor: Master Plan

> **Claude instruction:** At the end of every session, update this file — mark completed checklist items, adjust progress percentages, and revise "Next Actions." This file is the single source of truth for project state.

---

## a) General Work Plan

Build a standalone macOS/iOS notation editor for MusicXML 4, using Verovio for rendering, an intermediate Swift model as the internal representation, and a SwiftUI overlay for interaction. The app must be modular so it can later be embedded into other projects and extended with a layout editor.

**Core architecture:**
```
MusicXML File
    └─► Parser (mx / XMLCoder)
            └─► Internal Model (Score → Parts → Measures → Voices → Notes)
                    └─► Renderer (Verovio → SVG)
                            └─► SwiftUI / AppKit overlay (selection, editing)
```

**Golden rule:** Never couple UI directly to XML. Always: `UI ↔ Model ↔ Renderer`

**Key constraints:** Fully offline. WKWebView is used for SVG display only (requires `com.apple.security.network.client` for its internal subprocess architecture — no external requests are made).

**Key dependencies:**
| Library | Purpose | Source |
|---|---|---|
| **Verovio** | SVG notation renderer (C++ static lib) | https://github.com/rism-digital/verovio.git |
| **mx** | C++ MusicXML 4 parser | https://github.com/webern/mx.git |
| **musicxml** | W3C MusicXML 4 schema/reference | https://github.com/w3c-cg/musicxml.git |

---

## b) Implementation Stages

### Stage 1 — Project Bootstrap & Dependency Integration
*Goal: compile the project with all three dependencies linked.*

- [ ] Add **mx** (C++ parser) to Xcode project via Swift Package Manager or manual xcframework
- [ ] Add **Verovio** to Xcode project (SPM or pre-built xcframework)
- [ ] Clone **musicxml** schema repo for reference/validation
- [ ] Configure bridging header for C++ interop (mx ↔ Swift)
- [ ] Verify a "hello world" build compiles cleanly

### Stage 2 — File Loading & Raw Rendering
*Goal: open a .musicxml file and display rendered notation via Verovio.*

- [ ] Implement file picker (open .musicxml / .xml)
- [ ] Pass raw XML string to Verovio's Swift/ObjC wrapper
- [ ] Display returned SVG in a `WKWebView` or `PDFView`-equivalent
- [ ] Handle basic errors (invalid XML, unsupported version)
- [ ] Test with a sample MusicXML 4 file

### Stage 3 — Internal Model
*Goal: introduce a clean Swift model decoupled from raw XML.*

- [ ] Define model types: `Score`, `Part`, `Measure`, `Voice`, `Note`, `Rest`, `Chord`
- [ ] Build importer: mx parse output → Swift model (normalize durations, voices, ties, tuplets)
- [ ] Build exporter: Swift model → MusicXML string (for save/round-trip)
- [ ] Unit tests for import/export round-trips

### Stage 4 — Interactive Overlay (Selection)
*Goal: user can tap/click a note and see it highlighted.*

- [ ] Map Verovio SVG element IDs back to model objects
- [ ] Implement hit-testing on the rendered SVG
- [ ] Highlight selected note/rest in the overlay
- [ ] Display selected element's properties in a detail panel

### Stage 5 — Basic Editing
*Goal: insert, delete, and modify notes; re-render on change.*

- [ ] Insert note at cursor position
- [ ] Delete selected note
- [ ] Change pitch / duration of selected note
- [ ] Trigger Verovio re-render on every model mutation
- [ ] Undo/redo stack (UndoManager)

### Stage 6 — Layout Editor Foundation
*Goal: groundwork for embedding in other projects.*

- [ ] Abstract the editor into a reusable Swift package / framework target
- [ ] Define public API (load, save, selection delegate, edit commands)
- [ ] Add layout customisation (page size, margins, zoom)
- [ ] Document integration points for host apps

---

## c) Checklist

### Stage 1 — Bootstrap
- [ ] mx added to Xcode project *(see SETUP.md — Stage 3 dependency)*
- [x] Verovio C++ bridge written (`VerovioWrapper.h/.mm`, bridging header, `VerovioRenderer.swift`)
- [x] Verovio submodule cloned + `libverovio.a` built via cmake
- [x] Verovio `data/` folder added to app bundle as folder reference
- [x] All verovio header search paths configured (include subdirs + libmei)
- [ ] musicxml schema cloned *(optional reference)*
- [x] C++ bridging header configured (`swiftNotation-Bridging-Header.h`)
- [x] Project builds without errors

### Stage 2 — Render
- [x] File picker implemented (`ContentView.swift`)
- [x] XML passed to Verovio (`VerovioRenderer.swift`)
- [x] SVG displayed in view (`ScoreWebView.swift`)
- [x] Error handling in place
- [x] Sample MusicXML file added (`Sample.musicxml`)

### Stage 3 — Model
- [ ] Score/Part/Measure/Voice/Note types defined
- [ ] Importer written
- [ ] Exporter written
- [ ] Round-trip tests passing

### Stage 4 — Selection
- [ ] SVG ID ↔ model mapping implemented
- [ ] Hit-testing working
- [ ] Selection highlight working
- [ ] Detail panel showing properties

### Stage 5 — Editing
- [ ] Insert note working
- [ ] Delete note working
- [ ] Pitch/duration change working
- [ ] Re-render on edit working
- [ ] Undo/redo working

### Stage 6 — Framework
- [ ] Editor extracted as reusable package
- [ ] Public API defined
- [ ] Layout customisation working
- [ ] Integration documented

---

## d) Progress

| Stage | Status | % Complete |
|---|---|---|
| 1 — Bootstrap | 🟢 Complete | 95% |
| 2 — Render | 🟢 Complete | 100% |
| 3 — Model | 🔴 Not started | 0% |
| 4 — Selection | 🔴 Not started | 0% |
| 5 — Editing | 🔴 Not started | 0% |
| 6 — Framework | 🔴 Not started | 0% |
| **Overall** | | **25%** |

*Legend: 🔴 Not started · 🟡 In progress · 🟢 Complete*

---

## e) Next Actions

1. **Add mx as submodule** — add `https://github.com/webern/mx.git` under `Packages/mx`, build as a static library, configure header/library search paths in Xcode (mirrors the verovio setup).
2. **Write mx ObjC++ bridge** — create `MxBridge.h` / `MxBridge.mm` to parse MusicXML via mx and expose the result to Swift.
3. **Define Swift model types** — create `Score.swift`, `Part.swift`, `Measure.swift`, `Note.swift` with the internal model structure from Stage 3.
4. **Wire model into renderer** — instead of passing raw XML to Verovio, route through the model so edits can trigger re-renders.
5. **SVG ID mapping** — use Verovio's `svgBoundingBoxes: true` output to map element IDs back to model objects for hit-testing (Stage 4 foundation).

---

## Session Log

| Date | Summary |
|---|---|
| 2026-05-31 | Plan created from transcript. Project structure confirmed. No code written yet. |
| 2026-05-31 | Session 2: Verovio integrated via WKWebView JS toolkit (later replaced). |
| 2026-05-31 | Session 3: Architecture corrected — fully offline, no JS/CDN. Replaced WKWebView JS approach with native Verovio C++ via ObjC++ bridge (VerovioWrapper.h/.mm). Added bridging header, SWIFT_OBJC_BRIDGING_HEADER, HEADER_SEARCH_PATHS, LIBRARY_SEARCH_PATHS, OTHER_LDFLAGS in pbxproj. Entitlements updated (network.client removed). Views separated: EditorToolbar, ScoreCanvas, ScoreWebView, ContentView, RendererModel each in own file. SETUP.md updated with cmake build steps. Pending: user runs cmake to produce libverovio.a and adds data/ bundle. |
| 2026-05-31 | Session 4: Full build fix. Resolved 772 duplicate resource errors (deleted local data/ copy), fixed Swift 6 member import visibility (added import Combine), fixed ObjC NSError** bridging, added all verovio header subdirectory search paths, added Packages/verovio/data as folder reference resource, removed unsupported noLayout option, restored WKWebView with com.apple.security.network.client entitlement. App now builds cleanly and renders MusicXML files. Pushed to GitHub. |

---

*Last updated: 2026-05-31 (Session 4)*
