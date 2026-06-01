# Setup Instructions

This app is **fully offline**. No internet connection is needed at runtime.
All rendering is done natively via the Verovio C++ library linked directly into the app.

---

## 1. Add Verovio as a submodule and build it

```bash
cd /path/to/swiftNotation        # project root

# Add the submodule
git submodule add https://github.com/rism-digital/verovio.git Packages/verovio
git submodule update --init --recursive

# Build a macOS static library
cd Packages/verovio
mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"   # universal binary
make -j$(sysctl -n hw.logicalcpu)
```

This produces `Packages/verovio/build/libverovio.a`.

The build settings in `project.pbxproj` already point to:
- Headers: `$(SRCROOT)/Packages/verovio/include`
- Library: `$(SRCROOT)/Packages/verovio/build`
- Linker flag: `-lverovio`

So once the library is built, Xcode will pick it up automatically.

---

## 2. Copy the Verovio data directory into the app bundle

Verovio needs its `data/` folder at runtime (fonts, glyphs, etc.).

In Xcode:
1. Right-click the `swiftNotation` group → **Add Files to "swiftNotation"**
2. Navigate to `Packages/verovio/data/`
3. Select the `data` folder
4. Choose **Create folder references** (not groups)
5. Make sure **Add to target: swiftNotation** is checked

`VerovioWrapper.mm` already calls `SetResourcePath` pointing at this bundle folder.

---

## 3. Add mx as a submodule (Stage 3 — Internal Model)

```bash
cd /path/to/swiftNotation
git submodule add https://github.com/webern/mx.git Packages/mx
git submodule update --init --recursive
```

Build and Xcode integration steps will be added when Stage 3 begins.

---

## 4. MusicXML schema reference (optional)

```bash
git submodule add https://github.com/w3c-cg/musicxml.git References/musicxml
```

Reference only — not a build target.

---

## Quick Start

1. Complete steps 1–2 above
2. Open `swiftNotation.xcodeproj`
3. Build (⌘B) — should compile cleanly
4. Run (⌘R) → click **Open Score** → select `swiftNotation/Sample.musicxml`
