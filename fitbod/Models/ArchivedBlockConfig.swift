//
//  ArchivedBlockConfig.swift
//  fitbod
//
//  Freeze #2 archive DTO — written once in the same save as `Block.endDate`.
//  Readers (Phase 8+) decode this from `Block.archivedConfigJSON: String?`.
//
//  This is a plain Codable value type; it is NOT a SwiftData @Model.
//  Spec §6: decode failure → explicit error state in the reader.
//                           NO live-template fallback path, ever.
//
//  Field mirrors:
//    ArchivedPhaseDTO   ← BlockPhase stored fields
//    ArchivedSplitDTO   ← Split name + ordered SplitSessionSlot
//    ArchivedSlotDTO    ← SplitSessionSlot position + session name
//    ArchivedExerciseDTO ← RoutineExercise / SessionExerciseTemplate
//                          full prescription field set
//
//  ISO-8601 dates: both `encoded()` and `decode(from:)` use
//  `.iso8601` strategy so the JSON is human-readable and portable.
//
//  v:1 stamp: readers compare `v` before attempting field access.
//  Future schema changes bump `v` and add a migration path in the
//  reader — never in this DTO.
//

import Foundation

// MARK: - Top-level envelope

public struct ArchivedBlockConfig: Codable, Equatable, Sendable {

    /// Schema version stamp. Always 1 for V7-era archives.
    public let v: Int

    public let blockName: String
    public let startedAt: Date
    public let endedAt: Date

    /// Raw `SchedulingMode` value (e.g. "rotation" | "fixedWeekly").
    /// Stored as a plain String so the DTO has zero coupling to the enum.
    public let mode: String

    /// Calendar weekday numbers (1 = Sun … 7 = Sat). Sorted once at
    /// write via the user's `Calendar.firstWeekday`; array order is
    /// canonical and never re-sorted at read.
    public let trainingDays: [Int]

    public let phases: [ArchivedPhaseDTO]
    public let split: ArchivedSplitDTO

    public init(
        v: Int = 1,
        blockName: String,
        startedAt: Date,
        endedAt: Date,
        mode: String,
        trainingDays: [Int],
        phases: [ArchivedPhaseDTO],
        split: ArchivedSplitDTO
    ) {
        self.v = v
        self.blockName = blockName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.trainingDays = trainingDays
        self.phases = phases
        self.split = split
    }

    // MARK: - Codec helpers

    /// Encode to JSON with ISO-8601 date strategy.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decode from JSON. Throws on any malformed or type-mismatched input.
    /// Per spec §6: no live-template fallback — callers must surface an
    /// explicit "Archive unreadable" error state on failure.
    public static func decode(from data: Data) throws -> ArchivedBlockConfig {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArchivedBlockConfig.self, from: data)
    }
}

// MARK: - Phase DTO (mirrors BlockPhase stored fields)

public struct ArchivedPhaseDTO: Codable, Equatable, Sendable {

    /// Raw `BlockPhaseKind` value (e.g. "accumulation", "deload").
    public let kind: String

    /// Duration of this phase in weeks (`BlockPhase.weeks`).
    public let weeks: Int

    /// Volume scaling factor (`BlockPhase.volumeMultiplier`).
    public let volumeMultiplier: Double

    /// Intensity scaling factor (`BlockPhase.intensityMultiplier`).
    public let intensityMultiplier: Double

    /// Optional free-text notes (`BlockPhase.notes`).
    public let notes: String?

    public init(
        kind: String,
        weeks: Int,
        volumeMultiplier: Double,
        intensityMultiplier: Double,
        notes: String?
    ) {
        self.kind = kind
        self.weeks = weeks
        self.volumeMultiplier = volumeMultiplier
        self.intensityMultiplier = intensityMultiplier
        self.notes = notes
    }
}

// MARK: - Split DTO

public struct ArchivedSplitDTO: Codable, Equatable, Sendable {

    /// Name of the Split at archive time.
    public let name: String

    /// Slots ordered by position (ascending). Caller sorts before
    /// constructing — DTO preserves insertion order.
    public let slots: [ArchivedSlotDTO]

    public init(name: String, slots: [ArchivedSlotDTO]) {
        self.name = name
        self.slots = slots
    }
}

// MARK: - Slot DTO (mirrors SplitSessionSlot)

public struct ArchivedSlotDTO: Codable, Equatable, Sendable {

    /// Explicit position within the split (0-based, contiguous).
    public let position: Int

    /// Session template name at archive time.
    public let sessionName: String

    /// Exercises in this session slot, ordered by `orderIndex`.
    public let exercises: [ArchivedExerciseDTO]

    public init(
        position: Int,
        sessionName: String,
        exercises: [ArchivedExerciseDTO]
    ) {
        self.position = position
        self.sessionName = sessionName
        self.exercises = exercises
    }
}

// MARK: - Exercise DTO (mirrors RoutineExercise / SessionExerciseTemplate prescription fields)

public struct ArchivedExerciseDTO: Codable, Equatable, Sendable {

    /// Stable ID of the `Exercise` catalog row at archive time.
    public let exerciseID: UUID

    /// Snapshot of the exercise name — survives catalog edits / deletes.
    public let exerciseName: String

    /// Display order within the session slot.
    public let orderIndex: Int

    // MARK: Prescription fields (mirrored from RoutineExercise)

    public let targetSets: Int
    public let targetRepsLow: Int
    public let targetRepsHigh: Int
    public let targetRPE: Double?
    public let targetRIR: Int?
    public let prescribedRestSeconds: Int

    /// Tempo string (e.g. "3-1-1-0"), nullable.
    public let tempo: String?

    /// Free-text exercise notes.
    public let notes: String?

    // MARK: Enum-backed fields (stored as raw Strings)

    /// Raw `Intent` value (e.g. "strength", "hypertrophy").
    public let intentRaw: String

    /// Raw `ProgressionKind` value (e.g. "double", "rpe").
    public let progressionKindRaw: String

    // MARK: Behaviour flags

    public let generateWarmups: Bool
    public let tracksTempo: Bool
    public let tracksPartialReps: Bool

    public init(
        exerciseID: UUID,
        exerciseName: String,
        orderIndex: Int,
        targetSets: Int,
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        targetRIR: Int?,
        prescribedRestSeconds: Int,
        tempo: String?,
        notes: String?,
        intentRaw: String,
        progressionKindRaw: String,
        generateWarmups: Bool,
        tracksTempo: Bool,
        tracksPartialReps: Bool
    ) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.prescribedRestSeconds = prescribedRestSeconds
        self.tempo = tempo
        self.notes = notes
        self.intentRaw = intentRaw
        self.progressionKindRaw = progressionKindRaw
        self.generateWarmups = generateWarmups
        self.tracksTempo = tracksTempo
        self.tracksPartialReps = tracksPartialReps
    }
}
