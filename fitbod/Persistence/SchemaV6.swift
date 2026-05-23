//
//  SchemaV6.swift
//  fitbod
//
//  Phase 5 schema wrapper — additive successor to SchemaV5 (which Phase 4
//  shipped with `Block.reviewedAt`). SchemaV6's delta is 8 additive fields
//  on 4 existing entities and one default-bump that requires a custom
//  willMigrate:
//
//    UserSettings:
//      - frequencyHitMinSets:           Int   = 2       (D-03, additive)
//      - deloadAdvisoryDismissedWeekStart: Date? = nil  (D-17, additive)
//      - weeklyRecapShownForWeekStart:  Date? = nil     (VOL-07, additive)
//      - plateauTolerance default       0.005 → 0.02    (D-12, RETROACTIVE
//          via custom willMigrate — the @Model default change only affects
//          NEWLY-inserted rows, so existing rows need an explicit bump)
//
//    Exercise:
//      - plateauWindowOverride:    Int?    = nil   (SET-06, additive)
//      - plateauToleranceOverride: Double? = nil   (SET-06, additive)
//
//    ExerciseMuscleStimulus:
//      - userEditedWeight: Bool = false  (VOL-01 idempotency flag, additive)
//
//    MuscleVolumeTarget:
//      - userEdited:       Bool = false  (VOL-03 / SET-05 idempotency, additive)
//
//  Entity catalog is unchanged from V5 (no new @Model types). Lightweight
//  migration is sufficient for the additive fields; the plateauTolerance
//  default bump needs a custom willMigrate closure because lightweight
//  migration does NOT rewrite existing rows on a `@Model` default change.
//  Per CONTEXT.md D-12 + RESEARCH §9.2 / §9.3.
//
//  Why typealiases instead of nested @Model classes: same rationale as
//  SchemaV4 / SchemaV5 — the production runtime IS V6, and the V5→V6
//  stage only adds fields and bumps a default. No nested type needed for
//  the willMigrate closure (it operates directly on UserSettings rows
//  via the typealias).
//
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
//

import Foundation
import SwiftData

public enum SchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

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
        SchemaV5.models
    }
}
