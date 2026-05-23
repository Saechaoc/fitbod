//
//  SchemaV3.swift
//  fitbod
//
//  The Phase 3 schema wrapper. Historically (plan 03-01 of Phase 3) this
//  file was a 3-line composition declaration:
//
//      public static var models: [any PersistentModel.Type] {
//          SchemaV2.models + [PlateInventory.self]
//      }
//
//  Phase 3.1 (PIVOT-01..03) reshapes the top-level production
//  Routine / Session / RoutineExercise / SessionExercise @Model classes:
//    - Routine and Session GAIN `intentRaw` and `progressionKindRaw`
//      (Plan 02 — session-level intent + progression).
//    - RoutineExercise and SessionExercise LOSE those fields.
//
//  `MigrationStage.custom(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)`
//  needs SwiftData to model BOTH the V3 on-disk shape (so the willMigrate
//  closure can read `RoutineExercise.intentRaw` and
//  `SessionExercise.intentRaw` from existing rows) AND the V4 in-memory
//  shape (so the same closure can write `Routine.intentRaw` and
//  `Session.intentRaw` on the migrated rows) — in the same context, at the
//  same time.
//
//  Apple's documented solution (WWDC23 "Migrate to SwiftData" +
//  developer.apple.com/documentation/swiftdata/migrationstage/custom):
//  declare namespaced @Model classes per VersionedSchema. Each
//  VersionedSchema owns its own type identity, even when the on-disk table
//  is the same physical entity.
//
//  Implementation here:
//    - SchemaV3 declares four NESTED standalone @Model classes
//      (`SchemaV3.Routine`, `SchemaV3.Session`, `SchemaV3.RoutineExercise`,
//      `SchemaV3.SessionExercise`) carrying the V3 on-disk shape verbatim.
//      RE/SE still have `intentRaw` + `progressionKindRaw` here; Routine
//      and Session don't.
//    - The other 12 entities (Exercise, MuscleGroup, ExerciseMuscleStimulus,
//      Block, BlockPhase, UserSettings, MuscleVolumeTarget, RoutineFolder,
//      SupersetGroup, RoutineExerciseSetOverride, SetEntry, PlateInventory)
//      stay referenced via their top-level production types because the
//      V3↔V4 delta is field-level on exactly those four entities.
//    - `SchemaV3.models` therefore mixes 4 nested types and 12 top-level
//      types (16 total).
//
//  Cross-references for the V3 nested types use the nested form
//  (`SchemaV3.RoutineExercise.routine` references `SchemaV3.Routine`) so
//  that both sides of a SwiftData inverse keypath remain in the same
//  VersionedSchema. Cross-schema references (e.g. the nested
//  `RoutineExercise.setOverrides` cascading to the top-level
//  `RoutineExerciseSetOverride`) deliberately omit the inverse declaration
//  on the nested side — the migration closure (Plan 01 / Plan 02 Task 2)
//  reads RE/SE field values directly and never traverses
//  `setOverrides` or `sets` reverse-side from the nested types.
//
//  Version identifier matches semantic-version intent:
//    3.0.0 = Phase 3 schema delta (1 new entity + 7 additive fields)
//             — the on-disk shape doesn't move because of this file's
//             rewrite; the rewrite is purely about how SwiftData models
//             it at compile time so the V3→V4 custom migration can
//             compile against both shapes.
//

import Foundation
import SwiftData

