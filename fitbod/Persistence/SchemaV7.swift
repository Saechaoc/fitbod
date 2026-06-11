//
//  SchemaV7.swift
//  fitbod
//
//  Phase 7 schema wrapper — entity-rename + program-graph successor to
//  SchemaV6 (Phase 5). SchemaV7's delta:
//
//  Renames (custom stage, entity-level row copy via willMigrate/didMigrate):
//    - Routine             → SessionTemplate
//    - RoutineExercise     → SessionExerciseTemplate
//    - Session.template:     renamed relationship (was soft UUID)
//
//  New entities:
//    - Split              (periodization split bundling sessions; new table)
//    - SplitSessionSlot   (ordered join row — split × session template × position)
//
//  Block field additions (additive; handled by custom stage):
//    - split: Split?               (nil while draft; nullify on split hard-delete)
//    - schedulingModeRaw: String   ("rotation" | "fixedWeekly", default "rotation")
//    - trainingDaysJoined: String  (join-to-String [Int] accessor; default "")
//    - archivedConfigJSON: String? (freeze #2 — written once at block end)
//
//  Session field additions (additive; handled by custom stage):
//    - template: SessionTemplate?  (replaces soft sourceRoutineID)
//    - slot: SplitSessionSlot?     (which slot launched this workout; nil = ad-hoc)
//    - templateName: String?       (log-time name snapshot — freeze #1 insurance)
//
//  IMPORTANT: `models` is an EXPLICIT array of all 18 production types —
//  NOT a passthrough to SchemaV6.models. SchemaV6 is expanded for migration
//  (nested Routine/RoutineExercise types) and must NOT appear in the V7
//  production container. Passthrough here would silently include those
//  migration-only nested types (Pitfall 4 from RESEARCH.md).
//
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
//

import Foundation
import SwiftData

public enum SchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)

    // MARK: - Typealiases to top-level production types
    // V7 renames — new canonical names

    public typealias SessionTemplate = fitbod.SessionTemplate
    public typealias SessionExerciseTemplate = fitbod.SessionExerciseTemplate
    public typealias Split = fitbod.Split
    public typealias SplitSessionSlot = fitbod.SplitSessionSlot

    // Unchanged entities

    public typealias Exercise = fitbod.Exercise
    public typealias MuscleGroup = fitbod.MuscleGroup
    public typealias ExerciseMuscleStimulus = fitbod.ExerciseMuscleStimulus
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

    // MARK: - Explicit models array (18 production types — do NOT use SchemaV6.models passthrough)
    // Order: V7 new/renamed types first, then unchanged from V6.

    public static var models: [any PersistentModel.Type] {
        [
            Self.SessionTemplate.self,
            Self.SessionExerciseTemplate.self,
            Self.Split.self,
            Self.SplitSessionSlot.self,
            Self.Exercise.self,
            Self.MuscleGroup.self,
            Self.ExerciseMuscleStimulus.self,
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
