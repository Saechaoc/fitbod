//
//  MuscleRegion.swift
//  fitbod
//
//  Coarse anatomical bucket used by the muscle heatmap (Phase 5) for grouping
//  the 17 free-exercise-db muscles into upper / lower / core regions.
//
//  Persisted as `regionRaw: String` on `MuscleGroup`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum MuscleRegion: String, CaseIterable, Sendable {
    case upper
    case lower
    case core

    public static let `default`: MuscleRegion = .upper
}
