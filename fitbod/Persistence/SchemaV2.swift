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
//  CR-01 (Phase 7 review): like SchemaV1, SchemaV2 must NOT reference the
//  V7-renamed `SessionTemplate` / `SessionExerciseTemplate` production types
//  — a V2-version on-disk store records its template entities as `Routine` /
//  `RoutineExercise`. SchemaV2 declares its own nested @Model classes with
//  the V2 on-disk shape (Routine + `folderID`; RoutineExercise +
//  `supersetGroupID` / `tracksTempo` / `tracksPartialReps` / `setOverrides`).
//  `String(describing:)` resolves these to `"Routine"` / `"RoutineExercise"`
//  — identical to SchemaV1's nested names — so the additive-superset
//  assertion in SchemaV2MigrationTests (V2 \ V1 == the 3 new entities) holds.
//

import Foundation
import SwiftData

public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            // V1 inheritors — same identity, additive fields landed in plan 00-01.
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Self.Routine.self,            // V2 on-disk entity + folderID (renamed to SessionTemplate in V7)
            Self.RoutineExercise.self,    // V2 on-disk entity + superset/track/setOverrides (renamed to SessionExerciseTemplate in V7)
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

// MARK: - Nested V2-shape @Model classes (migration ancestor only)
// Mirror the V2 on-disk shapes of Routine / RoutineExercise. Same rules as
// SchemaV1 / SchemaV3 / SchemaV6 nested types:
//  - Inverse keypaths use the NESTED form (Routine↔RoutineExercise).
//  - The `setOverrides` cascade omits its inverse — it points at the
//    top-level production `RoutineExerciseSetOverride`, a cross-schema
//    reference the migration never traverses from the nested side.
//  - #Index intentionally omitted (macro can't see through the enum namespace).
//  - NOT in SchemaV7.models — migration scaffolding only.

extension SchemaV2 {

    /// V2-shape Routine — V1 shape + `folderID` (plan 00-01 additive). Still
    /// no parent-level `intentRaw` / `progressionKindRaw` (V4 addition).
    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false
        public var block: Block? = nil
        public var folderID: UUID? = nil   // NEW in V2

        @Relationship(deleteRule: .cascade, inverse: \SchemaV2.RoutineExercise.routine)
        public var exercises: [SchemaV2.RoutineExercise]? = []

        public init() {}
    }

    /// V2-shape RoutineExercise — V1 shape + `supersetGroupID` /
    /// `tracksTempo` / `tracksPartialReps` / `setOverrides` (plan 00-01
    /// additive). Retains per-exercise `intentRaw` / `progressionKindRaw`
    /// (not removed until V4).
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routine: SchemaV2.Routine? = nil
        public var exercise: Exercise? = nil
        public var orderIndex: Int = 0

        public var intentRaw: String = "hypertrophy"
        public var targetSets: Int = 3
        public var targetRepsLow: Int = 8
        public var targetRepsHigh: Int = 12
        public var targetRPE: Double? = nil
        public var targetRIR: Int? = nil
        public var prescribedRestSeconds: Int = 120
        public var tempo: String? = nil
        public var notes: String? = nil
        public var progressionKindRaw: String = "double"
        public var generateWarmups: Bool = false
        public var supersetGroupID: UUID? = nil      // NEW in V2
        public var tracksTempo: Bool = false         // NEW in V2
        public var tracksPartialReps: Bool = false   // NEW in V2
        public var warmupOverrideData: Data? = nil

        /// Inverse omitted — points at top-level production
        /// `RoutineExerciseSetOverride` (cross-schema; never traversed here).
        @Relationship(deleteRule: .cascade)
        public var setOverrides: [RoutineExerciseSetOverride]? = []   // NEW in V2

        public init() {}
    }
}
