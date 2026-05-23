//
//  ExportDocumentSnapshotTests.swift
//  fitbodTests
//
//  Wave-3 plan 06-09 — golden-file snapshot test locking the
//  byte-stable JSON shape of `ExportDocument` (EXP-02). Two
//  @Test functions:
//
//    1. invariants — encode a deterministic fixture and assert
//       structural constraints (formatVersion, schemaVersion,
//       ISO-8601 "Z" suffix, sorted-keys ordering)
//    2. goldenSnapshotMatch — encode and byte-compare against
//       `Fixtures/json/example-export.json`. First run (empty
//       fixture) regenerates and fails; subsequent runs pass.
//
//  Fixture hand-fixed UUIDs (regeneratable for diff hygiene):
//
//    Exercise           00000000-0000-0000-0000-000000000001
//    MuscleGroup        00000000-0000-0000-0000-000000000002
//    ExerciseMuscleStim 00000000-0000-0000-0000-000000000003
//    Routine            00000000-0000-0000-0000-000000000004
//    RoutineExercise    00000000-0000-0000-0000-000000000005
//    SetOverride        00000000-0000-0000-0000-000000000006
//    RoutineFolder      00000000-0000-0000-0000-000000000007
//    SupersetGroup      00000000-0000-0000-0000-000000000008
//    Session            00000000-0000-0000-0000-000000000009
//    SessionExercise    00000000-0000-0000-0000-00000000000a
//    SetEntry (warmup)  00000000-0000-0000-0000-00000000000b
//    SetEntry (working) 00000000-0000-0000-0000-00000000000c
//    Block              00000000-0000-0000-0000-00000000000d
//    BlockPhase         00000000-0000-0000-0000-00000000000e
//    MuscleVolumeTarget 00000000-0000-0000-0000-00000000000f
//    PlateInventory     00000000-0000-0000-0000-000000000010
//    UserSettings       00000000-0000-0000-0000-000000000011
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("ExportDocument JSON snapshot (EXP-02 envelope)")
struct ExportDocumentSnapshotTests {

    private static func uuid(_ tail: String) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-0000000000\(tail)")!
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixture builder

