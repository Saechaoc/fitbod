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
//  Phase 7 expansion: SchemaV6 gains nested @Model classes `SchemaV6.Routine`
//  and `SchemaV6.RoutineExercise` (V6 on-disk shape) so the migrateV6toV7
//  willMigrate closure can use `FetchDescriptor<SchemaV6.Routine>()` to
//  read old Routine rows (incl. `Routine.block?.id`) before the entity is
//  dropped. This mirrors the SchemaV3.swift pattern (see that file's header
//  comment). `SchemaV6.models` is expanded from a SchemaV5 passthrough to
//  an explicit array that includes both nested types (Pitfall 4 fix — silent
//  0-row stash otherwise).
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

    // MARK: - Explicit models array (Pitfall 4 fix — was a passthrough; now explicit)
    // 14 top-level production types + 2 nested V6-shape migration types = 16 entries.
    // The nested `Self.Routine` / `Self.RoutineExercise` are required so that
    // `FetchDescriptor<SchemaV6.Routine>()` in willMigrate resolves rows.
    // SchemaV7.models is a separate explicit array that does NOT include these
    // migration-only nested types.

    public static var models: [any PersistentModel.Type] {
        [
            // Top-level production types (entities unchanged from V5 entity catalog)
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
            // Nested V6-shape @Model classes for the V6→V7 migration closure.
            // These represent the OLD entity shapes before entity rename.
            Self.Routine.self,
            Self.RoutineExercise.self,
        ]
    }
}

// MARK: - Nested V6-shape @Model classes (migration support only)
// Declared in an extension to keep the enum clean. These mirror the exact
// on-disk shapes of Routine and RoutineExercise at the close of SchemaV6,
// so the migrateV6toV7 willMigrate closure can fetch rows via
// `FetchDescriptor<SchemaV6.Routine>()` before the entity is dropped.
//
// Rules (per SchemaV3.swift precedent):
//  - Inverse keypaths reference the NESTED form (SchemaV6.RoutineExercise)
//    — both sides of a SwiftData inverse must be in the same VersionedSchema.
//  - Cross-schema inverses (setOverrides → top-level RoutineExerciseSetOverride)
//    are intentionally omitted on the nested side — the migration closure reads
//    scalar fields and never traverses setOverrides.
//  - #Index is intentionally OMITTED — the macro cannot resolve qualified
//    type names through the enclosing enum namespace (SchemaV3.swift §129).
//  - The nested Routine/RoutineExercise types are NOT in SchemaV7.models —
//    they are migration scaffolding only.

extension SchemaV6 {

    /// V6-shape Routine — mirrors `fitbod.Routine` exactly as it existed at
    /// the close of SchemaV6. Includes `block: fitbod.Block?` so willMigrate
    /// can capture `blockID` for step 3 (auto-Split creation per block).
    ///
    /// `#Index` intentionally omitted — see class-level comment above.
    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false

        /// Top-level Block (unchanged entity) — needed to capture blockID in willMigrate.
        public var block: fitbod.Block? = nil

        public var folderID: UUID? = nil
        public var intentRaw: String = "strength"
        public var progressionKindRaw: String = "double"

        /// Inverse keypath uses the nested form — both sides must be in the same
        /// VersionedSchema (Pitfall 3 from RESEARCH.md / SchemaV3.swift pattern).
        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.RoutineExercise.routine)
        public var exercises: [SchemaV6.RoutineExercise]? = []

        public init() {}
    }

    /// V6-shape RoutineExercise — mirrors `fitbod.RoutineExercise` exactly as it
    /// existed at the close of SchemaV6. Needed to rebuild SessionExerciseTemplate
    /// rows in didMigrate.
    ///
    /// `routine` references `SchemaV6.Routine` (nested form) — CRITICAL.
    /// `setOverrides` intentionally omits its inverse: the migration closure
    /// reads scalar fields directly and never traverses the setOverrides
    /// relationship. Cross-schema inverse omission prevents "mismatched inverses"
    /// errors (SchemaV3.swift lines 158–166 pattern).
    ///
    /// `#Index` intentionally omitted — see class-level comment above.
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()

        /// Nested form — CRITICAL: both sides of the inverse keypath chain must
        /// live in the same VersionedSchema (see SchemaV6.Routine.exercises above).
        public var routine: SchemaV6.Routine? = nil

        public var exercise: fitbod.Exercise? = nil
        public var orderIndex: Int = 0

        public var targetSets: Int = 3
        public var targetRepsLow: Int = 8
        public var targetRepsHigh: Int = 12
        public var targetRPE: Double? = nil
        public var targetRIR: Int? = nil
        public var prescribedRestSeconds: Int = 120
        public var tempo: String? = nil
        public var notes: String? = nil
        public var generateWarmups: Bool = false
        public var supersetGroupID: UUID? = nil
        public var tracksTempo: Bool = false
        public var tracksPartialReps: Bool = false
        public var warmupOverrideData: Data? = nil

        /// Inverse deliberately omitted — `RoutineExerciseSetOverride.routineExercise`
        /// points at the top-level production type, not this nested type. The migration
        /// closure never traverses this relationship, so the cross-schema mismatch is
        /// harmless (SchemaV3.swift line 189 pattern).
        @Relationship(deleteRule: .cascade)
        public var setOverrides: [fitbod.RoutineExerciseSetOverride]? = []

        public init() {}
    }
}
