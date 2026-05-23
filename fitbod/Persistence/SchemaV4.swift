//
//  SchemaV4.swift
//  fitbod
//
//  The Phase 3.1 schema wrapper. Represents the V3->V4 migration
//  intermediate shape:
//    - `Routine.intentRaw` / `Routine.progressionKindRaw` ADDED (Plan 02)
//    - `Session.intentRaw` / `Session.progressionKindRaw` ADDED (Plan 02)
//    - `RoutineExercise.intentRaw` / `RoutineExercise.progressionKindRaw`
//      RETAINED long enough for didMigrate to backfill parent fields
//    - `SessionExercise.intentRaw` / `SessionExercise.progressionKindRaw`
//      RETAINED long enough for didMigrate to backfill parent fields
//
//  Per the BLOCKER 3 architecture decision (see SchemaV3.swift's header
//  comment for the full rationale), V3 declares NESTED standalone @Model
//  classes for the four entities with a V3<->V4 field delta; V4 declares
//  historical nested @Model classes for those four entities plus the
//  relationship chain that touches `Block`. This freezes V4 as the
//  pre-Phase-4 shape so SchemaV5 can be a real additive successor.
//
//  At Plan 01 commit time (this file's introduction), the top-level
//  production types still carry their V3 shape — Plan 02 reshapes them.
//  So the typealiases here resolve to V3-shape types initially, then
//  automatically reflect V4 shape after Plan 02 lands. This file does
//  not need to be edited when Plan 02 reshapes the production models.
//
//  Runtime production code now uses SchemaV5. V4 is kept as a historical
//  migration target so SwiftData can distinguish V4 stores from V5 stores
//  by checksum; using the top-level production `Block` here would include
//  `reviewedAt` and collapse V4/V5 into the same model shape.
//
//  Apple documentation reference:
//    - WWDC23 "Migrate to SwiftData"
//    - developer.apple.com/documentation/swiftdata/migrationstage/custom
//    - developer.apple.com/documentation/swiftdata/versionedschema
//
//  Version identifier matches semantic-version intent:
//    4.0.0 = Phase 3.1 schema delta (PIVOT-01..03 — session-level intent
//             and progression).
//

