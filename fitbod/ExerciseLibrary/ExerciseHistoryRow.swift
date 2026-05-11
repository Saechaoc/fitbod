//
//  ExerciseHistoryRow.swift
//  fitbod
//
//  Wave-5 plan 05-01 — one row in the per-exercise history list. Each
//  row corresponds to a single committed `SetEntry`. Rendered inside
//  the date-grouped `Section` blocks of `ExerciseHistoryView`'s inner
//  `FilteredHistoryList`.
//
//  ## Visual contract (UI-SPEC § Exercise history view)
//
//  - Top line (small): the workout's `routineSnapshotName` in
//    `.caption .secondaryLabel` — matches the UI-SPEC row format
//    "(top) workout name, (bottom) primary line". This is the only
//    place the user sees which routine produced the set without
//    drilling further.
//  - Primary line (body): "{weight} × {reps} @ RPE {N}" — verbatim per
//    UI-SPEC. Weight renders as integer when an integer (175, not
//    175.0); decimal weights render with one digit (177.5). RPE
//    suppresses to "{w} × {r}" when the set didn't record one.
//  - Trailing intent badge: a quiet capsule (UI-SPEC explicit — "inline
//    intent badges below are quiet") in `Color(.systemGray6)` fill with
//    `.label` foreground. Only the SELECTED filter chip up top uses
//    accent; the inline badges do not.
//
//  ## Why receive both SetEntry and SessionExercise?
//
//  The set tells us weight/reps/RPE. The session-exercise tells us the
//  parent session (for the routine-snapshot name) and the intent (for
//  the inline badge). Passing both avoids the row having to traverse
//  optional relationships at render time — the parent view's grouping
//  logic already has both objects in hand.
//

import SwiftUI

public struct ExerciseHistoryRow: View {
    public let setEntry: SetEntry
    public let sessionExercise: SessionExercise

    public init(setEntry: SetEntry, sessionExercise: SessionExercise) {
        self.setEntry = setEntry
        self.sessionExercise = sessionExercise
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {                             // UI-SPEC xs
            Text(sessionExercise.session?.routineSnapshotName ?? "Workout")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(primaryLine)
                    .font(.body)
                Spacer()
                intentChip
            }
        }
        .padding(.vertical, 8)                                                // UI-SPEC sm
    }

    /// UI-SPEC verbatim: "175 × 8 @ RPE 8" — RPE clause suppressed when
    /// the set didn't record one ("175 × 8"). Weight without fractional
    /// part renders as integer; weights with a fractional part render
    /// with one decimal digit (e.g. 177.5).
    private var primaryLine: String {
        let w = setEntry.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(setEntry.weight))"
            : String(format: "%.1f", setEntry.weight)
        if let rpe = setEntry.rpe {
            // Render integer RPE without ".0"; render decimal RPE with one digit.
            let rpeText: String
            if rpe.truncatingRemainder(dividingBy: 1) == 0 {
                rpeText = "\(Int(rpe))"
            } else {
                rpeText = String(format: "%.1f", rpe)
            }
            return "\(w) × \(setEntry.reps) @ RPE \(rpeText)"
        } else {
            return "\(w) × \(setEntry.reps)"
        }
    }

    /// The inline intent badge. UI-SPEC: capsule in `Color(.systemGray6)`
    /// fill with `.caption .semibold` label in `.label` color. NOT
    /// accent — only the selected filter chip uses accent.
    private var intentChip: some View {
        Text(sessionExercise.intentRaw.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))                                  // UI-SPEC: quiet inline badge
            .foregroundStyle(.primary)
            .clipShape(Capsule())
    }
}
