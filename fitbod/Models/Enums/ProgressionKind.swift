//
//  ProgressionKind.swift
//  fitbod
//
//  Selects which ProgressionStrategy implementation (Phase 3) computes the
//  prescribed weight for the next session of a given exercise.
//
//  Persisted as `progressionKindRaw: String` on `RoutineExercise`,
//  `SessionExercise`, and `UserSettings.defaultProgressionKindRaw`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum ProgressionKind: String, CaseIterable, Sendable {
    case rpe
    case double
    case block
    case hybrid

    public static let `default`: ProgressionKind = .double
}
