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
        let docA = try ExportSnapshot.document(in: containerA.mainContext, exportedAt: .distantPast)
        let docB = try ExportSnapshot.document(in: containerB.mainContext, exportedAt: .distantPast)

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
            splits: (splits ?? [])
                .map { ExportSplitDTO(id: $0.id, name: $0.name, createdAt: truncate($0.createdAt), isArchived: $0.isArchived, slots: $0.slots) }
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
            templateName: templateName,
            slotPosition: slotPosition,
            slotSplitName: slotSplitName,
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
            schedulingModeRaw: schedulingModeRaw,
            trainingDaysJoined: trainingDaysJoined,
            archivedConfigJSON: archivedConfigJSON,
            splitName: splitName,
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
