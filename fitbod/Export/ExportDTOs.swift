//
//  ExportDTOs.swift
//  fitbod
//
//  Wave-3 plan 06-09 — schema-versioned Codable DTO graph + envelope
//  for the EXP-02 JSON export (06-09b) AND the EXP-03 backup
//  archive (06-10). Single source of truth for:
//
//    1. The SchemaV7 export graph as plain Codable value
//       types (no SwiftData coupling — RESEARCH "Decoding backup
//       directly into @Model" anti-pattern).
//    2. `ExportDocument.canonicalSchemaVersion` constant — the
//       restore-side schema-skew check compares against this.
//    3. Shared `JSONEncoder.exportConfigured()` so the snapshot
//       test, the user-facing JSON export, and the backup writer
//       all produce byte-identical output.
//
//  ## DTO name collision (RESEARCH §"DTO name collision")
//
//  `fitbod/ExerciseLibrary/ExerciseDTO.swift` already declares
//  `ExerciseDTO` for the free-exercise-db seed pipeline. We
//  uniformly prefix every Phase 6 export DTO with `Export` to
//  avoid the collision: `ExportExerciseDTO`, `ExportRoutineDTO`,
//  etc.
//
//  Logged exercise names use the log-time snapshot through `displayName`,
//  preserving history after a library rename or deletion. The raw snapshot
//  is also carried so restore can retain pre-snapshot rows faithfully.
//
//  ## Schema version
//
//  This plan landed AFTER Phase 5 closed SchemaV6. The literal
//  CONTEXT D-28 spec called for `"v2"` (the schema as of Wave 0
//  planning) — we use `"v6"` so the restore-side equality check
//  is honest about what the current runtime stores. The plan's
//  `"v2"` literal is replaced; the contract (single constant,
//  string-typed, exposed via ExportDocument.canonicalSchemaVersion)
//  is preserved verbatim.
//
//  [CITED: REQUIREMENTS EXP-02 + CONTEXT D-28 + RESEARCH §DTO name
//   collision]
//

import Foundation

// MARK: - Encoder configuration (shared by all export surfaces)

extension JSONEncoder {
    /// Canonical Phase 6 export encoder — `.prettyPrinted`,
    /// `.sortedKeys`, `.withoutEscapingSlashes`, ISO-8601 dates.
    /// Used by the JSON exporter (06-09b), the backup archiver
    /// (06-10), and the ExportDocument snapshot test (06-09).
    public static func exportConfigured() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}

// MARK: - Envelope

public struct ExportDocument: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let schemaVersion: String
    public let exportedAt: Date
    public let unitSystem: String
    public let exercises: [ExportExerciseDTO]
    public let routines: [ExportRoutineDTO]
    /// Optional only for decoding format-1 archives, which had no routines graph.
    public let splits: [ExportSplitDTO]?
    public let routineFolders: [ExportRoutineFolderDTO]
    public let supersetGroups: [ExportSupersetGroupDTO]
    public let sessions: [ExportSessionDTO]
    public let blocks: [ExportBlockDTO]
    public let muscleGroups: [ExportMuscleGroupDTO]
    public let exerciseMuscleStimuli: [ExportExerciseMuscleStimulusDTO]
    public let muscleVolumeTargets: [ExportMuscleVolumeTargetDTO]
    public let plateInventories: [ExportPlateInventoryDTO]
    public let userSettings: ExportUserSettingsDTO?

    /// Single source-of-truth schema version. Restore-side compares
    /// against this; backup manifest writes the same string.
    public static let canonicalSchemaVersion = "v7"

    public init(
        formatVersion: Int,
        schemaVersion: String,
        exportedAt: Date,
        unitSystem: String,
        exercises: [ExportExerciseDTO],
        routines: [ExportRoutineDTO],
        splits: [ExportSplitDTO]? = [],
        routineFolders: [ExportRoutineFolderDTO],
        supersetGroups: [ExportSupersetGroupDTO],
        sessions: [ExportSessionDTO],
        blocks: [ExportBlockDTO],
        muscleGroups: [ExportMuscleGroupDTO],
        exerciseMuscleStimuli: [ExportExerciseMuscleStimulusDTO],
        muscleVolumeTargets: [ExportMuscleVolumeTargetDTO],
        plateInventories: [ExportPlateInventoryDTO],
        userSettings: ExportUserSettingsDTO?
    ) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.unitSystem = unitSystem
        self.exercises = exercises
        self.routines = routines
        self.splits = splits
        self.routineFolders = routineFolders
        self.supersetGroups = supersetGroups
        self.sessions = sessions
        self.blocks = blocks
        self.muscleGroups = muscleGroups
        self.exerciseMuscleStimuli = exerciseMuscleStimuli
        self.muscleVolumeTargets = muscleVolumeTargets
        self.plateInventories = plateInventories
        self.userSettings = userSettings
    }
}

