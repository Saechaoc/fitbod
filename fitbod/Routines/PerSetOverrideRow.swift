//
//  PerSetOverrideRow.swift
//  fitbod
//
//  Wave-3 plan 03-02 — one sub-row inside the prescription editor's
//  "Per-set overrides" disclosure. Renders the override's "Set {N}"
//  leading label and trailing inputs for the override's reps range +
//  RPE. Bound to a `@Bindable PerSetOverrideDraft`.
//
//  Phase 2 trade-off: the override inputs use `Int?` / `Double?` so the
//  user can leave any field blank (the snapshot falls back to the
//  parent RoutineExercise's defaults at session-start time, plan
//  04-01). The "blank" sentinel for the TextFields is `0` — a value
//  of 0 in any field is interpreted as `nil` and the override falls
//  through to the parent defaults. This keeps the TextField inputs
//  simple at the cost of disallowing literal 0 — an acceptable
//  trade-off for a routine builder (zero reps / zero RPE is never a
//  valid prescription).
//
//  Swipe-to-delete is wired by the parent prescription editor (the
//  delete-row destructive swipe; no extra confirmation per UI-SPEC).
//

import SwiftUI

public struct PerSetOverrideRow: View {
    @Bindable public var draft: PerSetOverrideDraft

    public init(draft: PerSetOverrideDraft) {
        self.draft = draft
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text("Set \(draft.setIndex + 1)")
                .font(.caption)
                .frame(width: 56, alignment: .leading)

            Spacer(minLength: 0)

            // Reps range two-field.
            TextField(
                "low",
                value: Binding(
                    get: { draft.targetRepsLow ?? 0 },
                    set: { draft.targetRepsLow = $0 == 0 ? nil : $0 }
                ),
                format: .number
            )
            .frame(width: 40)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)

            Text("–")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "high",
                value: Binding(
                    get: { draft.targetRepsHigh ?? 0 },
                    set: { draft.targetRepsHigh = $0 == 0 ? nil : $0 }
                ),
                format: .number
            )
            .frame(width: 40)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)

            // RPE single value (the override is a per-set point estimate,
            // not a range; range comes from the parent RoutineExercise
            // and the override pin-points one set inside that range).
            TextField(
                "RPE",
                value: Binding(
                    get: { draft.targetRPE ?? 0 },
                    set: { draft.targetRPE = $0 == 0 ? nil : $0 }
                ),
                format: .number.precision(.fractionLength(0...1))
            )
            .frame(width: 48)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }
}