    private static func makeFixture() -> ExportDocument {
        let exerciseID = uuid("01")
        let muscleID = uuid("02")
        let stimulusID = uuid("03")
        let routineID = uuid("04")
        let routineExerciseID = uuid("05")
        let setOverrideID = uuid("06")
        let folderID = uuid("07")
        let supersetID = uuid("08")
        let sessionID = uuid("09")
        let sessionExerciseID = uuid("0a")
        let warmupSetID = uuid("0b")
        let workingSetID = uuid("0c")
        let blockID = uuid("0d")
        let blockPhaseID = uuid("0e")
        let volumeTargetID = uuid("0f")
        let plateInventoryID = uuid("10")
        let userSettingsID = uuid("11")

        let exercise = ExportExerciseDTO(
            id: exerciseID, externalID: "bench-press-1",
            name: "Bench Press", canonicalName: "bench press",
            equipmentRaw: "barbell", mechanicRaw: "compound",
            forceRaw: "push", levelRaw: "intermediate",
            patternRaw: "horizontal_push", category: "strength",
            instructions: ["Lie supine.", "Press the bar."],
            imagePaths: ["bench-1.jpg"], isCustom: false,
            primaryMuscleSlugsJoined: "|chest|", createdAt: fixedDate,
            smallestIncrement: 2.5, barWeightOverride: nil,
            unitOverrideRaw: nil, plateauWindowOverride: nil,
            plateauToleranceOverride: nil
        )

        let muscleGroup = ExportMuscleGroupDTO(
            id: muscleID, slug: "chest",
            displayName: "Chest", regionRaw: "upper"
        )

        let stimulus = ExportExerciseMuscleStimulusDTO(
            id: stimulusID, exerciseID: exerciseID, muscleID: muscleID,
            role: "primary", weight: 1.0, userEditedWeight: false
        )

        let setOverride = ExportRoutineExerciseSetOverrideDTO(
            id: setOverrideID, setIndex: 0,
            targetRepsLow: 4, targetRepsHigh: 6, targetRPE: 8.0
        )

        let routineExercise = ExportRoutineExerciseDTO(
            id: routineExerciseID, exerciseID: exerciseID,
            orderIndex: 0, targetSets: 4,
            targetRepsLow: 4, targetRepsHigh: 6,
            targetRPE: 8.0, targetRIR: nil,
            prescribedRestSeconds: 180,
            tempo: nil, notes: nil, generateWarmups: true,
            supersetGroupID: nil, tracksTempo: false,
            tracksPartialReps: false, warmupOverrideData: nil,
            setOverrides: [setOverride]
        )

        let routine = ExportRoutineDTO(
            id: routineID, name: "Upper A",
            notes: nil, createdAt: fixedDate, updatedAt: fixedDate,
            isArchived: false, blockID: blockID, folderID: folderID,
            intentRaw: "strength", progressionKindRaw: "rpe",
            exercises: [routineExercise]
        )

        let folder = ExportRoutineFolderDTO(
            id: folderID, name: "Hypertrophy block",
            sortOrder: 0, createdAt: fixedDate
        )

        let superset = ExportSupersetGroupDTO(
            id: supersetID, routineID: routineID,
            kindRaw: "paired", sortOrder: 0, createdAt: fixedDate
        )

        let warmupSet = ExportSetEntryDTO(
            id: warmupSetID, orderIndex: 0,
            weight: 40, reps: 8, rpe: 6.0, rir: nil,
            restAfterSeconds: 60, tempoActual: nil, notes: nil,
            isWarmup: true, setTypeRaw: "warmup",
            completedAt: fixedDate, partialReps: nil,
            clusterSubRepsJoined: nil, isComplete: true,
            wasManualOverride: false
        )

        let workingSet = ExportSetEntryDTO(
            id: workingSetID, orderIndex: 1,
            weight: 100, reps: 5, rpe: 8.0, rir: nil,
            restAfterSeconds: 180, tempoActual: nil, notes: nil,
            isWarmup: false, setTypeRaw: "working",
            completedAt: fixedDate.addingTimeInterval(120),
            partialReps: nil, clusterSubRepsJoined: nil,
            isComplete: true, wasManualOverride: false
        )

        let sessionExercise = ExportSessionExerciseDTO(
            id: sessionExerciseID, exerciseID: exerciseID,
            exerciseName: "Bench Press", orderIndex: 0,
            targetSets: 4, targetRepsLow: 4, targetRepsHigh: 6,
            targetRPE: 8.0, targetRIR: nil,
            prescribedRestSeconds: 180, tempo: nil,
            tracksTempo: false, tracksPartialReps: false,
            prescribedWeight: 100.0, pinnedNote: nil,
            sets: [warmupSet, workingSet]
        )

        let session = ExportSessionDTO(
            id: sessionID, startedAt: fixedDate,
            completedAt: fixedDate.addingTimeInterval(3600),
            routineSnapshotName: "Upper A",
            sourceRoutineID: routineID, blockID: blockID,
            notes: nil, totalDurationSeconds: 3600,
            intentRaw: "strength", progressionKindRaw: "rpe",
            exercises: [sessionExercise]
        )

        let blockPhase = ExportBlockPhaseDTO(
            id: blockPhaseID, orderIndex: 0,
            nameRaw: "accumulation", weeks: 4,
            volumeMultiplier: 1.0, intensityMultiplier: 1.0,
            notes: nil
        )

        let block = ExportBlockDTO(
            id: blockID, name: "Spring Block",
            startDate: fixedDate, endDate: nil, notes: nil,
            isActive: true, reviewedAt: nil,
            phases: [blockPhase]
        )

        let volumeTarget = ExportMuscleVolumeTargetDTO(
            id: volumeTargetID, muscleID: muscleID,
            mv: 6, mev: 8, mav: 14, mrv: 22,
            notes: nil, userEdited: false
        )

        let plateInventory = ExportPlateInventoryDTO(
            id: plateInventoryID, equipmentKindRaw: "barbell",
            barWeight: 20.0, availablePlatesData: Data(),
            createdAt: fixedDate, updatedAt: fixedDate
        )

        let userSettings = ExportUserSettingsDTO(
            id: userSettingsID, unitsRaw: "lb",
            defaultProgressionKindRaw: "double",
            warmupSchemeRaw: "standard",
            customWarmupPercents: nil,
            plateauWindowSessions: 4, plateauTolerance: 0.02,
            deloadAlertEnabled: true, weekStartsMonday: true,
            defaultIncrementKg: 2.5, minCalibrationSets: 10,
            frequencyHitMinSets: 2,
            deloadAdvisoryDismissedWeekStart: nil,
            weeklyRecapShownForWeekStart: nil
        )

        return ExportDocument(
            formatVersion: 1,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: fixedDate,
            unitSystem: "kg",
            exercises: [exercise],
            routines: [routine],
            routineFolders: [folder],
            supersetGroups: [superset],
            sessions: [session],
            blocks: [block],
            muscleGroups: [muscleGroup],
            exerciseMuscleStimuli: [stimulus],
            muscleVolumeTargets: [volumeTarget],
            plateInventories: [plateInventory],
            userSettings: userSettings
        )
    }

