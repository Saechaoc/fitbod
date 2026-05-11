//
//  TempoEntryRow.swift
//  fitbod
//
//  Wave-4 plan 04-02 — opt-in 4-field tempo entry row (SESS-07).
//  Renders only when the parent `SessionExerciseCard` decides
//  `sessionExercise.tracksTempo == true` (snapshotted from the source
//  `RoutineExercise.tracksTempo` at SessionFactory time).
//
//  ## UI-SPEC verbatim
//
//  "Tempo" leading caption, followed by four small numeric `TextField`s
//  labeled inline "Ecc / Bot / Con / Top" (UI-SPEC § Session logger
//  "Tempo entry row label"). Each field captures one digit/integer per
//  tempo component; the dash-joined result persists to
//  `SetEntry.tempoActual: String?` as "ecc-bot-con-top" (e.g. "3-1-1-0",
//  matching the Phase 1 SetEntry header convention).
//
//  ## Persistence semantics
//
//  - Empty input → `tempoActual = nil` (no "0-0-0-0" ghosts in history).
//  - Any non-empty value across the four fields → joined with "-"
//    (preserves empty mid-fields as empty segments — e.g. "3--1-0").
//
//  Round-trip is symmetric: a saved "3-1-1-0" splits back into four
//  fields and re-renders identically.
//

import SwiftUI
import SwiftData

public struct TempoEntryRow: View {
    @Bindable public var entry: SetEntry
    @State private var components: [String] = ["", "", "", ""]

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 8) {                                                    // UI-SPEC sm
            Text("Tempo")                                                       // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(0..<4, id: \.self) { idx in
                TextField(label(idx), text: Binding(
                    get: { components[idx] },
                    set: { newValue in
                        components[idx] = newValue
                        persistTempo()
                    }
                ))
                .keyboardType(.numberPad)
                .frame(width: 32)
                .multilineTextAlignment(.center)
                .font(.caption)
            }
            Spacer()
        }
        .padding(.vertical, 4)                                                  // UI-SPEC xs
        .onAppear {
            // Re-hydrate the four fields from the persisted tempoActual.
            let parts = (entry.tempoActual ?? "").split(
                separator: "-",
                omittingEmptySubsequences: false
            ).map(String.init)
            for i in 0..<4 {
                components[i] = i < parts.count ? parts[i] : ""
            }
        }
    }

    /// UI-SPEC verbatim labels for the four tempo components
    /// (eccentric / bottom / concentric / top).
    private func label(_ idx: Int) -> String {
        ["Ecc", "Bot", "Con", "Top"][idx]                                       // UI-SPEC verbatim labels
    }

    /// Persists the dash-joined tempo to `SetEntry.tempoActual`. Empty
    /// across the board → nil so the history doesn't accumulate
    /// "0-0-0-0" ghost rows.
    private func persistTempo() {
        let allEmpty = components.allSatisfy { $0.isEmpty }
        entry.tempoActual = allEmpty ? nil : components.joined(separator: "-")
    }
}

#Preview("tempo entry row") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    se.tracksTempo = true
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.tempoActual = "3-1-1-0"
    ctx.insert(entry)
    try? ctx.save()
    return TempoEntryRow(entry: entry)
        .modelContainer(container)
        .padding()
}
