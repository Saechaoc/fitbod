//
//  SchemaV4.swift
//  fitbod
//
//  The Phase 3.1 schema wrapper. Represents the post-PIVOT-03 shape:
//    - `Routine.intentRaw` / `Routine.progressionKindRaw` ADDED (Plan 02)
//    - `Session.intentRaw` / `Session.progressionKindRaw` ADDED (Plan 02)
//    - `RoutineExercise.intentRaw` / `RoutineExercise.progressionKindRaw`
//      REMOVED (Plan 02)
//    - `SessionExercise.intentRaw` / `SessionExercise.progressionKindRaw`
//      REMOVED (Plan 02)
//
//  Per the BLOCKER 3 architecture decision (see SchemaV3.swift's header
//  comment for the full rationale), V3 declares NESTED standalone @Model
//  classes for the four entities with a V3↔V4 field delta; V4 declares
//  TYPEALIASES to the top-level production @Model classes for ALL 16
//  entities — including those four.
//
//  At Plan 01 commit time (this file's introduction), the top-level
//  production types still carry their V3 shape — Plan 02 reshapes them.
//  So the typealiases here resolve to V3-shape types initially, then
//  automatically reflect V4 shape after Plan 02 lands. This file does
//  not need to be edited when Plan 02 reshapes the production models.
//
//  Why typealiases instead of nested @Model classes here too: the
//  production code (RoutineDraft, SessionFactory, every view) reads
//  and writes the top-level production types directly — that's the
//  canonical runtime surface. V4 IS the production runtime, so the
//  typealiased identity is correct. Only V3 needs the nested types,
//  because V3 represents an outdated on-disk shape that the migration
//  closure reads from but no production runtime code touches.
//
//  Apple documentation reference:
//    - WWDC23 "Migrate to SwiftData"
//    - developer.apple.com/documentation/swiftdata/migrationstage/custom
//    - developer.apple.com/documentation/swiftdata/versionedschema
//
//  Version identifier matches semantic-version intent:
//    4.0.0 = Phase 3.1 schema delta (PIVOT-01..03 — session-level intent
//             and progression).
//

import Foundation
import SwiftData

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

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
