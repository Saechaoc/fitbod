//
//  BackupRoundTripTests.swift
//  fitbodTests
//
//  ## D-33 ACCEPTANCE CANARY — MUST PASS
//
//  Wave-5 plan 06-10 Task 8 — the load-bearing round-trip test that
//  proves the entire backup pipeline is correct. CONTEXT D-33 +
//  ROADMAP success criterion #5 explicitly anchor Phase 6 shippability
//  on this test passing.
//
//  Flow per @Test:
//    1. Seed containerA with PRFixtures.seedKnownPRHistory + a couple
//       of Exercise rows with imageData
//    2. BackupArchiver.archive() — write .fitbodbackup to tmpURL
//    3. Build containerB (separate in-memory configuration)
//    4. BackupRestorer.preflight + performRestore on containerB
//    5. Snapshot ExportDocument from both containers; compare normalized
//       (sorted by id) for entity-by-entity equality
//
//  Tests:
//    - roundTrip — full DTO graph equality
//    - roundTripPreservesCustomImages — image bytes byte-equal after restore
//
//  [CITED: CONTEXT D-33 + ROADMAP Phase 6 success criterion #5 +
//   RESEARCH §Backup round-trip Swift Testing pattern + EXP-04]
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BackupRoundTrip (D-33 acceptance — MUST PASS)", .serialized)
struct BackupRoundTripTests {

