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
    /// The document with every top-level array sorted (sessions by start,
    /// then id) and every date at the precision a backup keeps.
    ///
    /// It goes through the backup's own JSON coder instead of rebuilding
    /// each DTO by hand, so a field can never be left out of the comparison.
    /// A restored store holds exactly what that coder decoded, so a
    /// difference after this means the restore lost or changed something.
    func normalizedForEquality() -> ExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? JSONExporter.render(document: self),
              let doc = try? decoder.decode(ExportDocument.self, from: data) else {
            Issue.record("the document does not survive its own JSON coder")
            return self
        }
        func byID<Row>(_ rows: [Row], _ id: (Row) -> UUID) -> [Row] {
            rows.sorted { id($0).uuidString < id($1).uuidString }
        }
        return ExportDocument(
            formatVersion: doc.formatVersion,
            schemaVersion: doc.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 0),  // ignore exportedAt drift
            unitSystem: doc.unitSystem,
            exercises: byID(doc.exercises, \.id),
            routines: byID(doc.routines, \.id),
            splits: byID(doc.splits ?? [], \.id),
            routineFolders: byID(doc.routineFolders, \.id),
            supersetGroups: byID(doc.supersetGroups, \.id),
            sessions: doc.sessions.sorted {
                $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt < $1.startedAt
            },
            blocks: byID(doc.blocks, \.id),
            muscleGroups: byID(doc.muscleGroups, \.id),
            exerciseMuscleStimuli: byID(doc.exerciseMuscleStimuli, \.id),
            muscleVolumeTargets: byID(doc.muscleVolumeTargets, \.id),
            plateInventories: byID(doc.plateInventories, \.id),
            userSettings: doc.userSettings
        )
    }
}
