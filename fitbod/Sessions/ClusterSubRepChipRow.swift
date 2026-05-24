// ClusterSubRepChipRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 41).
// UI-SPEC v2 § Session logger line 384 + 349.
//
// Rest-pause sub-rep chip row (SESS-08). Renders only when the set's
// setType == .restPause (cluster / rest-pause set type).
//
// UI-SPEC verbatim:
//   Leading label:  "SUB-REPS:"  (labelSmall 10pt, 1.2 letterspacing)
//   Chips:          1pt bruInk-outlined Rectangle (NOT a Capsule — UI-SPEC line 349)
//   Trailing "+":   1pt bruSignal stroke + bruSignal text per UI-SPEC line 384 + 257
//
// BRU contract:
//   NO capsule shape — explicitly banned per UI-SPEC line 349
//   NO RoundedRectangle / NO accentColor / NO Color(.system*)
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)

import SwiftUI
import SwiftData

public struct ClusterSubRepChipRow: View {
    @Bindable public var entry: SetEntry

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 4) {
            // Leading section label per UI-SPEC line 384
            Text("SUB-REPS:")                                                       // UI-SPEC verbatim
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            // Per-index sub-rep chips — Rectangle-outlined, NOT Capsule (UI-SPEC line 349)
            ForEach(Array(entry.clusterSubReps.enumerated()), id: \.offset) { idx, reps in
                Text("\(reps)")
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(minHeight: 32)
                    .overlay(
                        Rectangle()
                            .stroke(Color.bruInk, lineWidth: 1)
                    )
            }

            // Trailing "+" add-chip — bruSignal outline + text per UI-SPEC line 384 + 257
            Button {
                addSubRep()
            } label: {
                Text("+")                                                           // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruSignal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(minHeight: 32)
                    .overlay(
                        Rectangle()
                            .stroke(Color.bruSignal, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Appends a new sub-rep entry. Defaults to 1 — chip-tap-to-edit deferred to Phase 6.
    private func addSubRep() {
        var subs = entry.clusterSubReps
        subs.append(1)
        entry.clusterSubReps = subs
    }
}

#if DEBUG
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
        .background(Color.bruPaper)
}
#endif
