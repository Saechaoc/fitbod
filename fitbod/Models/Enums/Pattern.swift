//
//  Pattern.swift
//  fitbod
//
//  Movement pattern classification (horizontal push, vertical pull, squat,
//  hinge, lunge, carry, core). Nullable in Phase 1 per Open Question #5:
//  `patternRaw` is left nil at seed time and curated in a later phase.
//
//  Persisted as `patternRaw: String?` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Pattern: String, CaseIterable, Sendable {
    case horizontalPush = "horizontal_push"
    case verticalPush = "vertical_push"
    case horizontalPull = "horizontal_pull"
    case verticalPull = "vertical_pull"
    case squat
    case hinge
    case lunge
    case carry
    case core
}
