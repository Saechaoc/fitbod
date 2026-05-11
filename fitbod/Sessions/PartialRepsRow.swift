//
//  PartialRepsRow.swift
//  fitbod
//
//  Wave-4 plan 04-02 — opt-in partial reps row (SESS-08). Renders only
//  when the parent `SessionExerciseCard` decides
//  `sessionExercise.tracksPartialReps == true` (snapshotted from the
//  source `RoutineExercise.tracksPartialReps` at SessionFactory time).
//
//  ## UI-SPEC verbatim
//
//  "Partial reps" leading caption, followed by a single small numeric
//  `TextField` with placeholder "0" (UI-SPEC § Session logger
//  "Partial reps row label"). Captures the partial-rep count
//  performed after the main set hit failure (e.g. lengthened partials
//  beyond the working set).
//
//  ## Persistence semantics
//
//  Empty input → `entry.partialReps = nil` (no zero ghosts in history).
//  Non-empty numeric input → `entry.partialReps = Int(newValue)`. The
//  Phase 1 `SetEntry.partialReps: Int?` field is the destination.
//

import SwiftUI
import SwiftData

public struct PartialRepsRow: View {
    @Bindable public var entry: SetEntry
    @State private var partialsText: String = ""

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 8) {                                                    // UI-SPEC sm
            Text("Partial reps")                                                // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: $partialsText)
                .keyboardType(.numberPad)
                .frame(width: 40)
                .multilineTextAlignment(.center)
                .font(.caption)
                .onChange(of: partialsText) { _, newValue in
                    entry.partialReps = newValue.isEmpty ? nil : Int(newValue)
                }
            Spacer()
        }
        .padding(.vertical, 4)                                                  // UI-SPEC xs
        .onAppear {
            partialsText = entry.partialReps.map(String.init) ?? ""
        }
    }
}

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
}
