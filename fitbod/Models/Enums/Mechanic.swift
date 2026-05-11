//
//  Mechanic.swift
//  fitbod
//
//  Compound vs isolation. Drives the "first compound of session" warmup
//  ramp (Phase 3) and the volume-weighting heuristic.
//
//  Persisted as `mechanicRaw: String` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Mechanic: String, CaseIterable, Sendable {
    case compound
    case isolation

    public static let `default`: Mechanic = .compound
}
