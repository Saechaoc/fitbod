//
//  SchemaV5.swift
//  fitbod
//
//  The Phase 4 schema wrapper. Additive successor to SchemaV4 (which
//  Phase 3.1 locked for the PIVOT-03 session-level intent /
//  progression reshape). V5's delta:
//
//    - `Block.reviewedAt: Date? = nil` ADDED (D-26 / D-21).
//
//  Per Phase 4 CONTEXT.md D-26: the original plan was to ship
//  `Block.reviewedAt` inside SchemaV3 (Phase 3 in flight at that
//  time). Phase 3 sealed SchemaV3 lightweight; Phase 3.1 sealed
//  SchemaV4 with the PIVOT-03 custom migration. Phase 4 therefore
//  stacks SchemaV5 on top of V4 as the canonical home for
//  `Block.reviewedAt`.
//
//  Why lightweight is sufficient here: the delta is a single new
//  Optional<Date> field with a `nil` default on an existing @Model.
//  SwiftData's lightweight migration handles additive optional fields
//  without a custom willMigrate closure
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight].
//  The closure-based V3→V4 stage exists ONLY because that stage
//  removes fields AND moves values between entities; neither applies
//  here.
//
//  CR-01 (Phase 7 review): the V7 rename Routine→SessionTemplate /
//  RoutineExercise→SessionExerciseTemplate dropped the top-level
//  `Routine` / `RoutineExercise` production types. SchemaV5 previously
//  used typealiases (`typealias Routine = fitbod.SessionTemplate`)
//  which resolve the entity NAME to "SessionTemplate" — NOT "Routine".
//  SwiftData matches schema versions by the model entity NAMES recorded
//  in the on-disk store; a V5 store's entities are named "Routine" /
//  "RoutineExercise". With typealiases, SwiftData cannot find the V5
//  entities and refuses to open (or corrupts) any pre-V7 store at
//  version 5, breaking the migration walk V5→…→V7.
//
//  Fix mirrors the SchemaV1 / SchemaV3 / SchemaV4 / SchemaV6
//  nested-@Model pattern: SchemaV5 now declares its own nested
//  `Routine` / `RoutineExercise` @Model classes carrying the V5-era
//  on-disk shape. The V5-era shape is IDENTICAL to the SchemaV6 nested
//  shape — V5→V6 added fields only to OTHER entities
//  (UserSettings / Exercise / ExerciseMuscleStimulus / MuscleVolumeTarget)
//  and never changed Routine / RoutineExercise. The two nested types are
//  mirrored from SchemaV6.swift verbatim with inverse keypaths
//  re-targeted to SchemaV5.Routine / SchemaV5.RoutineExercise.
//
//  `String(describing: SchemaV5.Routine.self)` now resolves to "Routine"
//  — the correct V5 on-disk entity name — so a genuine V5 store walks
//  forward to V7 cleanly.
//
//  Audit: V3 (nested — safe), V4 (nested — safe), V6 (nested — safe);
//  only V5 had the unfixed CR-01 break introduced by the V7 rename.
//
//  Version identifier:
//    5.0.0 = Phase 4 schema delta (Block.reviewedAt — end-of-block
//             review timestamp).
//

import Foundation
import SwiftData

public enum SchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

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

// MARK: - Nested V5-shape @Model classes (migration support)
// Declared in an extension to keep the enum clean. These mirror the exact
// on-disk shapes of Routine and RoutineExercise at the close of SchemaV5,
// so the migration chain can resolve V5 entity names correctly.
//
// The V5-era Routine/RoutineExercise shape is IDENTICAL to the SchemaV6
// nested shape — V5→V6 was additive on OTHER entities only. The types below
// are mirrored from SchemaV6.swift with inverse keypaths re-targeted to the
// SchemaV5 nested forms.
//
// Rules (per SchemaV3.swift / SchemaV6.swift precedent):
//  - Inverse keypaths reference the NESTED form (SchemaV5.RoutineExercise)
//    — both sides of a SwiftData inverse must be in the same VersionedSchema.
//  - Cross-schema inverses (setOverrides → top-level RoutineExerciseSetOverride)
//    are intentionally omitted on the nested side — the migration closure
//    reads scalar fields and never traverses setOverrides.
//  - #Index is intentionally OMITTED — the macro cannot resolve qualified
//    type names through the enclosing enum namespace (SchemaV3.swift §129).

extension SchemaV5 {

    /// V5-shape Routine — mirrors `fitbod.Routine` exactly as it existed at
    /// the close of SchemaV5. Includes `block: fitbod.Block?` so migration
    /// can capture blockID. Entity name resolves to "Routine" (not
    /// "SessionTemplate") so a V5 on-disk store is correctly matched.
    ///
    /// `#Index` intentionally omitted — see extension-level comment above.
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
        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.RoutineExercise.routine)
        public var exercises: [SchemaV5.RoutineExercise]? = []

        public init() {}
    }

    /// V5-shape RoutineExercise — mirrors `fitbod.RoutineExercise` exactly as it
    /// existed at the close of SchemaV5. Needed to rebuild SessionExerciseTemplate
    /// rows in didMigrate.
    ///
    /// `routine` references `SchemaV5.Routine` (nested form) — CRITICAL.
    /// `setOverrides` intentionally omits its inverse: the migration closure
    /// reads scalar fields directly and never traverses the setOverrides
    /// relationship. Cross-schema inverse omission prevents "mismatched inverses"
    /// errors (SchemaV3.swift lines 158–166 / SchemaV6.swift lines 191–196 pattern).
    ///
    /// `#Index` intentionally omitted — see extension-level comment above.
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()

        /// Nested form — CRITICAL: both sides of the inverse keypath chain must
        /// live in the same VersionedSchema (see SchemaV5.Routine.exercises above).
        public var routine: SchemaV5.Routine? = nil

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
        /// harmless (SchemaV3.swift line 189 / SchemaV6.swift lines 191–196 pattern).
        @Relationship(deleteRule: .cascade)
        public var setOverrides: [fitbod.RoutineExerciseSetOverride]? = []

        public init() {}
    }
}
