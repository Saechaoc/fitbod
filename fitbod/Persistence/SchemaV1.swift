//
//  SchemaV1.swift
//  fitbod
//
//  The load-bearing Day-1 schema wrapper (FOUND-01 / PITFALLS #2).
//
//  Every `@Model` type owned by the app is listed here exactly once.
//  `ModelContainer` consumes `Schema(SchemaV1.models)` (see `fitbodApp.swift`)
//  and `FitbodSchemaMigrationPlan` keeps a single `[SchemaV1.self]` schema
//  list so future SchemaV2/V3 migrations have somewhere to slot in.
//
//  Cost of skipping per PITFALLS.md #2: the first time we rename or split a
//  model in a future phase, SwiftData refuses to open the existing store and
//  the only recovery is wiping the database. This file pays that bill
//  permanently — even with an empty `stages` migration plan, the wrapper is
//  the non-negotiable piece.
//
//  Version identifier matches semantic-version intent:
//    1.0.0 = initial 12-entity schema shipped in Phase 1.
//

import SwiftData

public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Routine.self,
            RoutineExercise.self,
            Session.self,
            SessionExercise.self,
            SetEntry.self,
            Block.self,
            BlockPhase.self,
            UserSettings.self,
            MuscleVolumeTarget.self,
        ]
    }
}
