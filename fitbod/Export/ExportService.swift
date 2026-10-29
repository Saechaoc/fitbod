//
//  ExportService.swift
//  fitbod
//
//  Wave-4 plan 06-09b — `@ModelActor` off-main rendering service for
//  the EXP-01 (CSV) + EXP-02 (JSON) exports. SettingsView kicks off
//  rendering via `Task { let file = try await ExportService(...).renderCSV() }`
//  and assigns the resulting Sendable `CSVFile` / `JSONFile` back on
//  the main actor to wire into `ShareLink`.
//
//  ## Why @ModelActor (RESEARCH §Pitfall 13)
//
//  `ShareLink`'s `DataRepresentation` runs its byte-producer closure
//  on the caller's thread. If we built the bytes from inside the
//  closure, a large export would block the main thread while the
//  share sheet animated in. ExportService renders the bytes off main
//  first, hands back a value-typed Transferable, and ShareLink's
//  closure becomes a trivial pass-through.
//
//  ## snapshotDocument
//
//  Reads every SchemaV6 entity and assembles a deterministic
//  `ExportDocument`. Per-entity FetchDescriptors sorted by id (or
//  startedAt for sessions) for round-trip-stable output. Image bytes
//  are intentionally NOT included in the JSON export — 06-10's
//  backup writer is the surface that carries `images/<uuid>.jpg` into
//  the `.fitbodbackup` ZIP.
//
//  [CITED: CONTEXT D-27/D-29 + RESEARCH §Pattern 4 + Pitfall 13]
//

import Foundation
import OSLog
import SwiftData