// MARK: - Split + ordered slots (UI: routine)

public struct ExportSplitDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let isArchived: Bool
    public let slots: [ExportSplitSessionSlotDTO]

    public init(id: UUID, name: String, createdAt: Date, isArchived: Bool, slots: [ExportSplitSessionSlotDTO]) {
        self.id = id; self.name = name; self.createdAt = createdAt
        self.isArchived = isArchived; self.slots = slots
    }
}

public struct ExportSplitSessionSlotDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let position: Int
    public let sessionTemplateID: UUID?

    public init(id: UUID, position: Int, sessionTemplateID: UUID?) {
        self.id = id; self.position = position; self.sessionTemplateID = sessionTemplateID
    }
}

// MARK: - Exercise

public struct ExportExerciseDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let externalID: String?
    public let name: String
    public let canonicalName: String
    public let equipmentRaw: String
    public let mechanicRaw: String
    public let forceRaw: String?
    public let levelRaw: String?
    public let patternRaw: String?
    public let category: String
    public let instructions: [String]
    public let imagePaths: [String]
    public let isCustom: Bool
    public let primaryMuscleSlugsJoined: String
    public let createdAt: Date
    public let smallestIncrement: Double?
    public let barWeightOverride: Double?
    public let unitOverrideRaw: String?
    public let plateauWindowOverride: Int?
    public let plateauToleranceOverride: Double?

    public init(
        id: UUID,
        externalID: String?,
        name: String,
        canonicalName: String,
        equipmentRaw: String,
        mechanicRaw: String,
        forceRaw: String?,
        levelRaw: String?,
        patternRaw: String?,
        category: String,
        instructions: [String],
        imagePaths: [String],
        isCustom: Bool,
        primaryMuscleSlugsJoined: String,
        createdAt: Date,
        smallestIncrement: Double?,
        barWeightOverride: Double?,
        unitOverrideRaw: String?,
        plateauWindowOverride: Int?,
        plateauToleranceOverride: Double?
    ) {
        self.id = id
        self.externalID = externalID
        self.name = name
        self.canonicalName = canonicalName
        self.equipmentRaw = equipmentRaw
        self.mechanicRaw = mechanicRaw
        self.forceRaw = forceRaw
        self.levelRaw = levelRaw
        self.patternRaw = patternRaw
        self.category = category
        self.instructions = instructions
        self.imagePaths = imagePaths
        self.isCustom = isCustom
        self.primaryMuscleSlugsJoined = primaryMuscleSlugsJoined
        self.createdAt = createdAt
        self.smallestIncrement = smallestIncrement
        self.barWeightOverride = barWeightOverride
        self.unitOverrideRaw = unitOverrideRaw
        self.plateauWindowOverride = plateauWindowOverride
        self.plateauToleranceOverride = plateauToleranceOverride
    }
}

// MARK: - Routine + descendants

public struct ExportRoutineDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let notes: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let isArchived: Bool
    public let blockID: UUID?
    public let folderID: UUID?
    public let intentRaw: String
    public let progressionKindRaw: String
    public let exercises: [ExportRoutineExerciseDTO]

    public init(
        id: UUID, name: String, notes: String?, createdAt: Date,
        updatedAt: Date, isArchived: Bool, blockID: UUID?,
        folderID: UUID?, intentRaw: String, progressionKindRaw: String,
        exercises: [ExportRoutineExerciseDTO]
    ) {
        self.id = id; self.name = name; self.notes = notes
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isArchived = isArchived; self.blockID = blockID
        self.folderID = folderID; self.intentRaw = intentRaw
        self.progressionKindRaw = progressionKindRaw
        self.exercises = exercises
    }
}

