//
//  PrescriptionDefaults.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the ROUTINE-09 mechanic/equipment heuristic.
//  When a brand-new `RoutineExerciseDraft` is appended to a `RoutineDraft`
//  by the routine builder (via `RoutineDraft.append(exercise:)`), this
//  enum populates the draft's prescription fields per CONTEXT.md Area 1:
//
//    - Compound mechanic → rest 180s
//    - Isolation mechanic → rest 90s
//    - Barbell + compound → strength-style rep range (4–6 reps @ RPE 8)
//    - Otherwise → hypertrophy-style rep range (8–12 reps @ RPE 8)
//
//  The heuristic is intentionally minimal — it's just a "good first guess"
//  that the user can immediately edit in the prescription editor.
//
//  ## Phase 3.1 PIVOT-04
//
//  The pre-Phase-3.1 implementation also wrote `draft.intent` and
//  `draft.progressionKind` (per-exercise) here. Those fields moved to
//  `RoutineDraft` (per-routine) in Plan 04; the writes are gone. The
//  rep-range heuristic stays per-exercise because target reps remain
//  a per-exercise concept — only the session-level Intent +
//  Progression hoisted out.
//
//  Pure value-type logic — no `ModelContainer`, no SwiftData. Pulled into
//  its own file so the heuristic is testable in isolation
//  (`PrescriptionDefaultsTests`).
//

import Foundation

public enum PrescriptionDefaults {

    /// Apply the mechanic/equipment heuristic to a freshly-added
    /// `RoutineExerciseDraft` per ROUTINE-09 + CONTEXT.md Area 1.
    ///
    /// - Compound → rest 180s, isolation → rest 90s.
    /// - Barbell + compound → strength-style rep range (4–6 reps).
    /// - Otherwise → hypertrophy-style rep range (8–12 reps).
    /// - Target RPE defaults to 8.0.
    ///
    /// Phase 3.1 PIVOT-04: this helper no longer writes per-exercise
    /// `intent` or `progressionKind` — those fields are gone from
    /// `RoutineExerciseDraft`. The session-level Intent + Progression
    /// live on the parent `RoutineDraft`.
    @MainActor
    public static func apply(to draft: RoutineExerciseDraft, from exercise: Exercise) {
        let isCompound = exercise.mechanic == .compound
        let isBarbell = exercise.equipment == .barbell

        draft.prescribedRestSeconds = isCompound ? 180 : 90

        if isCompound && isBarbell {
            draft.targetRepsLow = 4
            draft.targetRepsHigh = 6
            draft.targetRPE = 8.0
        } else {
            draft.targetRepsLow = 8
            draft.targetRepsHigh = 12
            draft.targetRPE = 8.0
        }
    }
}
