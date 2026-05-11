//
//  SetType.swift
//  fitbod
//
//  Set classification: warmup, working, drop, failure, rest_pause. Added in
//  Phase 1 (not strictly used until Phase 2's session logger) to keep the
//  schema locked Day 1 and avoid a Phase 2 migration.
//
//  Persisted as `setTypeRaw: String` on `SetEntry`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum SetType: String, CaseIterable, Sendable {
    case warmup
    case working
    case drop
    case failure
    case restPause = "rest_pause"

    public static let `default`: SetType = .working
}
