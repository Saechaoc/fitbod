//
//  ClusterSubRepChipRow.swift
//  fitbod
//
//  Wave-4 plan 04-02 — rest-pause sub-rep chip row (SESS-08). Renders
//  only when the parent `SessionExerciseCard` decides the set's
//  `setType == .restPause` (cluster / rest-pause set type chosen via
//  the SetTypeChip cycling/menu).
//
//  ## UI-SPEC verbatim
//
//  "Sub-reps:" prefix, followed by a chip per logged sub-rep (e.g.
//  `[8] [3] [2]`) and a trailing `[+]` chip to add another. Each chip
//  is a Capsule with `Color(.systemGray5)` background and a `.caption`
//  rep-count label (UI-SPEC § Session logger
//  "Cluster / rest-pause sub-rep chip row").
//
//  ## Persistence semantics
//
//  Reads/writes via the `entry.clusterSubReps: [Int]` computed accessor
//  from plan 00-01 (Phase 1 SetEntry extension). The accessor encodes
//  the array as a comma-separated string in
//  `SetEntry.clusterSubRepsJoined`, so an empty array round-trips to
//  `nil`. The first tap on `[+]` appends `1` (the most common rest-pause
//  miniset count); the user can override the chip's value in a later
//  Phase 6 polish (chip-tap-to-edit pattern explicitly deferred per the
//  plan body).
//

import SwiftUI
import SwiftData

public struct ClusterSubRepChipRow: View {
    @Bindable public var entry: SetEntry

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 4) {                                                    // UI-SPEC xs
            Text("Sub-reps:")                                                   // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(entry.clusterSubReps.enumerated()), id: \.offset) { _, reps in
                Text("\(reps)")
                    .font(.caption)
                    .padding(.horizontal, 8)                                    // UI-SPEC sm
                    .padding(.vertical, 4)                                      // UI-SPEC xs
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            Button {
                addSubRep()
            } label: {
                Text("+")                                                       // UI-SPEC verbatim
                    .font(.caption)
                    .padding(.horizontal, 8)                                    // UI-SPEC sm
                    .padding(.vertical, 4)                                      // UI-SPEC xs
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 4)                                                  // UI-SPEC xs
    }

    /// Appends a new sub-rep entry. Defaults to 1 — the chip-tap-to-edit
    /// cycle (so the user can bump to 2, 3, …) is explicitly deferred to
    /// Phase 6 polish per the plan body's anti-patterns callout.
    private func addSubRep() {
        var subs = entry.clusterSubReps
        subs.append(1)
        entry.clusterSubReps = subs
    }
}

#Preview("cluster sub-rep chip row") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.setTypeRaw = SetType.restPause.rawValue
    entry.clusterSubReps = [8, 3, 2]
    ctx.insert(entry)
    try? ctx.save()
    return ClusterSubRepChipRow(entry: entry)
        .modelContainer(container)
        .padding()
}