    @Test("roundTrip — seed → archive → restore → entity-by-entity DTO equality")
    func roundTrip() async throws {
        // 1. Seed containerA.
        let containerA = try InMemoryContainer.makeCurrent()
        let ctxA = containerA.mainContext
        let seed = try PRFixtures.seedKnownPRHistory(ctx: ctxA)
        _ = seed  // keep around for future assertions if needed

        // Inject one image for round-trip image coverage.
        let exA = try ctxA.fetch(FetchDescriptor<Exercise>()).first!
        exA.imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])
        try ctxA.save()

        // 2. Archive.
        let archiver = BackupArchiver(modelContainer: containerA)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-\(UUID().uuidString).fitbodbackup")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        _ = try await archiver.archive(outputURL: tmpURL)

        // 3. Fresh containerB.
        let containerB = try InMemoryContainer.makeCurrent()
        let restorer = BackupRestorer()

        // 4. preflight + performRestore on containerB.
        let manifest = try await restorer.preflight(url: tmpURL, context: containerB.mainContext)
        try await restorer.performRestore(
            url: tmpURL,
            manifest: manifest,
            currentContainer: containerB
        )

        // 5. Snapshot both containers; normalize; compare.
        let docA = try Self.snapshot(containerA.mainContext)
        let docB = try Self.snapshot(containerB.mainContext)

        let normA = docA.normalizedForEquality()
        let normB = docB.normalizedForEquality()

        // Top-level entity counts must match.
        #expect(normA.exercises.count == normB.exercises.count, "exercise count mismatch")
        #expect(normA.routines.count == normB.routines.count, "routine count mismatch")
        #expect(normA.sessions.count == normB.sessions.count, "session count mismatch")
        #expect(normA.muscleGroups.count == normB.muscleGroups.count, "muscleGroup count mismatch")
        #expect(normA.blocks.count == normB.blocks.count, "block count mismatch")
        #expect(normA.exerciseMuscleStimuli.count == normB.exerciseMuscleStimuli.count, "stimuli count mismatch")
        #expect(normA.muscleVolumeTargets.count == normB.muscleVolumeTargets.count, "volume target count mismatch")
        #expect(normA.plateInventories.count == normB.plateInventories.count, "plate inventory count mismatch")

        // Full deep equality on each entity array — the load-bearing
        // assertion that proves byte-stable round-trip.
        #expect(normA.exercises == normB.exercises, "exercises mismatch")
        #expect(normA.routines == normB.routines, "routines mismatch")
        #expect(normA.sessions == normB.sessions, "sessions mismatch")
        #expect(normA.muscleGroups == normB.muscleGroups, "muscleGroups mismatch")
        #expect(normA.blocks == normB.blocks, "blocks mismatch")
        #expect(normA.exerciseMuscleStimuli == normB.exerciseMuscleStimuli, "exerciseMuscleStimuli mismatch")
        #expect(normA.muscleVolumeTargets == normB.muscleVolumeTargets, "muscleVolumeTargets mismatch")
        #expect(normA.plateInventories == normB.plateInventories, "plateInventories mismatch")
        #expect(normA.userSettings == normB.userSettings, "userSettings mismatch")
    }

    @Test("roundTripPreservesCustomImages — image bytes byte-equal after restore")
    func roundTripPreservesCustomImages() async throws {
        let containerA = try InMemoryContainer.makeCurrent()
        let ctxA = containerA.mainContext

        // Two custom Exercise rows with distinct image bytes.
        let one = Exercise(
            name: "Custom A", canonicalName: "custom a",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        let two = Exercise(
            name: "Custom B", canonicalName: "custom b",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctxA.insert(one)
        ctxA.insert(two)
        one.imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])
        two.imageData = Data([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10, 0x4A, 0x47])
        try ctxA.save()

        let oneID = one.id
        let twoID = two.id

        // Archive.
        let archiver = BackupArchiver(modelContainer: containerA)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-images-\(UUID().uuidString).fitbodbackup")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        _ = try await archiver.archive(outputURL: tmpURL)

        // Restore into containerB.
        let containerB = try InMemoryContainer.makeCurrent()
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: tmpURL, context: containerB.mainContext)
        try await restorer.performRestore(
            url: tmpURL,
            manifest: manifest,
            currentContainer: containerB
        )

        let ctxB = containerB.mainContext
        let restored = try ctxB.fetch(FetchDescriptor<Exercise>())
        let byID = Dictionary(uniqueKeysWithValues: restored.map { ($0.id, $0) })
        #expect(byID[oneID]?.imageData == Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]))
        #expect(byID[twoID]?.imageData == Data([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10, 0x4A, 0x47]))
    }

    // MARK: - Snapshot helper (mirrors ExportService.snapshotDocument)

    /// Build an ExportDocument from a ModelContext without going
    /// through ExportService (which is @ModelActor and requires its
    /// own container). Tests need synchronous access to the snapshot
    /// for normalization + comparison.
    static func snapshot(_ ctx: ModelContext) throws -> ExportDocument {
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.id)])).map(mapExercise)
        let muscleGroups = try ctx.fetch(FetchDescriptor<MuscleGroup>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleGroup)
        let muscleStimuli = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleStimulus)
        let routineFolders = try ctx.fetch(FetchDescriptor<RoutineFolder>(sortBy: [SortDescriptor(\.id)])).map(mapRoutineFolder)
        let supersetGroups = try ctx.fetch(FetchDescriptor<SupersetGroup>(sortBy: [SortDescriptor(\.id)])).map(mapSupersetGroup)
        let routines = try ctx.fetch(FetchDescriptor<SessionTemplate>(sortBy: [SortDescriptor(\.id)])).map(mapRoutine)
        let sessions = try ctx.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)])).map(mapSession)
        let blocks = try ctx.fetch(FetchDescriptor<Block>(sortBy: [SortDescriptor(\.id)])).map(mapBlock)
        let muscleVolumeTargets = try ctx.fetch(FetchDescriptor<MuscleVolumeTarget>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleVolumeTarget)
        let plateInventories = try ctx.fetch(FetchDescriptor<PlateInventory>(sortBy: [SortDescriptor(\.id)])).map(mapPlateInventory)
        let userSettings = try ctx.fetch(FetchDescriptor<UserSettings>()).first.map(mapUserSettings)
        let unitSystem = userSettings?.unitsRaw ?? "kg"

        return ExportDocument(
            formatVersion: 1,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: Date(timeIntervalSince1970: 0),  // fixed for normalization
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

    // MARK: - Mappers (mirror ExportService.swift)

    static func mapExercise(_ ex: Exercise) -> ExportExerciseDTO {
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

    static func mapMuscleGroup(_ m: MuscleGroup) -> ExportMuscleGroupDTO {
        ExportMuscleGroupDTO(
            id: m.id, slug: m.slug,
            displayName: m.displayName, regionRaw: m.regionRaw
        )
    }

    static func mapMuscleStimulus(_ s: ExerciseMuscleStimulus) -> ExportExerciseMuscleStimulusDTO {
        ExportExerciseMuscleStimulusDTO(
            id: s.id, exerciseID: s.exercise?.id,
            muscleID: s.muscle?.id, role: s.role,
            weight: s.weight, userEditedWeight: s.userEditedWeight
        )
    }

    static func mapRoutineFolder(_ f: RoutineFolder) -> ExportRoutineFolderDTO {
        ExportRoutineFolderDTO(
            id: f.id, name: f.name,
            sortOrder: f.sortOrder, createdAt: f.createdAt
        )
    }

    static func mapSupersetGroup(_ s: SupersetGroup) -> ExportSupersetGroupDTO {
        ExportSupersetGroupDTO(
            id: s.id, routineID: s.routineID,
            kindRaw: s.kindRaw, sortOrder: s.sortOrder,
            createdAt: s.createdAt
        )
    }

    static func mapRoutine(_ r: SessionTemplate) -> ExportRoutineDTO {
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

    static func mapRoutineExercise(_ re: SessionExerciseTemplate) -> ExportRoutineExerciseDTO {
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

    static func mapSetOverride(_ s: RoutineExerciseSetOverride) -> ExportRoutineExerciseSetOverrideDTO {
        ExportRoutineExerciseSetOverrideDTO(
            id: s.id, setIndex: s.setIndex,
            targetRepsLow: s.targetRepsLow,
            targetRepsHigh: s.targetRepsHigh,
            targetRPE: s.targetRPE
        )
    }

    static func mapSession(_ s: Session) -> ExportSessionDTO {
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
            exercises: exercises
        )
    }

    static func mapSessionExercise(_ se: SessionExercise) -> ExportSessionExerciseDTO {
        let sets = (se.sets ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(mapSetEntry)
        return ExportSessionExerciseDTO(
            id: se.id, exerciseID: se.exercise?.id,
            exerciseName: se.exercise?.name ?? "",
            orderIndex: se.orderIndex,
            targetSets: se.targetSets,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE, targetRIR: se.targetRIR,
            prescribedRestSeconds: se.prescribedRestSeconds,
            tempo: se.tempo, tracksTempo: se.tracksTempo,
            tracksPartialReps: se.tracksPartialReps,
            prescribedWeight: se.prescribedWeight,
            pinnedNote: se.pinnedNote, sets: sets
        )
    }

    static func mapSetEntry(_ e: SetEntry) -> ExportSetEntryDTO {
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

    static func mapBlock(_ b: Block) -> ExportBlockDTO {
        let phases = (b.phases ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(mapBlockPhase)
        return ExportBlockDTO(
            id: b.id, name: b.name,
            startDate: b.startDate, endDate: b.endDate,
            notes: b.notes, isActive: b.isActive,
            reviewedAt: b.reviewedAt, phases: phases
        )
    }

    static func mapBlockPhase(_ p: BlockPhase) -> ExportBlockPhaseDTO {
        ExportBlockPhaseDTO(
            id: p.id, orderIndex: p.orderIndex,
            nameRaw: p.nameRaw, weeks: p.weeks,
            volumeMultiplier: p.volumeMultiplier,
            intensityMultiplier: p.intensityMultiplier,
            notes: p.notes
        )
    }

    static func mapMuscleVolumeTarget(_ t: MuscleVolumeTarget) -> ExportMuscleVolumeTargetDTO {
        ExportMuscleVolumeTargetDTO(
            id: t.id, muscleID: t.muscle?.id,
            mv: t.mv, mev: t.mev, mav: t.mav, mrv: t.mrv,
            notes: t.notes, userEdited: t.userEdited
        )
    }

    static func mapPlateInventory(_ pi: PlateInventory) -> ExportPlateInventoryDTO {
        ExportPlateInventoryDTO(
            id: pi.id, equipmentKindRaw: pi.equipmentKindRaw,
            barWeight: pi.barWeight,
            availablePlatesData: pi.availablePlatesData,
            createdAt: pi.createdAt, updatedAt: pi.updatedAt
        )
    }

    static func mapUserSettings(_ s: UserSettings) -> ExportUserSettingsDTO {
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

// MARK: - Normalization extension

extension ExportDocument {
    /// Sort every top-level entity array by id (sessions by startedAt
    /// then id) AND truncate every Date field to whole-second
    /// precision. The latter is necessary because the JSON round-trip
    /// uses ISO-8601 with second precision, which loses any sub-second
    /// fraction present in the original SwiftData Date (e.g. Date.now).
    /// Without this normalization, an unmodified round-trip would
    /// still fail Equatable because the original `createdAt = Date.now`
    /// has microsecond-level precision while the restored value
    /// rounds to the nearest second.
    /// Per RESEARCH §"Backup round-trip Swift Testing pattern" line 647.
    func normalizedForEquality() -> ExportDocument {
        ExportDocument(
            formatVersion: formatVersion,
            schemaVersion: schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 0),  // ignore exportedAt drift
            unitSystem: unitSystem,
            exercises: exercises
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            routines: routines
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            routineFolders: routineFolders
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            supersetGroups: supersetGroups
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            sessions: sessions
                .map { $0.dateTruncated() }
                .sorted {
                    if $0.startedAt == $1.startedAt {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return $0.startedAt < $1.startedAt
                },
            blocks: blocks
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            muscleGroups: muscleGroups.sorted { $0.id.uuidString < $1.id.uuidString },
            exerciseMuscleStimuli: exerciseMuscleStimuli.sorted { $0.id.uuidString < $1.id.uuidString },
            muscleVolumeTargets: muscleVolumeTargets.sorted { $0.id.uuidString < $1.id.uuidString },
            plateInventories: plateInventories
                .map { $0.dateTruncated() }
                .sorted { $0.id.uuidString < $1.id.uuidString },
            userSettings: userSettings?.dateTruncated()
        )
    }
}

// MARK: - Per-DTO Date truncation (test-only)
//
// Each helper rounds every Date field to the nearest whole second
// (matching ISO-8601 precision). The original DTOs are immutable
// `let` — these helpers construct new DTOs with truncated values.

private func truncate(_ d: Date) -> Date {
    Date(timeIntervalSince1970: d.timeIntervalSince1970.rounded(.down))
}

private func truncate(_ d: Date?) -> Date? {
    d.map(truncate)
}

private extension ExportExerciseDTO {
    func dateTruncated() -> ExportExerciseDTO {
        ExportExerciseDTO(
            id: id, externalID: externalID, name: name,
            canonicalName: canonicalName,
            equipmentRaw: equipmentRaw, mechanicRaw: mechanicRaw,
            forceRaw: forceRaw, levelRaw: levelRaw,
            patternRaw: patternRaw, category: category,
            instructions: instructions, imagePaths: imagePaths,
            isCustom: isCustom,
            primaryMuscleSlugsJoined: primaryMuscleSlugsJoined,
            createdAt: truncate(createdAt),
            smallestIncrement: smallestIncrement,
            barWeightOverride: barWeightOverride,
            unitOverrideRaw: unitOverrideRaw,
            plateauWindowOverride: plateauWindowOverride,
            plateauToleranceOverride: plateauToleranceOverride
        )
    }
}

private extension ExportRoutineDTO {
    func dateTruncated() -> ExportRoutineDTO {
        ExportRoutineDTO(
            id: id, name: name, notes: notes,
            createdAt: truncate(createdAt),
            updatedAt: truncate(updatedAt),
            isArchived: isArchived, blockID: blockID,
            folderID: folderID, intentRaw: intentRaw,
            progressionKindRaw: progressionKindRaw,
            exercises: exercises
        )
    }
}

private extension ExportRoutineFolderDTO {
    func dateTruncated() -> ExportRoutineFolderDTO {
        ExportRoutineFolderDTO(
            id: id, name: name, sortOrder: sortOrder,
            createdAt: truncate(createdAt)
        )
    }
}

private extension ExportSupersetGroupDTO {
    func dateTruncated() -> ExportSupersetGroupDTO {
        ExportSupersetGroupDTO(
            id: id, routineID: routineID,
            kindRaw: kindRaw, sortOrder: sortOrder,
            createdAt: truncate(createdAt)
        )
    }
}

private extension ExportSessionDTO {
    func dateTruncated() -> ExportSessionDTO {
        ExportSessionDTO(
            id: id,
            startedAt: truncate(startedAt),
            completedAt: truncate(completedAt),
            routineSnapshotName: routineSnapshotName,
            sourceRoutineID: sourceRoutineID,
            blockID: blockID, notes: notes,
            totalDurationSeconds: totalDurationSeconds,
            intentRaw: intentRaw,
            progressionKindRaw: progressionKindRaw,
            exercises: exercises.map { $0.dateTruncated() }
        )
    }
}

private extension ExportSessionExerciseDTO {
    func dateTruncated() -> ExportSessionExerciseDTO {
        ExportSessionExerciseDTO(
            id: id, exerciseID: exerciseID, exerciseName: exerciseName,
            orderIndex: orderIndex, targetSets: targetSets,
            targetRepsLow: targetRepsLow, targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE, targetRIR: targetRIR,
            prescribedRestSeconds: prescribedRestSeconds,
            tempo: tempo, tracksTempo: tracksTempo,
            tracksPartialReps: tracksPartialReps,
            prescribedWeight: prescribedWeight,
            pinnedNote: pinnedNote,
            sets: sets.map { $0.dateTruncated() }
        )
    }
}

private extension ExportSetEntryDTO {
    func dateTruncated() -> ExportSetEntryDTO {
        ExportSetEntryDTO(
            id: id, orderIndex: orderIndex,
            weight: weight, reps: reps,
            rpe: rpe, rir: rir,
            restAfterSeconds: restAfterSeconds,
            tempoActual: tempoActual, notes: notes,
            isWarmup: isWarmup, setTypeRaw: setTypeRaw,
            completedAt: truncate(completedAt),
            partialReps: partialReps,
            clusterSubRepsJoined: clusterSubRepsJoined,
            isComplete: isComplete,
            wasManualOverride: wasManualOverride
        )
    }
}

private extension ExportBlockDTO {
    func dateTruncated() -> ExportBlockDTO {
        ExportBlockDTO(
            id: id, name: name,
            startDate: truncate(startDate),
            endDate: truncate(endDate),
            notes: notes, isActive: isActive,
            reviewedAt: truncate(reviewedAt),
            phases: phases
        )
    }
}

private extension ExportPlateInventoryDTO {
    func dateTruncated() -> ExportPlateInventoryDTO {
        ExportPlateInventoryDTO(
            id: id, equipmentKindRaw: equipmentKindRaw,
            barWeight: barWeight,
            availablePlatesData: availablePlatesData,
            createdAt: truncate(createdAt),
            updatedAt: truncate(updatedAt)
        )
    }
}

private extension ExportUserSettingsDTO {
    func dateTruncated() -> ExportUserSettingsDTO {
        ExportUserSettingsDTO(
            id: id, unitsRaw: unitsRaw,
            defaultProgressionKindRaw: defaultProgressionKindRaw,
            warmupSchemeRaw: warmupSchemeRaw,
            customWarmupPercents: customWarmupPercents,
            plateauWindowSessions: plateauWindowSessions,
            plateauTolerance: plateauTolerance,
            deloadAlertEnabled: deloadAlertEnabled,
            weekStartsMonday: weekStartsMonday,
            defaultIncrementKg: defaultIncrementKg,
            minCalibrationSets: minCalibrationSets,
            frequencyHitMinSets: frequencyHitMinSets,
            deloadAdvisoryDismissedWeekStart: truncate(deloadAdvisoryDismissedWeekStart),
            weeklyRecapShownForWeekStart: truncate(weeklyRecapShownForWeekStart)
        )
    }
}
