//
//  ExerciseDTO.swift
//  fitbod
//
//  Decoded shape of one row from `yuhonas/free-exercise-db/dist/exercises.json`.
//  Plain `Codable` struct — NOT a `@Model` (PITFALLS #2: keep `Codable` off
//  SwiftData entity types; the `@ModelActor` importer in plan 02-02 reads
//  `[ExerciseDTO]` and writes `@Model Exercise` rows).
//
//  Schema verified against vendored snapshot at
//  `fitbod/Resources/ExerciseSeed/exercises.json` (SOURCE.md pins the upstream
//  commit). All 11 fields match the upstream `schema.json`.
//

import Foundation

/// One row decoded from `exercises.json`. Plain value type, threadsafe,
/// reused across DTODecodingTests + ExerciseLibraryImporter (plan 02-02).
public struct ExerciseDTO: Codable, Equatable, Sendable {
    /// e.g. "Barbell_Bench_Press" — slug used as `Exercise.externalID`.
    public let id: String
    /// Display name, e.g. "Barbell Bench Press".
    public let name: String
    /// "static" | "pull" | "push" | nil — maps to `Force` enum.
    public let force: String?
    /// "beginner" | "intermediate" | "expert" — maps to `Level` enum.
    public let level: String
    /// "isolation" | "compound" | nil — maps to `Mechanic` enum.
    public let mechanic: String?
    /// 12+ raw values; canonical mapping lives in `EquipmentMapper.map(_:)`.
    public let equipment: String?
    /// Subset of 17 muscle slugs; primary contributors.
    public let primaryMuscles: [String]
    /// Subset of 17 muscle slugs; secondary contributors.
    public let secondaryMuscles: [String]
    /// Free-text steps; plan 02-02 joins these into `Exercise.instructionsText`.
    public let instructions: [String]
    /// "strength" | "powerlifting" | "olympic weightlifting" | "strongman" |
    /// "cardio" | "stretching" | "plyometrics" — v1 filters to first 4 only.
    public let category: String
    /// Relative paths within upstream's `exercises/` image bundle.
    /// v1 does NOT vendor the binary images, but the path strings persist
    /// to `Exercise.imagePaths` for a future image-bundling phase
    /// (CONTEXT.md Area 1 — "no images bundled v1" decision).
    public let images: [String]

    public init(
        id: String,
        name: String,
        force: String? = nil,
        level: String,
        mechanic: String? = nil,
        equipment: String? = nil,
        primaryMuscles: [String] = [],
        secondaryMuscles: [String] = [],
        instructions: [String] = [],
        category: String,
        images: [String] = []
    ) {
        self.id = id
        self.name = name
        self.force = force
        self.level = level
        self.mechanic = mechanic
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
        self.category = category
        self.images = images
    }
}