import Foundation
import SwiftData

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    // MARK: - Typealiases to top-level production types

    public typealias Exercise = fitbod.Exercise
    public typealias MuscleGroup = fitbod.MuscleGroup
    public typealias ExerciseMuscleStimulus = fitbod.ExerciseMuscleStimulus
    public typealias UserSettings = fitbod.UserSettings
    public typealias MuscleVolumeTarget = fitbod.MuscleVolumeTarget
    public typealias RoutineFolder = fitbod.RoutineFolder
    public typealias SupersetGroup = fitbod.SupersetGroup
    public typealias PlateInventory = fitbod.PlateInventory

    public static var models: [any PersistentModel.Type] {
        [
            Self.Exercise.self,
            Self.MuscleGroup.self,
            Self.ExerciseMuscleStimulus.self,
            Self.Block.self,
            Self.BlockPhase.self,
            Self.Routine.self,
            Self.RoutineExercise.self,
            Self.Session.self,
            Self.SessionExercise.self,
            Self.SetEntry.self,
            Self.UserSettings.self,
            Self.MuscleVolumeTarget.self,
            Self.RoutineFolder.self,
            Self.SupersetGroup.self,
            Self.RoutineExerciseSetOverride.self,
            Self.PlateInventory.self,
        ]
    }

    @Model
    public final class Block {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var startDate: Date = Date.now
        public var endDate: Date? = nil
        public var notes: String? = nil
        public var isActive: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.BlockPhase.block)
        public var phases: [SchemaV4.BlockPhase]? = []

        @Relationship(inverse: \SchemaV4.Routine.block)
        public var routines: [SchemaV4.Routine]? = []

        @Relationship(inverse: \SchemaV4.Session.block)
        public var sessions: [SchemaV4.Session]? = []

        public init() {}
    }

    @Model
    public final class BlockPhase {
        @Attribute(.unique) public var id: UUID = UUID()
        public var block: SchemaV4.Block? = nil
        public var orderIndex: Int = 0
        public var nameRaw: String = "accumulation"
        public var weeks: Int = 4
        public var volumeMultiplier: Double = 1.0
        public var intensityMultiplier: Double = 1.0
        public var notes: String? = nil

        public init() {}
    }

    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false
        public var block: SchemaV4.Block? = nil
        public var folderID: UUID? = nil
        public var intentRaw: String? = nil
        public var progressionKindRaw: String? = nil

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.RoutineExercise.routine)
        public var exercises: [SchemaV4.RoutineExercise]? = []

        public init() {}
    }

    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routine: SchemaV4.Routine? = nil
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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.RoutineExerciseSetOverride.routineExercise)
        public var setOverrides: [SchemaV4.RoutineExerciseSetOverride]? = []

        public init() {}
    }

    @Model
    public final class RoutineExerciseSetOverride {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routineExercise: SchemaV4.RoutineExercise? = nil
        public var setIndex: Int = 0
        public var targetRepsLow: Int? = nil
        public var targetRepsHigh: Int? = nil
        public var targetRPE: Double? = nil

        public init() {}
    }

    @Model
    public final class Session {
        @Attribute(.unique) public var id: UUID = UUID()
        public var startedAt: Date = Date.now
        public var completedAt: Date? = nil
        public var routineSnapshotName: String = ""
        public var sourceRoutineID: UUID? = nil
        public var block: SchemaV4.Block? = nil
        public var notes: String? = nil
        public var totalDurationSeconds: Int? = nil
        public var intentRaw: String? = nil
        public var progressionKindRaw: String? = nil

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.SessionExercise.session)
        public var exercises: [SchemaV4.SessionExercise]? = []

        public init() {}
    }

    @Model
    public final class SessionExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var session: SchemaV4.Session? = nil
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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.SetEntry.sessionExercise)
        public var sets: [SchemaV4.SetEntry]? = []

        public init() {}
    }

    @Model
    public final class SetEntry {
        @Attribute(.unique) public var id: UUID = UUID()
        public var sessionExercise: SchemaV4.SessionExercise? = nil
        public var orderIndex: Int = 0
        public var weight: Double = 0
        public var reps: Int = 0
        public var rpe: Double? = nil
        public var rir: Int? = nil
        public var restAfterSeconds: Int? = nil
        public var tempoActual: String? = nil
        public var notes: String? = nil
        public var isWarmup: Bool = false
        public var setTypeRaw: String = "working"
        public var completedAt: Date = Date.now
        public var partialReps: Int? = nil
        public var clusterSubRepsJoined: String? = nil
        public var isComplete: Bool = false
        public var wasManualOverride: Bool = false

        public init() {}
    }
}

extension SchemaV4.BlockPhase {
    public var kind: BlockPhaseKind { BlockPhaseKind(rawValue: nameRaw) ?? .accumulation }
}

extension SchemaV4.Routine {
    public var intent: Intent { Intent(rawValue: intentRaw ?? "") ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw ?? "") ?? .double
    }
}

extension SchemaV4.Session {
    public var intent: Intent { Intent(rawValue: intentRaw ?? "") ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw ?? "") ?? .double
    }
}

extension SchemaV4.RoutineExercise {
    public var warmupOverride: WarmupConfig? {
        get {
            guard let data = warmupOverrideData else { return nil }
            return try? JSONDecoder().decode(WarmupConfig.self, from: data)
        }
        set {
            warmupOverrideData = try? JSONEncoder().encode(newValue)
        }
    }
}

extension SchemaV4.SetEntry {
    public var setType: SetType { SetType(rawValue: setTypeRaw) ?? .working }

    public var clusterSubReps: [Int] {
        get {
            guard let joined = clusterSubRepsJoined, !joined.isEmpty else { return [] }
            return joined.split(separator: ",").compactMap { Int($0) }
        }
        set {
            clusterSubRepsJoined = newValue.isEmpty ? nil : newValue.map(String.init).joined(separator: ",")
        }
    }
}
