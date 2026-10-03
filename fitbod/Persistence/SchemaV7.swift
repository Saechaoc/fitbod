//
//  SchemaV7.swift
//  fitbod
//
//  BASELINE SCHEMA. This is the only VersionedSchema in the app.
//
//  Schema history (SchemaV1-V6 and FitbodSchemaMigrationPlan) was
//  intentionally reset on 2026-10-02: the app has a single user and no
//  production data, and the frozen historical schemas were fragile (they
//  referenced live types and crashed on launch for pre-V7 stores). The type
//  keeps the name `SchemaV7` so existing V7 stores still match.
//
//  The container is built from this schema WITHOUT a migration plan (see
//  `FitbodModelContainer`). Additive changes (new optional or defaulted
//  attributes, new entities) migrate automatically in place. A store SwiftData
//  cannot open is moved aside into `IncompatibleStores/<timestamp>/` and a
//  fresh store is created.
//
//  `models` is an explicit list of all 18 production types.
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

    // MARK: - Explicit models array (18 production types)

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