public struct ExportRoutineExerciseDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let exerciseID: UUID?
    public let orderIndex: Int
    public let targetSets: Int
    public let targetRepsLow: Int
    public let targetRepsHigh: Int
    public let targetRPE: Double?
    public let targetRIR: Int?
    public let prescribedRestSeconds: Int
    public let tempo: String?
    public let notes: String?
    public let generateWarmups: Bool
    public let supersetGroupID: UUID?
    public let tracksTempo: Bool
    public let tracksPartialReps: Bool
    public let warmupOverrideData: Data?
    public let setOverrides: [ExportRoutineExerciseSetOverrideDTO]

    public init(
        id: UUID, exerciseID: UUID?, orderIndex: Int, targetSets: Int,
        targetRepsLow: Int, targetRepsHigh: Int, targetRPE: Double?,
        targetRIR: Int?, prescribedRestSeconds: Int, tempo: String?,
        notes: String?, generateWarmups: Bool, supersetGroupID: UUID?,
        tracksTempo: Bool, tracksPartialReps: Bool,
        warmupOverrideData: Data?,
        setOverrides: [ExportRoutineExerciseSetOverrideDTO]
    ) {
        self.id = id; self.exerciseID = exerciseID
        self.orderIndex = orderIndex; self.targetSets = targetSets
        self.targetRepsLow = targetRepsLow; self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE; self.targetRIR = targetRIR
        self.prescribedRestSeconds = prescribedRestSeconds
        self.tempo = tempo; self.notes = notes
        self.generateWarmups = generateWarmups
        self.supersetGroupID = supersetGroupID
        self.tracksTempo = tracksTempo
        self.tracksPartialReps = tracksPartialReps
        self.warmupOverrideData = warmupOverrideData
        self.setOverrides = setOverrides
    }
}

public struct ExportRoutineExerciseSetOverrideDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let setIndex: Int
    public let targetRepsLow: Int?
    public let targetRepsHigh: Int?
    public let targetRPE: Double?

    public init(
        id: UUID, setIndex: Int, targetRepsLow: Int?,
        targetRepsHigh: Int?, targetRPE: Double?
    ) {
        self.id = id; self.setIndex = setIndex
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
    }
}

public struct ExportRoutineFolderDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let sortOrder: Int
    public let createdAt: Date

    public init(id: UUID, name: String, sortOrder: Int, createdAt: Date) {
        self.id = id; self.name = name
        self.sortOrder = sortOrder; self.createdAt = createdAt
    }
}

public struct ExportSupersetGroupDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let routineID: UUID
    public let kindRaw: String
    public let sortOrder: Int
    public let createdAt: Date

    public init(id: UUID, routineID: UUID, kindRaw: String, sortOrder: Int, createdAt: Date) {
        self.id = id; self.routineID = routineID
        self.kindRaw = kindRaw; self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

// MARK: - Session + descendants

public struct ExportSessionDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date?
    public let routineSnapshotName: String
    public let sourceRoutineID: UUID?
    public let blockID: UUID?
    public let notes: String?
    public let totalDurationSeconds: Int?
    public let intentRaw: String
    public let progressionKindRaw: String
    // WR-05 (V7): log-time template-name snapshot (freeze #1 insurance) +
    // the launching slot's position and split name. All optional/defaulted
    // so older v6 backups (which lack these keys) decode cleanly.
    public let templateName: String?
    public let slotPosition: Int?
    public let slotSplitName: String?
    public let slotID: UUID?
    public let exercises: [ExportSessionExerciseDTO]

    public init(
        id: UUID, startedAt: Date, completedAt: Date?,
        routineSnapshotName: String, sourceRoutineID: UUID?,
        blockID: UUID?, notes: String?, totalDurationSeconds: Int?,
        intentRaw: String, progressionKindRaw: String,
        templateName: String? = nil,
        slotPosition: Int? = nil,
        slotSplitName: String? = nil,
        slotID: UUID? = nil,
        exercises: [ExportSessionExerciseDTO]
    ) {
        self.id = id; self.startedAt = startedAt
        self.completedAt = completedAt
        self.routineSnapshotName = routineSnapshotName
        self.sourceRoutineID = sourceRoutineID; self.blockID = blockID
        self.notes = notes; self.totalDurationSeconds = totalDurationSeconds
        self.intentRaw = intentRaw
        self.progressionKindRaw = progressionKindRaw
        self.templateName = templateName
        self.slotPosition = slotPosition
        self.slotSplitName = slotSplitName
        self.slotID = slotID
        self.exercises = exercises
    }
}

