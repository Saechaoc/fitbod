//
//  Equipment.swift
//  fitbod
//
//  LIB-06 anchor: the equipment facet for the exercise library filter.
//  Nine cases: the eight from LIB-06 plus `kettlebell` (RESEARCH Open Q #4 —
//  added now to avoid a Phase 2 migration).
//
//  Persisted as `equipmentRaw: String` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Equipment: String, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bands
    case bodyweight
    case weightedBodyweight = "weighted_bodyweight"
    case kettlebell
    case other

    public static let `default`: Equipment = .other
}
