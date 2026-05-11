//
//  Level.swift
//  fitbod
//
//  Difficulty hint sourced from yuhonas/free-exercise-db. Nullable —
//  the dataset includes rows without a level set, and custom exercises
//  default to unspecified.
//
//  Persisted as `levelRaw: String?` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Level: String, CaseIterable, Sendable {
    case beginner
    case intermediate
    case expert
}
