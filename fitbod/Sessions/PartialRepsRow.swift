// PartialRepsRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 40).
// UI-SPEC v2 § Session logger line 383.
//
// Opt-in partial reps row (SESS-08). Renders only when the parent
// SessionExerciseCard decides sessionExercise.tracksPartialReps == true.
//
// UI-SPEC verbatim:
//   Leading section label: "PARTIAL REPS"   (labelSmall 10pt, 1.2 letterspacing)
//   Field:                 BRUFont.bodyDefault mono 12pt, outlined Rectangle 1pt bruInk
//
// Persistence semantics:
//   Empty → partialReps = nil (no zero ghosts in history).
//   Non-empty numeric → partialReps = Int(newValue).
//
// BRU contract:
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct PartialRepsRow: View {
    @Bindable public var entry: SetEntry
    @State private var partialsText: String = ""

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Leading section label per UI-SPEC line 383
            Text("PARTIAL REPS")                                                    // UI-SPEC verbatim
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            // Mono TextField with 1pt bruInk outlined Rectangle
            TextField("—", text: $partialsText)
                .font(BRUFont.bodyDefault)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(minWidth: 40, minHeight: 32)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: 1)
                )
                .onChange(of: partialsText) { _, newValue in
                    entry.partialReps = newValue.isEmpty ? nil : Int(newValue)
                }

            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear {
            partialsText = entry.partialReps.map(String.init) ?? ""
        }
    }
}

#if DEBUG
#Preview("partial reps row") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    se.tracksPartialReps = true
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.partialReps = 3
    ctx.insert(entry)
    try? ctx.save()
    return PartialRepsRow(entry: entry)
        .modelContainer(container)
        .padding()
        .background(Color.bruPaper)
}
#endif
