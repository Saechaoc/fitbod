//
//  SeedError.swift
//  fitbod
//
//  Typed error surface for the `ExerciseLibraryImporter` (`@ModelActor`)
//  in plan 01-PLAN-02-02. The seed pipeline reads bundled resources,
//  decodes the upstream JSON via `ExerciseDTO`, and writes
//  `MuscleGroup` / `Exercise` / `ExerciseMuscleStimulus` rows; every
//  failure mode collapses onto one of these three cases so the caller
//  can branch on it (or log it as a `CustomStringConvertible`).
//
//  Conforms to `Sendable` so the error can cross the `@ModelActor`
//  isolation boundary back to the caller's `await` site without a
//  Swift 6 strict-concurrency warning.
//

import Foundation

/// Error cases raised by `ExerciseLibraryImporter.seedIfNeeded()`.
public enum SeedError: Error, CustomStringConvertible, Sendable {
    /// A required file is not present in `Bundle.main`. The seed
    /// short-circuits here rather than crashing with a force-unwrap;
    /// the importer's caller decides whether to surface a user-facing
    /// "library unavailable" state or abort launch.
    case bundledResourceMissing(name: String)

    /// `JSONDecoder.decode([ExerciseDTO].self, from:)` failed. The
    /// underlying `DecodingError` carries the JSON path that mismatched
    /// the DTO schema — useful when a future dataset bump silently
    /// changes a field name or type.
    case decodeFailed(underlying: Error)

    /// A muscle slug from the dataset does not resolve to a known
    /// canonical row (i.e., it is absent from `MuscleRegionMap.allSlugs`).
    /// Currently only emitted as a soft-warning code path; the seed
    /// continues by skipping the stimulus row for the unknown slug.
    case unexpectedMuscleSlug(String)

    public var description: String {
        switch self {
        case .bundledResourceMissing(let name):
            return "Bundled resource missing: \(name)"
        case .decodeFailed(let err):
            return "JSON decode failed: \(err)"
        case .unexpectedMuscleSlug(let slug):
            return "Unrecognized muscle slug in dataset: \(slug)"
        }
    }
}
