//
//  BackupArchiver.swift
//  fitbod
//
//  Wave-5 plan 06-10 Task 3 — `@ModelActor` off-main archiver that
//  composes the `.fitbodbackup` ZIP container. Reuses 06-09b's
//  ExportService.snapshotDocument logic (via a parallel
//  implementation since ExportService methods are isolated to its
//  own actor) plus 06-09's JSONExporter, and delegates the ZIP
//  container to ZIPWriter from Task 2.
//
//  ## Container format (CONTEXT D-30 — locked over AppleArchive)
//
//  PKWARE ZIP with extension `.fitbodbackup`. Layout:
//
//    fitbod-backup-2026-05-23.fitbodbackup
//    ├── manifest.json          (BackupManifest encoded)
//    ├── store.json             (full ExportDocument encoded)
//    └── images/
//        ├── {exerciseUUID-1}.jpg
//        └── ...
//
//  ## SHA-256 checksum (RESEARCH §Security Domain V10)
//
//  CryptoKit.SHA256.hash(data: storeJSON) — hex-encoded lowercase
//  into manifest.checksum. Restore-side recomputes and rejects on
//  mismatch.
//
//  ## STORE-only in v1
//
//  All entries written with compressionMethod=0 (STORE) via ZIPWriter.
//  CONTEXT D-30 does NOT require compression; ZIP-format conformance
//  is the load-bearing requirement (Finder / `unzip` readability).
//
//  [CITED: CONTEXT D-30 + D-31 + RESEARCH §Pattern 5 REVISED +
//   Open Question 1 RESOLVED]
//

import CryptoKit
import Foundation
import OSLog
import SwiftData

