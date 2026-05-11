//
//  BlockPhaseKind.swift
//  fitbod
//
//  The phase a periodization block is in: accumulation, intensification,
//  realization, or deload. Drives `BlockPeriodizedStrategy` (Phase 3) and
//  `PeriodizationEngine` (Phase 4).
//
//  Persisted as `nameRaw: String` on `BlockPhase`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum BlockPhaseKind: String, CaseIterable, Sendable {
    case accumulation
    case intensification
    case realization
    case deload

    public static let `default`: BlockPhaseKind = .accumulation
}
