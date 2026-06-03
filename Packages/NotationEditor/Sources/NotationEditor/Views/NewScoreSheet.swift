// Views/NewScoreSheet.swift
// Modal sheet for configuring and creating a new blank score.

import SwiftUI

// MARK: - Config

/// All parameters needed to build a blank score.
public struct NewScoreConfig: Sendable {
    public var title:        String
    public var composer:     String
    public var partName:     String
    public var keyFifths:    Int
    public var keyMode:      KeyMode
    public var timeBeats:    Int
    public var timeBeatType: Int
    public var clef:         Clef
    public var measureCount: Int

    public init(
        title:        String  = "",
        composer:     String  = "",
        partName:     String  = "Piano",
        keyFifths:    Int     = 0,
        keyMode:      KeyMode = .major,
        timeBeats:    Int     = 4,
        timeBeatType: Int     = 4,
        clef:         Clef    = .treble,
        measureCount: Int     = 16
    ) {
        self.title        = title
        self.composer     = composer
        self.partName     = partName
        self.keyFifths    = keyFifths
        self.keyMode      = keyMode
        self.timeBeats    = timeBeats
        self.timeBeatType = timeBeatType
        self.clef         = clef
        self.measureCount = measureCount
    }
}

// MARK: - Sheet

public struct NewScoreSheet: View {

    @Binding var isPresented: Bool
    let onCreate: (NewScoreConfig) -> Void

    @State private var title        = ""
    @State private var composer     = ""
    @State private var partName     = "Piano"
    @State private var keyFifths    = 0
    @State private var keyMode:     KeyMode = .major
    @State private var timeBeats    = 4
    @State private var timeBeatType = 4
    @State private var clef:        Clef = .treble
    @State private var measureCount = 16

    private let beatTypes = [2, 4, 8, 16]

    public init(isPresented: Binding<Bool>, onCreate: @escaping (NewScoreConfig) -> Void) {
        self._isPresented = isPresented
        self.onCreate     = onCreate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("New Score")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            Form {
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Composer", text: $composer)
                    TextField("Instrument", text: $partName)
                        .help("Instrument or part name (e.g. Violin, Piano)")
                }

                Section("Key & Time") {
                    Picker("Key", selection: $keyFifths) {
                        ForEach(-7...7, id: \.self) { k in
                            Text(keyLabel(k, mode: keyMode)).tag(k)
                        }
                    }
                    Picker("Mode", selection: $keyMode) {
                        Text("Major").tag(KeyMode.major)
                        Text("Minor").tag(KeyMode.minor)
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Time signature") {
                        HStack(spacing: 6) {
                            Stepper(value: $timeBeats, in: 1...32) {
                                Text("\(timeBeats)")
                                    .monospacedDigit()
                                    .frame(minWidth: 20, alignment: .trailing)
                            }
                            Text("/")
                                .foregroundStyle(.secondary)
                            Picker("Beat type", selection: $timeBeatType) {
                                ForEach(beatTypes, id: \.self) { bt in
                                    Text("\(bt)").tag(bt)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                Section("Notation") {
                    Picker("Clef", selection: $clef) {
                        Text("Treble").tag(Clef.treble)
                        Text("Bass").tag(Clef.bass)
                        Text("Alto").tag(Clef.alto)
                        Text("Tenor").tag(Clef.tenor)
                        Text("Percussion").tag(Clef.percussion)
                    }

                    Stepper("Measures: \(measureCount)", value: $measureCount, in: 1...300)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Create") {
                    let config = NewScoreConfig(
                        title:        title,
                        composer:     composer,
                        partName:     partName,
                        keyFifths:    keyFifths,
                        keyMode:      keyMode,
                        timeBeats:    timeBeats,
                        timeBeatType: timeBeatType,
                        clef:         clef,
                        measureCount: measureCount
                    )
                    isPresented = false
                    onCreate(config)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460)
    }

    // MARK: - Helpers

    private func keyLabel(_ fifths: Int, mode: KeyMode) -> String {
        let majorRoots = ["C♭","G♭","D♭","A♭","E♭","B♭","F","C","G","D","A","E","B","F♯","C♯"]
        let minorRoots = ["A♭","E♭","B♭","F","C","G","D","A","E","B","F♯","C♯","G♯","D♯","A♯"]
        let idx = fifths + 7
        guard (0..<15).contains(idx) else { return "\(fifths)" }
        let root = mode == .major ? majorRoots[idx] : minorRoots[idx]
        let qual = mode == .major ? "major" : "minor"
        let acc: String
        switch fifths {
        case ..<0: acc = " (\(abs(fifths))♭)"
        case 1...: acc = " (\(fifths)♯)"
        default:   acc = ""
        }
        return "\(root) \(qual)\(acc)"
    }
}

// MARK: - Preview

#Preview {
    NewScoreSheet(isPresented: .constant(true)) { config in
        print("Create: \(config.title), \(config.timeBeats)/\(config.timeBeatType)")
    }
}
