//
//  WeightUnit.swift
//  fitbod
//
//  SET-01 anchor: pounds vs kilograms. Display-only toggle —
//  history is stored in a single canonical unit and re-rendered on the fly.
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
