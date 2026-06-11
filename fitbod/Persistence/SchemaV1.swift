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
//  CR-01 (Phase 7 review): the V7 rename Routine→SessionTemplate /
//  RoutineExercise→SessionExerciseTemplate dropped the top-level `Routine`
//  / `RoutineExercise` types. SchemaV1 cannot reference the V7-renamed
//  production types — SwiftData matches schema versions by the model entity
//  NAMES recorded in the on-disk store, and a V1 store's entities are named
//  `Routine` / `RoutineExercise`. Listing `SessionTemplate` /
//  `SessionExerciseTemplate` here makes SwiftData unable to find the V1
//  entities and it refuses to open (or corrupts) any pre-V7 store at
//  version 1, breaking the migration walk V1→…→V7.
//
//  Fix mirrors the SchemaV3 / SchemaV6 nested-@Model pattern: SchemaV1
//  declares its own nested `Routine` / `RoutineExercise` @Model classes
//  carrying the V1-era on-disk shape (no `folderID` — that is a V2
//  addition; no `supersetGroupID` / `tracksTempo` / `tracksPartialReps` /
//  `setOverrides` on RoutineExercise — also V2 additions). The other 10
//  entities are unchanged across V1↔V7 and stay referenced via their
//  top-level production types.
//
//  `String(describing:)` of these nested types resolves to the unqualified
//  `"Routine"` / `"RoutineExercise"` — the exact V1 on-disk entity names —
//  so SchemaV1Tests (12-entity contract) and SchemaV2MigrationTests
//  (additive-superset assertion) keep passing.
//

import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Self.Routine.self,            // V1 on-disk entity (renamed to SessionTemplate in V7)
            Self.RoutineExercise.self,    // V1 on-disk entity (renamed to SessionExerciseTemplate in V7)
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

// MARK: - Nested V1-shape @Model classes (migration ancestor only)
// These mirror the V1 on-disk shapes of Routine and RoutineExercise so
// SwiftData can match and walk an existing V1 store forward through the
// migration chain. Rules per SchemaV3.swift / SchemaV6.swift precedent:
//  - Inverse keypaths reference the NESTED form (both sides of an inverse
//    must live in the same VersionedSchema).
//  - #Index is intentionally omitted (the macro cannot resolve qualified
//    type names through the enclosing enum namespace).
//  - These nested types are NOT in SchemaV7.models — migration scaffolding only.

extension SchemaV1 {

    /// V1-shape Routine. No `folderID` (V2 addition) and no parent-level
    /// `intentRaw` / `progressionKindRaw` (V4 addition).
    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false
        public var block: Block? = nil

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.RoutineExercise.routine)
        public var exercises: [SchemaV1.RoutineExercise]? = []

        public init() {}
    }

    /// V1-shape RoutineExercise. No `supersetGroupID` / `tracksTempo` /
    /// `tracksPartialReps` / `setOverrides` (all V2 additions). Retains the
    /// per-exercise `intentRaw` / `progressionKindRaw` (those existed since
    /// V1; not removed until V4).
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routine: SchemaV1.Routine? = nil
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
        public var warmupOverrideData: Data? = nil

        public init() {}
    }
}
