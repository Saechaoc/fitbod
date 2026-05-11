//
//  SchemaV2.swift
//  fitbod
//
//  The Phase 2 schema wrapper. Aggregates the 12 entities inherited
//  unchanged from SchemaV1 plus the 3 new entities introduced by
//  plan 00-01 (`RoutineFolder`, `SupersetGroup`,
//  `RoutineExerciseSetOverride`).
//
//  Every delta against SchemaV1 is *additive*:
//    - New entity types (RoutineFolder / SupersetGroup /
//      RoutineExerciseSetOverride)
//    - New default-valued properties on existing entities
//      (Routine.folderID, RoutineExercise.supersetGroupID /
//      tracksTempo / tracksPartialReps / setOverrides cascade,
//      SessionExercise.pinnedNote, SetEntry.partialReps /
//      clusterSubRepsJoined / isComplete)
//
//  Per RESEARCH § Pattern 4 + Apple's docs, additive-only deltas are
//  explicitly eligible for `MigrationStage.lightweight(fromVersion:
//  toVersion:)`. The migration stage itself is registered in
//  `FitbodSchemaMigrationPlan`; this file is just the entity catalog.
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
//
//  Version identifier matches semantic-version intent:
//    2.0.0 = Phase 2 schema delta (3 new entities + 8 additive fields).
//
//  Ordering: the first 12 entries mirror `SchemaV1.models` line-for-line
//  so a side-by-side diff against SchemaV1.swift highlights only the 3
//  appended types. The order is not load-bearing for SwiftData but is
//  load-bearing for diff readability.
//

import SwiftData

public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            // V1 inheritors — same identity, additive fields landed in plan 00-01.
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Routine.self,                 // + folderID
            RoutineExercise.self,         // + supersetGroupID / tracksTempo / tracksPartialReps / setOverrides
            Session.self,
            SessionExercise.self,         // + pinnedNote
            SetEntry.self,                // + partialReps / clusterSubRepsJoined / isComplete
            Block.self,
            BlockPhase.self,
            UserSettings.self,
            MuscleVolumeTarget.self,
            // NEW in V2 (plan 00-01).
            RoutineFolder.self,
            SupersetGroup.self,
            RoutineExerciseSetOverride.self,
        ]
    }
}