public struct ExportSessionExerciseDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let exerciseID: UUID?
    /// The logged display name, even when the library entry has been deleted.
    public let exerciseName: String
    public let exerciseNameSnapshot: String?
    public let orderIndex: Int
    public let targetSets: Int
    public let targetRepsLow: Int
    public let targetRepsHigh: Int
    public let targetRPE: Double?
    public let targetRIR: Int?
    public let prescribedRestSeconds: Int
    public let tempo: String?
    public let tracksTempo: Bool
    public let tracksPartialReps: Bool
    public let prescribedWeight: Double?
    public let pinnedNote: String?
    public let sets: [ExportSetEntryDTO]

    public init(
        id: UUID, exerciseID: UUID?, exerciseName: String, orderIndex: Int,
        targetSets: Int, targetRepsLow: Int, targetRepsHigh: Int,
        targetRPE: Double?, targetRIR: Int?, prescribedRestSeconds: Int,
        tempo: String?, tracksTempo: Bool, tracksPartialReps: Bool,
        prescribedWeight: Double?, pinnedNote: String?,
        exerciseNameSnapshot: String? = nil,
        sets: [ExportSetEntryDTO]
    ) {
        self.id = id; self.exerciseID = exerciseID
        self.exerciseName = exerciseName; self.orderIndex = orderIndex
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetSets = targetSets
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE; self.targetRIR = targetRIR
        self.prescribedRestSeconds = prescribedRestSeconds
        self.tempo = tempo; self.tracksTempo = tracksTempo
        self.tracksPartialReps = tracksPartialReps
        self.prescribedWeight = prescribedWeight
        self.pinnedNote = pinnedNote; self.sets = sets
    }
}

public struct ExportSetEntryDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let orderIndex: Int
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let rir: Int?
    public let restAfterSeconds: Int?
    public let tempoActual: String?
    public let notes: String?
    public let isWarmup: Bool
    public let setTypeRaw: String
    public let completedAt: Date
    public let partialReps: Int?
    public let clusterSubRepsJoined: String?
    public let isComplete: Bool
    public let wasManualOverride: Bool

    public init(
        id: UUID, orderIndex: Int, weight: Double, reps: Int,
        rpe: Double?, rir: Int?, restAfterSeconds: Int?,
        tempoActual: String?, notes: String?, isWarmup: Bool,
        setTypeRaw: String, completedAt: Date, partialReps: Int?,
        clusterSubRepsJoined: String?, isComplete: Bool,
        wasManualOverride: Bool
    ) {
        self.id = id; self.orderIndex = orderIndex
        self.weight = weight; self.reps = reps
        self.rpe = rpe; self.rir = rir
        self.restAfterSeconds = restAfterSeconds
        self.tempoActual = tempoActual
        self.notes = notes; self.isWarmup = isWarmup
        self.setTypeRaw = setTypeRaw; self.completedAt = completedAt
        self.partialReps = partialReps
        self.clusterSubRepsJoined = clusterSubRepsJoined
        self.isComplete = isComplete
        self.wasManualOverride = wasManualOverride
    }
}

// MARK: - Block + BlockPhase

public struct ExportBlockDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let startDate: Date
    public let endDate: Date?
    public let notes: String?
    public let isActive: Bool
    public let reviewedAt: Date?
    // WR-05 (V7): program-graph fields. schedulingModeRaw / trainingDaysJoined
    // default to the V7 model defaults; archivedConfigJSON is the freeze-#2
    // archive (spec §6 — sole source of truth for completed-block views, so it
    // MUST round-trip); splitName is a soft name reference to the attached split.
    // All defaulted/optional so older v6 backups decode without these keys.
    public let schedulingModeRaw: String
    public let trainingDaysJoined: String
    public let archivedConfigJSON: String?
    public let splitName: String?
    public let splitID: UUID?
    public let phases: [ExportBlockPhaseDTO]

    public init(
        id: UUID, name: String, startDate: Date, endDate: Date?,
        notes: String?, isActive: Bool, reviewedAt: Date?,
        schedulingModeRaw: String = "rotation",
        trainingDaysJoined: String = "",
        archivedConfigJSON: String? = nil,
        splitName: String? = nil,
        splitID: UUID? = nil,
        phases: [ExportBlockPhaseDTO]
    ) {
        self.id = id; self.name = name
        self.startDate = startDate; self.endDate = endDate
        self.notes = notes; self.isActive = isActive
        self.reviewedAt = reviewedAt
        self.schedulingModeRaw = schedulingModeRaw
        self.trainingDaysJoined = trainingDaysJoined
        self.archivedConfigJSON = archivedConfigJSON
        self.splitName = splitName
        self.splitID = splitID
        self.phases = phases
    }
}