@ModelActor
public actor ExportService {

    private static let log = Logger(subsystem: "com.fitbod.app", category: "export")

    // MARK: - Public render entry points

    /// Render the full SetEntry history into a CSV `Transferable`
    /// wrapping pre-rendered bytes. Filename is dated to the current
    /// day in ISO format.
    public func renderCSV() async throws -> CSVFile {
        let sets = try fetchAllCompletedSets()
        let settings = try fetchUserSettings()
        let data = CSVExporter.render(setEntries: sets, userSettings: settings)
        let filename = Self.dailyFilename(prefix: "fitbod-export", ext: "csv")
        return CSVFile(data: data, filename: filename)
    }

    /// Render the full schema snapshot into a JSON `Transferable`
    /// wrapping pre-rendered bytes via 06-09's `JSONEncoder.exportConfigured()`.
    public func renderJSON() async throws -> JSONFile {
        let doc = try await snapshotDocument()
        let data = try JSONExporter.render(document: doc)
        let filename = Self.dailyFilename(prefix: "fitbod-export", ext: "json")
        return JSONFile(data: data, filename: filename)
    }

    /// Build an `ExportDocument` from the current SwiftData store.
    /// Surface used both by `renderJSON()` and by 06-10's
    /// `BackupArchiver` (so backup + JSON export share one source of
    /// truth — single snapshot definition).
    public func snapshotDocument() async throws -> ExportDocument {
        let exercises = try fetchExercises().map { mapExercise($0) }
        let muscleGroups = try fetchMuscleGroups().map { mapMuscleGroup($0) }
        let muscleStimuli = try fetchMuscleStimuli().map { mapMuscleStimulus($0) }
        let routineFolders = try fetchRoutineFolders().map { mapRoutineFolder($0) }
        let supersetGroups = try fetchSupersetGroups().map { mapSupersetGroup($0) }
        let routines = try fetchRoutines().map { mapRoutine($0) }
        let sessions = try fetchSessions().map { mapSession($0) }
        let blocks = try fetchBlocks().map { mapBlock($0) }
        let muscleVolumeTargets = try fetchMuscleVolumeTargets().map { mapMuscleVolumeTarget($0) }
        let plateInventories = try fetchPlateInventories().map { mapPlateInventory($0) }
        let userSettings = try fetchUserSettings().map { mapUserSettings($0) }
        let unitSystem = userSettings?.unitsRaw ?? WeightUnit.default.rawValue

        return ExportDocument(
            formatVersion: 1,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: Date.now,
            unitSystem: unitSystem,
            exercises: exercises,
            routines: routines,
            routineFolders: routineFolders,
            supersetGroups: supersetGroups,
            sessions: sessions,
            blocks: blocks,
            muscleGroups: muscleGroups,
            exerciseMuscleStimuli: muscleStimuli,
            muscleVolumeTargets: muscleVolumeTargets,
            plateInventories: plateInventories,
            userSettings: userSettings
        )
    }

    // MARK: - Filename helper

    static func dailyFilename(prefix: String, ext: String, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        return "\(prefix)-\(date).\(ext)"
    }

    // MARK: - Per-entity fetch helpers

    private func fetchAllCompletedSets() throws -> [SetEntry] {
        try modelContext.fetch(FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.isComplete },
            sortBy: [SortDescriptor(\SetEntry.completedAt)]
        ))
    }

    private func fetchExercises() throws -> [Exercise] {
        try modelContext.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.id)]))
    }

    private func fetchMuscleGroups() throws -> [MuscleGroup] {
        try modelContext.fetch(FetchDescriptor<MuscleGroup>(sortBy: [SortDescriptor(\MuscleGroup.id)]))
    }

    private func fetchMuscleStimuli() throws -> [ExerciseMuscleStimulus] {
        try modelContext.fetch(FetchDescriptor<ExerciseMuscleStimulus>(sortBy: [SortDescriptor(\ExerciseMuscleStimulus.id)]))
    }

    private func fetchRoutineFolders() throws -> [RoutineFolder] {
        try modelContext.fetch(FetchDescriptor<RoutineFolder>(sortBy: [SortDescriptor(\RoutineFolder.id)]))
    }

    private func fetchSupersetGroups() throws -> [SupersetGroup] {
        try modelContext.fetch(FetchDescriptor<SupersetGroup>(sortBy: [SortDescriptor(\SupersetGroup.id)]))
    }

    private func fetchRoutines() throws -> [SessionTemplate] {
        try modelContext.fetch(FetchDescriptor<SessionTemplate>(sortBy: [SortDescriptor(\SessionTemplate.id)]))
    }

    private func fetchSessions() throws -> [Session] {
        try modelContext.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\Session.startedAt)]))
    }

    private func fetchBlocks() throws -> [Block] {
        try modelContext.fetch(FetchDescriptor<Block>(sortBy: [SortDescriptor(\Block.id)]))
    }

    private func fetchMuscleVolumeTargets() throws -> [MuscleVolumeTarget] {
        try modelContext.fetch(FetchDescriptor<MuscleVolumeTarget>(sortBy: [SortDescriptor(\MuscleVolumeTarget.id)]))
    }

    private func fetchPlateInventories() throws -> [PlateInventory] {
        try modelContext.fetch(FetchDescriptor<PlateInventory>(sortBy: [SortDescriptor(\PlateInventory.id)]))
    }

    private func fetchUserSettings() throws -> UserSettings? {
        try modelContext.fetch(FetchDescriptor<UserSettings>()).first
    }

    // MARK: - Mappers (model → DTO)

    private func mapExercise(_ ex: Exercise) -> ExportExerciseDTO {
        ExportExerciseDTO(
            id: ex.id,
            externalID: ex.externalID,
            name: ex.name,
            canonicalName: ex.canonicalName,
            equipmentRaw: ex.equipmentRaw,
            mechanicRaw: ex.mechanicRaw,
            forceRaw: ex.forceRaw,
            levelRaw: ex.levelRaw,
            patternRaw: ex.patternRaw,
            category: ex.category,
            instructions: ex.instructions,
            imagePaths: ex.imagePaths,
            isCustom: ex.isCustom,
            primaryMuscleSlugsJoined: ex.primaryMuscleSlugsJoined,
            createdAt: ex.createdAt,
            smallestIncrement: ex.smallestIncrement,
            barWeightOverride: ex.barWeightOverride,
            unitOverrideRaw: ex.unitOverrideRaw,
            plateauWindowOverride: ex.plateauWindowOverride,
            plateauToleranceOverride: ex.plateauToleranceOverride
        )
    }

    private func mapMuscleGroup(_ m: MuscleGroup) -> ExportMuscleGroupDTO {
        ExportMuscleGroupDTO(
            id: m.id, slug: m.slug,
            displayName: m.displayName, regionRaw: m.regionRaw
        )
    }

    private func mapMuscleStimulus(_ s: ExerciseMuscleStimulus) -> ExportExerciseMuscleStimulusDTO {
        ExportExerciseMuscleStimulusDTO(
            id: s.id,
            exerciseID: s.exercise?.id,
            muscleID: s.muscle?.id,
            role: s.role, weight: s.weight,
            userEditedWeight: s.userEditedWeight
        )
    }

    private func mapRoutineFolder(_ f: RoutineFolder) -> ExportRoutineFolderDTO {
        ExportRoutineFolderDTO(
            id: f.id, name: f.name,
            sortOrder: f.sortOrder, createdAt: f.createdAt
        )
    }

    private func mapSupersetGroup(_ s: SupersetGroup) -> ExportSupersetGroupDTO {
        ExportSupersetGroupDTO(
            id: s.id, routineID: s.routineID,
            kindRaw: s.kindRaw, sortOrder: s.sortOrder,
            createdAt: s.createdAt
        )
    }

    private func mapRoutine(_ r: SessionTemplate) -> ExportRoutineDTO {
        let exercises = (r.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapRoutineExercise($0) }
        return ExportRoutineDTO(
            id: r.id, name: r.name, notes: r.notes,
            createdAt: r.createdAt, updatedAt: r.updatedAt,
            isArchived: r.isArchived,
            blockID: r.block?.id,
            folderID: r.folderID,
            intentRaw: r.intentRaw,
            progressionKindRaw: r.progressionKindRaw,
            exercises: exercises
        )
    }

    private func mapRoutineExercise(_ re: SessionExerciseTemplate) -> ExportRoutineExerciseDTO {
        let overrides = (re.setOverrides ?? [])
            .sorted { $0.setIndex < $1.setIndex }
            .map { mapSetOverride($0) }
        return ExportRoutineExerciseDTO(
            id: re.id,
            exerciseID: re.exercise?.id,
            orderIndex: re.orderIndex,
            targetSets: re.targetSets,
            targetRepsLow: re.targetRepsLow,
            targetRepsHigh: re.targetRepsHigh,
            targetRPE: re.targetRPE,
            targetRIR: re.targetRIR,
            prescribedRestSeconds: re.prescribedRestSeconds,
            tempo: re.tempo,
            notes: re.notes,
            generateWarmups: re.generateWarmups,
            supersetGroupID: re.supersetGroupID,
            tracksTempo: re.tracksTempo,
            tracksPartialReps: re.tracksPartialReps,
            warmupOverrideData: re.warmupOverrideData,
            setOverrides: overrides
        )
    }

    private func mapSetOverride(_ s: RoutineExerciseSetOverride) -> ExportRoutineExerciseSetOverrideDTO {
        ExportRoutineExerciseSetOverrideDTO(
            id: s.id, setIndex: s.setIndex,
            targetRepsLow: s.targetRepsLow,
            targetRepsHigh: s.targetRepsHigh,
            targetRPE: s.targetRPE
        )
    }

    private func mapSession(_ s: Session) -> ExportSessionDTO {
        let exercises = (s.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapSessionExercise($0) }
        return ExportSessionDTO(
            id: s.id, startedAt: s.startedAt,
            completedAt: s.completedAt,
            routineSnapshotName: s.routineSnapshotName,
            sourceRoutineID: s.sourceRoutineID,
            blockID: s.block?.id,
            notes: s.notes,
            totalDurationSeconds: s.totalDurationSeconds,
            intentRaw: s.intentRaw,
            progressionKindRaw: s.progressionKindRaw,
            templateName: s.templateName,
            slotPosition: s.slot?.position,
            slotSplitName: s.slot?.split?.name,
            exercises: exercises
        )
    }

    private func mapSessionExercise(_ se: SessionExercise) -> ExportSessionExerciseDTO {
        let sets = (se.sets ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapSetEntry($0) }
        return ExportSessionExerciseDTO(
            id: se.id,
            exerciseID: se.exercise?.id,
            exerciseName: se.exercise?.name ?? "",   // Open Q2 deferred
            orderIndex: se.orderIndex,
            targetSets: se.targetSets,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            targetRIR: se.targetRIR,
            prescribedRestSeconds: se.prescribedRestSeconds,
            tempo: se.tempo,
            tracksTempo: se.tracksTempo,
            tracksPartialReps: se.tracksPartialReps,
            prescribedWeight: se.prescribedWeight,
            pinnedNote: se.pinnedNote,
            sets: sets
        )
    }

    private func mapSetEntry(_ e: SetEntry) -> ExportSetEntryDTO {
        ExportSetEntryDTO(
            id: e.id, orderIndex: e.orderIndex,
            weight: e.weight, reps: e.reps,
            rpe: e.rpe, rir: e.rir,
            restAfterSeconds: e.restAfterSeconds,
            tempoActual: e.tempoActual,
            notes: e.notes, isWarmup: e.isWarmup,
            setTypeRaw: e.setTypeRaw,
            completedAt: e.completedAt,
            partialReps: e.partialReps,
            clusterSubRepsJoined: e.clusterSubRepsJoined,
            isComplete: e.isComplete,
            wasManualOverride: e.wasManualOverride
        )
    }

    private func mapBlock(_ b: Block) -> ExportBlockDTO {
        let phases = (b.phases ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapBlockPhase($0) }
        return ExportBlockDTO(
            id: b.id, name: b.name,
            startDate: b.startDate, endDate: b.endDate,
            notes: b.notes, isActive: b.isActive,
            reviewedAt: b.reviewedAt,
            schedulingModeRaw: b.schedulingModeRaw,
            trainingDaysJoined: b.trainingDaysJoined,
            archivedConfigJSON: b.archivedConfigJSON,
            splitName: b.split?.name,
            phases: phases
        )
    }

    private func mapBlockPhase(_ p: BlockPhase) -> ExportBlockPhaseDTO {
        ExportBlockPhaseDTO(
            id: p.id, orderIndex: p.orderIndex,
            nameRaw: p.nameRaw, weeks: p.weeks,
            volumeMultiplier: p.volumeMultiplier,
            intensityMultiplier: p.intensityMultiplier,
            notes: p.notes
        )
    }

    private func mapMuscleVolumeTarget(_ t: MuscleVolumeTarget) -> ExportMuscleVolumeTargetDTO {
        ExportMuscleVolumeTargetDTO(
            id: t.id, muscleID: t.muscle?.id,
            mv: t.mv, mev: t.mev, mav: t.mav, mrv: t.mrv,
            notes: t.notes, userEdited: t.userEdited
        )
    }

    private func mapPlateInventory(_ pi: PlateInventory) -> ExportPlateInventoryDTO {
        ExportPlateInventoryDTO(
            id: pi.id, equipmentKindRaw: pi.equipmentKindRaw,
            barWeight: pi.barWeight,
            availablePlatesData: pi.availablePlatesData,
            createdAt: pi.createdAt, updatedAt: pi.updatedAt
        )
    }

    private func mapUserSettings(_ s: UserSettings) -> ExportUserSettingsDTO {
        ExportUserSettingsDTO(
            id: s.id, unitsRaw: s.unitsRaw,
            defaultProgressionKindRaw: s.defaultProgressionKindRaw,
            warmupSchemeRaw: s.warmupSchemeRaw,
            customWarmupPercents: s.customWarmupPercents,
            plateauWindowSessions: s.plateauWindowSessions,
            plateauTolerance: s.plateauTolerance,
            deloadAlertEnabled: s.deloadAlertEnabled,
            weekStartsMonday: s.weekStartsMonday,
            defaultIncrementKg: s.defaultIncrementKg,
            minCalibrationSets: s.minCalibrationSets,
            frequencyHitMinSets: s.frequencyHitMinSets,
            deloadAdvisoryDismissedWeekStart: s.deloadAdvisoryDismissedWeekStart,
            weeklyRecapShownForWeekStart: s.weeklyRecapShownForWeekStart
        )
    }
}