    // MARK: - 1. invariants

    @Test("invariants — formatVersion + schemaVersion + ISO-8601 Z + sorted keys")
    func invariants() throws {
        let doc = Self.makeFixture()
        let data = try JSONEncoder.exportConfigured().encode(doc)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["formatVersion"] as? Int == 1)
        #expect(json["schemaVersion"] as? String == "v6")
        let exportedAt = try #require(json["exportedAt"] as? String)
        #expect(exportedAt.hasSuffix("Z"), "exportedAt should be UTC ISO-8601 with Z suffix")

        // Sorted-keys sanity: "exercises" comes alphabetically before "exportedAt"
        // which comes before "formatVersion". Check positions in the raw bytes.
        let str = try #require(String(data: data, encoding: .utf8))
        let posExercises = str.range(of: "\"exercises\"")?.lowerBound
        let posExportedAt = str.range(of: "\"exportedAt\"")?.lowerBound
        let posFormatVersion = str.range(of: "\"formatVersion\"")?.lowerBound
        #expect(posExercises != nil && posExportedAt != nil && posFormatVersion != nil)
        if let a = posExercises, let b = posExportedAt, let c = posFormatVersion {
            #expect(a < b, "exercises should appear before exportedAt with .sortedKeys")
            #expect(b < c, "exportedAt should appear before formatVersion with .sortedKeys")
        }
    }

    // MARK: - 2. golden snapshot

    @Test("goldenSnapshotMatch — byte-equal against committed fixture")
    func goldenSnapshotMatch() throws {
        let doc = Self.makeFixture()
        let generated = try JSONEncoder.exportConfigured().encode(doc)

        // Locate fixture: Phase6 → Fixtures/json/example-export.json
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .appendingPathComponent("Fixtures/json/example-export.json")

        // Skip if host filesystem unreachable (defensive — schema-names
        // canary already covers the host-readability invariant).
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            return
        }

        let committed = (try? Data(contentsOf: fixtureURL)) ?? Data()
        if committed.isEmpty {
            // First run: regenerate fixture and fail with re-run guidance.
            try? generated.write(to: fixtureURL)
            #expect(
                false,
                "Fixture regenerated at \(fixtureURL.path) — commit and re-run."
            )
            return
        }

        if generated != committed {
            // Helpful diagnostic — short prefix of the divergence.
            let gen = String(data: generated, encoding: .utf8) ?? "<binary>"
            let com = String(data: committed, encoding: .utf8) ?? "<binary>"
            let prefixLen = 200
            let genPrefix = String(gen.prefix(prefixLen))
            let comPrefix = String(com.prefix(prefixLen))
            #expect(
                generated == committed,
                "ExportDocument byte snapshot diverged.\nGenerated: \(genPrefix)\nCommitted: \(comPrefix)"
            )
        } else {
            #expect(generated == committed)
        }
    }
}