@ModelActor
public actor BackupArchiver {

    private static let log = Logger(subsystem: "com.fitbod.app", category: "backup")

    /// Build a `.fitbodbackup` ZIP archive from the current SwiftData
    /// store and write it to disk. Returns the written file. Restore's
    /// side file and the backup tests use it.
    ///
    /// - Parameters:
    ///   - outputURL: optional output URL; defaults to
    ///     documentDirectory/fitbod-backup-YYYY-MM-DD.fitbodbackup.
    ///   - now: the archive's timestamp. Tests fix it.
    public func archive(outputURL: URL? = nil, now: Date = .now) async throws -> FitbodBackupFile {
        let (zipBytes, imageCount) = try zipArchive(now: now)

        // 9. Resolve outputURL — caller override or
        //    documentDirectory/fitbod-backup-YYYY-MM-DD.fitbodbackup.
        let resolvedURL: URL
        if let outputURL {
            resolvedURL = outputURL
        } else {
            let dir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let filename = Self.dailyFilename(now: now)
            resolvedURL = dir.appendingPathComponent(filename)
        }

        // 10. Atomic write.
        try zipBytes.write(to: resolvedURL, options: .atomic)

        Self.log.info("BackupArchiver wrote \(zipBytes.count) bytes (manifest+store+\(imageCount) images) to \(resolvedURL.lastPathComponent, privacy: .public)")

        return FitbodBackupFile(url: resolvedURL, filename: resolvedURL.lastPathComponent)
    }

    /// The same archive's bytes, unwritten, for Settings' CREATE share
    /// item. Only the bytes leave the actor.
    ///
    /// - Parameter now: the archive's timestamp. Tests fix it.
    public func archiveData(now: Date = .now) throws -> Data {
        try zipArchive(now: now).bytes
    }

    /// Steps 1 to 8: the ZIP bytes and how many images they hold, every
    /// timestamp in them `now`.
    private func zipArchive(now: Date) throws -> (bytes: Data, imageCount: Int) {
        // 1. Build the full ExportDocument from current ModelContext.
        let doc = try buildExportDocument(now: now)

        // 2. Encode store.json via 06-09b's JSONExporter (shared encoder
        //    config; byte-identical to JSON export).
        let storeJSON = try JSONExporter.render(document: doc)

        // 3. Compute SHA-256 hex of store.json bytes.
        let digest = SHA256.hash(data: storeJSON)
        let checksum = digest.map { String(format: "%02x", $0) }.joined()

        // 4. Collect image entries from custom exercises.
        let exercises = try fetchExercisesForImages()
        let imageEntries: [ZIPWriter.Entry] = exercises.compactMap { ex in
            guard let imageData = ex.imageData else { return nil }
            return ZIPWriter.Entry(
                path: "images/\(ex.id.uuidString).jpg",
                data: imageData,
                lastModified: now
            )
        }

        // 5. Build manifest record.
        let manifest = BackupManifest(
            formatVersion: 2,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            createdAt: now,
            checksum: checksum,
            imageCount: imageEntries.count
        )

        // 6. Encode manifest.json (ISO-8601 dates + sortedKeys).
        let manifestJSON = try manifest.encoded()

        // 7. Assemble ZIP entries: manifest first (so an inspector
        //    reading the archive top-down sees it first), then
        //    store.json, then images.
        var entries: [ZIPWriter.Entry] = [
            ZIPWriter.Entry(path: "manifest.json", data: manifestJSON, lastModified: now),
            ZIPWriter.Entry(path: "store.json", data: storeJSON, lastModified: now),
        ]
        entries.append(contentsOf: imageEntries)

        // 8. Write the ZIP container.
        return (try ZIPWriter.write(entries: entries), imageEntries.count)
    }

    // MARK: - Filename

    static func dailyFilename(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return "fitbod-backup-\(formatter.string(from: now)).fitbodbackup"
    }

    // MARK: - ExportDocument assembly (mirrors ExportService.snapshotDocument)
    //
    // We duplicate the snapshot logic here rather than calling
    // ExportService directly because both classes are @ModelActor —
    // they can't share a ModelContext, and routing through a separate
    // actor would round-trip every entity over the actor boundary.
    // Keeping the snapshot code path local to this actor is faster
    // and preserves the canonical mapping rules.

    private func buildExportDocument(now: Date) throws -> ExportDocument {
        let exercises = try fetchExercises().map(mapExercise)
        let muscleGroups = try fetchMuscleGroups().map(mapMuscleGroup)
        let muscleStimuli = try fetchMuscleStimuli().map(mapMuscleStimulus)
        let routineFolders = try fetchRoutineFolders().map(mapRoutineFolder)
        let supersetGroups = try fetchSupersetGroups().map(mapSupersetGroup)
        let routines = try fetchRoutines().map(mapRoutine)
        let splits = try fetchSplits().map(mapSplit)
        let sessions = try fetchSessions().map(mapSession)
        let blocks = try fetchBlocks().map(mapBlock)
        let muscleVolumeTargets = try fetchMuscleVolumeTargets().map(mapMuscleVolumeTarget)
        let plateInventories = try fetchPlateInventories().map(mapPlateInventory)
        let userSettings = try fetchUserSettings().map(mapUserSettings)
        let unitSystem = userSettings?.unitsRaw ?? WeightUnit.default.rawValue

        return ExportDocument(
            formatVersion: 2,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: now,
            unitSystem: unitSystem,
            exercises: exercises,
            routines: routines,
            splits: splits,
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

    // MARK: - Per-entity fetches (sorted by id for deterministic output)

    private func fetchExercises() throws -> [Exercise] {
        try modelContext.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.id)]))
    }

    /// Same query but kept distinct for clarity in the image-collection
    /// step (no need to re-fetch since the data is identical, but
    /// readers find the intent clearer at the call site).
    private func fetchExercisesForImages() throws -> [Exercise] {
        try fetchExercises()
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

    private func fetchSplits() throws -> [Split] {
        try modelContext.fetch(FetchDescriptor<Split>(sortBy: [SortDescriptor(\Split.id)]))
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

    // MARK: - Mappers (mirror ExportService — single contract)

    private func mapSplit(_ split: Split) -> ExportSplitDTO {
        let slots = (split.slots ?? []).sorted { $0.position < $1.position }.map {
            ExportSplitSessionSlotDTO(id: $0.id, position: $0.position, sessionTemplateID: $0.sessionTemplate?.id)
        }
        return ExportSplitDTO(
            id: split.id, name: split.name, createdAt: split.createdAt,
            isArchived: split.isArchived, slots: slots
        )
    }

    private func mapExercise(_ ex: Exercise) -> ExportExerciseDTO {
        ExportExerciseDTO(
            id: ex.id, externalID: ex.externalID, name: ex.name,
            canonicalName: ex.canonicalName,
            equipmentRaw: ex.equipmentRaw, mechanicRaw: ex.mechanicRaw,
            forceRaw: ex.forceRaw, levelRaw: ex.levelRaw,
            patternRaw: ex.patternRaw, category: ex.category,
            instructions: ex.instructions, imagePaths: ex.imagePaths,
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
            id: s.id, exerciseID: s.exercise?.id,
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
            .map(mapRoutineExercise)
        return ExportRoutineDTO(
            id: r.id, name: r.name, notes: r.notes,
            createdAt: r.createdAt, updatedAt: r.updatedAt,
            isArchived: r.isArchived,
            blockID: r.block?.id, folderID: r.folderID,
            intentRaw: r.intentRaw,
            progressionKindRaw: r.progressionKindRaw,
            exercises: exercises
        )
    }

    private func mapRoutineExercise(_ re: SessionExerciseTemplate) -> ExportRoutineExerciseDTO {
        let overrides = (re.setOverrides ?? [])
            .sorted { $0.setIndex < $1.setIndex }
            .map(mapSetOverride)
        return ExportRoutineExerciseDTO(
            id: re.id, exerciseID: re.exercise?.id,
            orderIndex: re.orderIndex, targetSets: re.targetSets,
            targetRepsLow: re.targetRepsLow, targetRepsHigh: re.targetRepsHigh,
            targetRPE: re.targetRPE, targetRIR: re.targetRIR,
            prescribedRestSeconds: re.prescribedRestSeconds,
            tempo: re.tempo, notes: re.notes,
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
            .map(mapSessionExercise)
        return ExportSessionDTO(
            id: s.id, startedAt: s.startedAt,
            completedAt: s.completedAt,
            routineSnapshotName: s.routineSnapshotName,
            sourceRoutineID: s.sourceRoutineID,
            blockID: s.block?.id, notes: s.notes,
            totalDurationSeconds: s.totalDurationSeconds,
            intentRaw: s.intentRaw,
            progressionKindRaw: s.progressionKindRaw,
            templateName: s.templateName,
            slotPosition: s.slot?.position,
            slotSplitName: s.slot?.split?.name,
            slotID: s.slot?.id,
            exercises: exercises
        )
    }

    private func mapSessionExercise(_ se: SessionExercise) -> ExportSessionExerciseDTO {
        let sets = (se.sets ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(mapSetEntry)
        return ExportSessionExerciseDTO(
            id: se.id, exerciseID: se.exercise?.id,
            exerciseName: se.displayName,
            orderIndex: se.orderIndex,
            targetSets: se.targetSets,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE, targetRIR: se.targetRIR,
            prescribedRestSeconds: se.prescribedRestSeconds,
            tempo: se.tempo, tracksTempo: se.tracksTempo,
            tracksPartialReps: se.tracksPartialReps,
            prescribedWeight: se.prescribedWeight,
            pinnedNote: se.pinnedNote,
            exerciseNameSnapshot: se.exerciseNameSnapshot,
            sets: sets
        )
    }

    private func mapSetEntry(_ e: SetEntry) -> ExportSetEntryDTO {
        ExportSetEntryDTO(
            id: e.id, orderIndex: e.orderIndex,
            weight: e.weight, reps: e.reps,
            rpe: e.rpe, rir: e.rir,
            restAfterSeconds: e.restAfterSeconds,
            tempoActual: e.tempoActual, notes: e.notes,
            isWarmup: e.isWarmup, setTypeRaw: e.setTypeRaw,
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
            .map(mapBlockPhase)
        return ExportBlockDTO(
            id: b.id, name: b.name,
            startDate: b.startDate, endDate: b.endDate,
            notes: b.notes, isActive: b.isActive,
            reviewedAt: b.reviewedAt,
            schedulingModeRaw: b.schedulingModeRaw,
            trainingDaysJoined: b.trainingDaysJoined,
            archivedConfigJSON: b.archivedConfigJSON,
            splitName: b.split?.name,
            splitID: b.split?.id,
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
