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
//    - Barbell + compound → strength intent (4–6 reps @ RPE 8, double prog.)
//    - Otherwise → hypertrophy intent (8–12 reps @ RPE 8, double prog.)
//
//  The heuristic is intentionally minimal — it's just a "good first guess"
//  that the user can immediately edit in the prescription editor. No
//  attempt is made to vary RPE or progression kind by equipment; the
//  builder's intent picker / progression picker exposes the full surface.
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
    /// - Barbell + compound → strength intent (4–6 reps).
    /// - Otherwise → hypertrophy intent (8–12 reps).
    /// - Target RPE defaults to 8.0; progression defaults to `.double`.
    @MainActor
    public static func apply(to draft: RoutineExerciseDraft, from exercise: Exercise) {
        let isCompound = exercise.mechanic == .compound
        let isBarbell = exercise.equipment == .barbell

        draft.prescribedRestSeconds = isCompound ? 180 : 90

        if isCompound && isBarbell {
            draft.intent = .strength
            draft.targetRepsLow = 4
            draft.targetRepsHigh = 6
            draft.targetRPE = 8.0
            draft.progressionKind = .double
        } else {
            draft.intent = .hypertrophy
            draft.targetRepsLow = 8
            draft.targetRepsHigh = 12
            draft.targetRPE = 8.0
            draft.progressionKind = .double
        }
    }
}