public enum SchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            // Top-level production types (entities with no V3↔V4 field delta).
            // Order mirrors SchemaV1.models for readability.
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Block.self,
            BlockPhase.self,
            UserSettings.self,
            MuscleVolumeTarget.self,
            RoutineFolder.self,
            SupersetGroup.self,
            RoutineExerciseSetOverride.self,
            SetEntry.self,
            PlateInventory.self,
            // Nested standalone @Model classes carrying the V3 on-disk
            // shape for the four entities reshaped by Phase 3.1 (PIVOT-03).
            Self.Routine.self,
            Self.Session.self,
            Self.RoutineExercise.self,
            Self.SessionExercise.self,
        ]
    }

    // MARK: - Nested standalone @Model classes (V3 on-disk shape)

    /// V3-shape Routine. Mirrors `fitbod.Routine` as it existed at the close
    /// of Phase 3 plan 03-01 — no `intentRaw` / `progressionKindRaw` (Plan
    /// 02 of Phase 3.1 adds those to the top-level production type).
    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false
        public var block: Block? = nil
        public var folderID: UUID? = nil

        @Relationship(deleteRule: .cascade, inverse: \SchemaV3.RoutineExercise.routine)
        public var exercises: [SchemaV3.RoutineExercise]? = []

        public init() {}
    }

    /// V3-shape Session. Mirrors `fitbod.Session` as it existed at the close
    /// of Phase 3 plan 03-01 — no `intentRaw` / `progressionKindRaw` (Plan
    /// 02 of Phase 3.1 adds those to the top-level production type).
    ///
    /// `#Index` is intentionally omitted from this nested type: the SwiftData
    /// `#Index<T>` macro requires `T` to match the enclosing class's
    /// unqualified identifier as the `@Model` macro sees it (it can't see
    /// through the enclosing-enum namespace). Indexes here would be cold —
    /// the V3→V4 migration closure does a single one-shot
    /// `FetchDescriptor<SchemaV3.Session>` and filters in memory; nothing
    /// in the migration path benefits from an index. The top-level
    /// `fitbod.Session` keeps the production `#Index<Session>([\.startedAt],
    /// [\.sourceRoutineID])` (extended in Plan 02 to add `[\.intentRaw]`)
    /// for the hot history queries.
    @Model
    public final class Session {
        @Attribute(.unique) public var id: UUID = UUID()
        public var startedAt: Date = Date.now
        public var completedAt: Date? = nil
        public var routineSnapshotName: String = ""
        public var sourceRoutineID: UUID? = nil
        public var block: Block? = nil
        public var notes: String? = nil
        public var totalDurationSeconds: Int? = nil

        @Relationship(deleteRule: .cascade, inverse: \SchemaV3.SessionExercise.session)
        public var exercises: [SchemaV3.SessionExercise]? = []

        public init() {}
    }

    /// V3-shape RoutineExercise. Mirrors `fitbod.RoutineExercise` AS IT
    /// EXISTS TODAY — RETAINING `intentRaw` + `progressionKindRaw` (those
    /// are precisely the fields Plan 02 of Phase 3.1 strips from the
    /// top-level production type; the willMigrate closure reads them off
    /// these nested rows so it can backfill the V4 Routine/Session intent
    /// fields).
    ///
    /// The `routine` relationship references the nested `SchemaV3.Routine`
    /// — both sides of the inverse keypath chain must live in the same
    /// VersionedSchema or SwiftData refuses to compose the schema.
    ///
    /// The `setOverrides` relationship intentionally omits its inverse
    /// keypath here: `RoutineExerciseSetOverride.routineExercise` points
    /// at the top-level production `fitbod.RoutineExercise`. The
    /// V3↔V4 migration closure never traverses this relationship — it
    /// reads scalar fields from RE rows directly — so the cross-schema
    /// reference is harmless. Keeping a `nil` inverse here also avoids
    /// SwiftData rejecting the schema with a "mismatched inverses" error.
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routine: SchemaV3.Routine? = nil
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
        public var supersetGroupID: UUID? = nil
        public var tracksTempo: Bool = false
        public var tracksPartialReps: Bool = false
        public var warmupOverrideData: Data? = nil

        @Relationship(deleteRule: .cascade)
        public var setOverrides: [RoutineExerciseSetOverride]? = []

        public init() {}
    }

    /// V3-shape SessionExercise. Mirrors `fitbod.SessionExercise` AS IT
    /// EXISTS TODAY — RETAINING `intentRaw` + `progressionKindRaw`.
    ///
    /// As with `SchemaV3.Session` above, `#Index` is omitted: the macro
    /// can't resolve `SchemaV3.SessionExercise` through the enclosing-enum
    /// namespace, and the migration closure does a one-shot
    /// `FetchDescriptor<SchemaV3.SessionExercise>` + in-memory filter, so
    /// an index would be cold-storage anyway. The top-level
    /// `fitbod.SessionExercise` keeps the production
    /// `#Index<SessionExercise>([\.intentRaw])` for the hot ExerciseHistoryView
    /// chip-filter queries (Plan 02 moves that index to `Session.intentRaw`).
    ///
    /// As with RoutineExercise above, `session` references the nested
    /// `SchemaV3.Session`, and `sets` intentionally omits the inverse
    /// declaration so the cross-schema reference to top-level `SetEntry`
    /// stays harmless (the migration closure never traverses it).
    @Model
    public final class SessionExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var session: SchemaV3.Session? = nil
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
        public var progressionKindRaw: String = "double"
        public var tracksTempo: Bool = false
        public var tracksPartialReps: Bool = false
        public var prescribedWeight: Double? = nil
        public var pinnedNote: String? = nil

        @Relationship(deleteRule: .cascade)
        public var sets: [SetEntry]? = []

        public init() {}
    }
}
