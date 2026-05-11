//
//  Intent.swift
//  fitbod
//
//  Training intent for a prescribed exercise. Drives progression algorithm
//  selection (RPE table vs double-progression), rep-range defaults, and the
//  intent-split history charts surfaced in Phase 4 progress views.
//
//  Persisted as `intentRaw: String` on `RoutineExercise` and `SessionExercise`
//  (FOUND-03 / PITFALLS #9 — *Raw: String convention).
//

import Foundation

public enum Intent: String, CaseIterable, Sendable {
    case strength
    case hypertrophy
    case power
    case endurance
    case technique

    public static let `default`: Intent = .hypertrophy
}
