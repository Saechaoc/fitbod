//
//  SchemaV5.swift
//  fitbod
//
//  The Phase 4 schema wrapper. Additive successor to SchemaV4 (which
//  Phase 3.1 locked for the PIVOT-03 session-level intent /
//  progression reshape). V5's delta:
//
//    - `Block.reviewedAt: Date? = nil` ADDED (D-26 / D-21).
//
//  Per Phase 4 CONTEXT.md D-26: the original plan was to ship
//  `Block.reviewedAt` inside SchemaV3 (Phase 3 in flight at that
//  time). Phase 3 sealed SchemaV3 lightweight; Phase 3.1 sealed
//  SchemaV4 with the PIVOT-03 custom migration. Phase 4 therefore
//  stacks SchemaV5 on top of V4 as the canonical home for
//  `Block.reviewedAt`.
//
//  Why lightweight is sufficient here: the delta is a single new
//  Optional<Date> field with a `nil` default on an existing @Model.
//  SwiftData's lightweight migration handles additive optional fields
//  without a custom willMigrate closure
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight].
//  The closure-based V3→V4 stage exists ONLY because that stage
//  removes fields AND moves values between entities; neither applies
//  here.
//
//  Why typealiases instead of nested @Model classes: the same
//  rationale as SchemaV4 — the production runtime IS V5, and the
//  V4→V5 stage adds a field without removing any. No nested type
//  needed for the willMigrate closure (there isn't one).
//
//  Version identifier:
//    5.0.0 = Phase 4 schema delta (Block.reviewedAt — end-of-block
//             review timestamp).
//

import Foundation
import SwiftData

public enum SchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    // MARK: - Typealiases to top-level production types

    public typealias Exercise = fitbod.Exercise
    public typealias MuscleGroup = fitbod.MuscleGroup
    public typealias ExerciseMuscleStimulus = fitbod.ExerciseMuscleStimulus
    public typealias Routine = fitbod.Routine
    public typealias RoutineExercise = fitbod.RoutineExercise
    public typealias Session = fitbod.Session
    public typealias SessionExercise = fitbod.SessionExercise
    public typealias SetEntry = fitbod.SetEntry
    public typealias Block = fitbod.Block
    public typealias BlockPhase = fitbod.BlockPhase
    public typealias UserSettings = fitbod.UserSettings
    public typealias MuscleVolumeTarget = fitbod.MuscleVolumeTarget
    public typealias RoutineFolder = fitbod.RoutineFolder
    public typealias SupersetGroup = fitbod.SupersetGroup
    public typealias RoutineExerciseSetOverride = fitbod.RoutineExerciseSetOverride
    public typealias PlateInventory = fitbod.PlateInventory

    public static var models: [any PersistentModel.Type] {
        [
            Self.Exercise.self,
            Self.MuscleGroup.self,
            Self.ExerciseMuscleStimulus.self,
            Self.Routine.self,
            Self.RoutineExercise.self,
            Self.Session.self,
            Self.SessionExercise.self,
            Self.SetEntry.self,
            Self.Block.self,
            Self.BlockPhase.self,
            Self.UserSettings.self,
            Self.MuscleVolumeTarget.self,
            Self.RoutineFolder.self,
            Self.SupersetGroup.self,
            Self.RoutineExerciseSetOverride.self,
            Self.PlateInventory.self,
        ]
    }
}