public struct ExportBlockPhaseDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let orderIndex: Int
    public let nameRaw: String
    public let weeks: Int
    public let volumeMultiplier: Double
    public let intensityMultiplier: Double
    public let notes: String?

    public init(
        id: UUID, orderIndex: Int, nameRaw: String, weeks: Int,
        volumeMultiplier: Double, intensityMultiplier: Double,
        notes: String?
    ) {
        self.id = id; self.orderIndex = orderIndex
        self.nameRaw = nameRaw; self.weeks = weeks
        self.volumeMultiplier = volumeMultiplier
        self.intensityMultiplier = intensityMultiplier
        self.notes = notes
    }
}

// MARK: - MuscleGroup + ExerciseMuscleStimulus + MuscleVolumeTarget

public struct ExportMuscleGroupDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let slug: String
    public let displayName: String
    public let regionRaw: String

    public init(id: UUID, slug: String, displayName: String, regionRaw: String) {
        self.id = id; self.slug = slug
        self.displayName = displayName; self.regionRaw = regionRaw
    }
}

public struct ExportExerciseMuscleStimulusDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let exerciseID: UUID?
    public let muscleID: UUID?
    public let role: String
    public let weight: Double
    public let userEditedWeight: Bool

    public init(
        id: UUID, exerciseID: UUID?, muscleID: UUID?,
        role: String, weight: Double, userEditedWeight: Bool
    ) {
        self.id = id; self.exerciseID = exerciseID
        self.muscleID = muscleID; self.role = role
        self.weight = weight; self.userEditedWeight = userEditedWeight
    }
}

public struct ExportMuscleVolumeTargetDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let muscleID: UUID?
    public let mv: Int
    public let mev: Int
    public let mav: Int
    public let mrv: Int
    public let notes: String?
    public let userEdited: Bool

    public init(
        id: UUID, muscleID: UUID?, mv: Int, mev: Int, mav: Int, mrv: Int,
        notes: String?, userEdited: Bool
    ) {
        self.id = id; self.muscleID = muscleID
        self.mv = mv; self.mev = mev; self.mav = mav; self.mrv = mrv
        self.notes = notes; self.userEdited = userEdited
    }
}

// MARK: - PlateInventory

public struct ExportPlateInventoryDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let equipmentKindRaw: String
    public let barWeight: Double
    public let availablePlatesData: Data
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID, equipmentKindRaw: String, barWeight: Double,
        availablePlatesData: Data, createdAt: Date, updatedAt: Date
    ) {
        self.id = id; self.equipmentKindRaw = equipmentKindRaw
        self.barWeight = barWeight
        self.availablePlatesData = availablePlatesData
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

// MARK: - UserSettings

public struct ExportUserSettingsDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let unitsRaw: String
    public let defaultProgressionKindRaw: String
    public let warmupSchemeRaw: String
    public let customWarmupPercents: [Double]?
    public let plateauWindowSessions: Int
    public let plateauTolerance: Double
    public let deloadAlertEnabled: Bool
    public let weekStartsMonday: Bool
    public let defaultIncrementKg: Double
    public let minCalibrationSets: Int
    public let frequencyHitMinSets: Int
    public let deloadAdvisoryDismissedWeekStart: Date?
    public let weeklyRecapShownForWeekStart: Date?

    public init(
        id: UUID, unitsRaw: String, defaultProgressionKindRaw: String,
        warmupSchemeRaw: String, customWarmupPercents: [Double]?,
        plateauWindowSessions: Int, plateauTolerance: Double,
        deloadAlertEnabled: Bool, weekStartsMonday: Bool,
        defaultIncrementKg: Double, minCalibrationSets: Int,
        frequencyHitMinSets: Int,
        deloadAdvisoryDismissedWeekStart: Date?,
        weeklyRecapShownForWeekStart: Date?
    ) {
        self.id = id; self.unitsRaw = unitsRaw
        self.defaultProgressionKindRaw = defaultProgressionKindRaw
        self.warmupSchemeRaw = warmupSchemeRaw
        self.customWarmupPercents = customWarmupPercents
        self.plateauWindowSessions = plateauWindowSessions
        self.plateauTolerance = plateauTolerance
        self.deloadAlertEnabled = deloadAlertEnabled
        self.weekStartsMonday = weekStartsMonday
        self.defaultIncrementKg = defaultIncrementKg
        self.minCalibrationSets = minCalibrationSets
        self.frequencyHitMinSets = frequencyHitMinSets
        self.deloadAdvisoryDismissedWeekStart = deloadAdvisoryDismissedWeekStart
        self.weeklyRecapShownForWeekStart = weeklyRecapShownForWeekStart
    }
}
