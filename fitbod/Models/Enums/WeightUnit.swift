//
//  WeightUnit.swift
//  fitbod
//
//  SET-01 anchor: pounds vs kilograms. A display label only: weights are
//  stored exactly as entered and never converted, so switching the unit
//  relabels existing numbers rather than recomputing them. An exercise's
//  `unitOverride` wins over the app-wide unit for that exercise.
//
//  Persisted as `unitsRaw: String` on `UserSettings`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum WeightUnit: String, CaseIterable, Sendable {
    case lb
    case kg

    public static let `default`: WeightUnit = .lb
}
