//
//  BackupCatalogFieldsTests.swift
//  fitbodTests
//
//  The RM-022 / RM-062 fields in a backup (format 3):
//    - every new field survives archive and restore;
//    - a format-2 backup, which has none of the keys, still restores and the
//      fields take the model defaults;
//    - a backup in a format newer than this build writes is refused before
//      anything is replaced;
//    - restore clears the seed stamp, so the next seed applies the bundled
//      curation to the restored catalog.
//

import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Backup catalog and set fields", .serialized)
struct BackupCatalogFieldsTests {
    private static let date = Date(timeIntervalSince1970: 1_700_000_000)

    private static let exerciseKeys = [
        "familyName", "variantLabel", "aliasesJoined", "trackingRaw", "brand", "loadingRaw", "isHidden",
    ]
    private static let setKeys = ["startedAt", "durationSeconds", "distanceMeters", "level"]

    @Test("every new field survives archive and restore")
    func everyNewFieldRoundTrips() async throws {
        let source = try makeContainer()
        try seed(in: source.mainContext)
        let url = try await archive(source)
        defer { try? FileManager.default.removeItem(at: url) }

        let destination = try makeContainer()
        try await restore(url, into: destination)

        let exercise = try #require(try destination.mainContext.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.familyName == "Stair Climber")
        #expect(exercise.variantLabel == "Arsenal Strength")
        #expect(exercise.aliasesJoined == "stairmaster|stepmill")
        #expect(exercise.tracking == .durationLevel)
        #expect(exercise.brand == "Arsenal Strength")
        #expect(exercise.loadingRaw == "stack")
        #expect(exercise.isHidden)

        let set = try #require(try destination.mainContext.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(set.startedAt == Self.date)
        #expect(set.durationSeconds == 1200)
        #expect(set.distanceMeters == 1609.344)
        #expect(set.level == 8.5)

        let before = try ExportSnapshot.document(in: source.mainContext, exportedAt: Self.date).normalizedForEquality()
        let after = try ExportSnapshot.document(in: destination.mainContext, exportedAt: Self.date).normalizedForEquality()
        #expect(before == after)
    }

    @Test("a format-2 backup without the new keys restores, and the fields take their defaults")
    func backupWithoutTheNewKeysRestores() async throws {
        let source = try makeContainer()
        try seed(in: source.mainContext)
        let bytes = try await BackupArchiver(modelContainer: source).archiveData(now: Self.date)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try rewritten(bytes, formatVersion: 2, stripNewKeys: true).write(to: url, options: .atomic)

        let destination = try makeContainer()
        try await restore(url, into: destination)

        let exercise = try #require(try destination.mainContext.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.name == "Stair Climber (Arsenal Strength)")
        #expect(exercise.familyName == nil)
        #expect(exercise.variantLabel == nil)
        #expect(exercise.aliasesJoined == "")
        #expect(exercise.trackingRaw == nil)
        #expect(exercise.tracking == .weightReps)
        #expect(exercise.brand == nil)
        #expect(exercise.loadingRaw == nil)
        #expect(exercise.isHidden == false)

        let set = try #require(try destination.mainContext.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(set.isComplete)
        #expect(set.startedAt == nil)
        #expect(set.durationSeconds == nil)
        #expect(set.distanceMeters == nil)
        #expect(set.level == nil)
    }

    @Test("a backup in a newer format is refused before anything is replaced")
    func newerFormatIsRefused() async throws {
        let source = try makeContainer()
        try seed(in: source.mainContext)
        let bytes = try await BackupArchiver(modelContainer: source).archiveData(now: Self.date)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let newer = ExportDocument.currentFormatVersion + 1
        try rewritten(bytes, formatVersion: newer, stripNewKeys: false).write(to: url, options: .atomic)

        let destination = try makeContainer()
        await #expect(throws: BackupRestorer.RestoreError.newerFormat(found: newer)) {
            _ = try await BackupRestorer().preflight(url: url, context: destination.mainContext)
        }
    }

    @Test("restore clears the seed stamp, and the next seed applies curation to the restored catalog")
    func restoreClearsTheSeedStamp() async throws {
        // A row as an older backup holds it: a curated id, before its retag.
        let curationURL = try #require(Bundle.main.url(forResource: "curation", withExtension: "json"))
        let curation = try JSONDecoder().decode([String: ExerciseCuration].self, from: Data(contentsOf: curationURL))
        let (externalID, curated) = try #require(
            curation.sorted { $0.key < $1.key }.first { $0.value.equipment != nil }
        )
        let source = try makeContainer()
        let stale = Exercise(
            externalID: externalID, name: "Stale", canonicalName: "stale",
            equipmentRaw: Equipment.other.rawValue, mechanicRaw: Mechanic.compound.rawValue
        )
        source.mainContext.insert(stale)
        try source.mainContext.save()
        let url = try await archive(source)
        defer { try? FileManager.default.removeItem(at: url) }

        let name = "BackupCatalogFieldsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(try ExerciseLibraryImporter.bundledSeedVersion(), forKey: ExerciseLibraryImporter.seedVersionKey)

        let destination = try makeContainer()
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: url, context: destination.mainContext)
        try await restorer.performRestore(
            url: url, manifest: manifest, currentContainer: destination, defaults: defaults
        )
        #expect(defaults.object(forKey: ExerciseLibraryImporter.seedVersionKey) == nil)

        try await ExerciseLibraryImporter(modelContainer: destination).seedIfNeeded(defaults: defaults)
        let restored = try #require(
            try ModelContext(destination).fetch(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID == externalID })
            ).first
        )
        #expect(restored.id == stale.id)
        #expect(restored.equipmentRaw == curated.equipment)
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try FitbodModelContainer.make(inMemory: true)
    }

    /// One exercise and one completed set, with every new field set.
    private func seed(in context: ModelContext) throws {
        let exercise = Exercise(
            name: "Stair Climber (Arsenal Strength)", canonicalName: "stair climber (arsenal strength)",
            equipmentRaw: Equipment.cardioMachine.rawValue, mechanicRaw: Mechanic.compound.rawValue,
            category: "cardio", isCustom: true, createdAt: Self.date
        )
        exercise.familyName = "Stair Climber"
        exercise.variantLabel = "Arsenal Strength"
        exercise.aliasesJoined = "stairmaster|stepmill"
        exercise.trackingRaw = Tracking.durationLevel.rawValue
        exercise.brand = "Arsenal Strength"
        exercise.loadingRaw = "stack"
        exercise.isHidden = true
        context.insert(exercise)

        let session = Session()
        session.startedAt = Self.date
        session.completedAt = Self.date.addingTimeInterval(1800)
        context.insert(session)
        let logged = SessionExercise()
        context.insert(logged)
        logged.session = session
        logged.exercise = exercise
        logged.exerciseNameSnapshot = exercise.name
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = logged
        set.isComplete = true
        set.completedAt = Self.date.addingTimeInterval(1200)
        set.startedAt = Self.date
        set.durationSeconds = 1200
        set.distanceMeters = 1609.344
        set.level = 8.5
        try context.save()
    }

    private func archive(_ container: ModelContainer) async throws -> URL {
        let url = archiveURL()
        _ = try await BackupArchiver(modelContainer: container).archive(outputURL: url, now: Self.date)
        return url
    }

    private func archiveURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("catalog-\(UUID().uuidString).fitbodbackup")
    }

    /// Restores with a throwaway defaults suite, so the host app's seed
    /// stamp is left alone.
    private func restore(_ url: URL, into container: ModelContainer) async throws {
        let name = "BackupCatalogFieldsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: url, context: container.mainContext)
        try await restorer.performRestore(url: url, manifest: manifest, currentContainer: container, defaults: defaults)
    }

    /// The archive with another format number and, when asked, without the
    /// keys format 3 added, as a format-2 build wrote it.
    private func rewritten(_ archive: Data, formatVersion: Int, stripNewKeys: Bool) throws -> Data {
        let entries = try ZIPReader.read(data: archive)
        let storeEntry = try #require(entries.first(where: { $0.path == "store.json" }))
        var store = try #require(JSONSerialization.jsonObject(with: storeEntry.data) as? [String: Any])
        store["formatVersion"] = formatVersion
        if stripNewKeys {
            store["exercises"] = (store["exercises"] as? [[String: Any]])?.map { exercise in
                exercise.filter { !Self.exerciseKeys.contains($0.key) }
            }
            store["sessions"] = (store["sessions"] as? [[String: Any]])?.map { original in
                var session = original
                session["exercises"] = (session["exercises"] as? [[String: Any]])?.map { originalExercise in
                    var exercise = originalExercise
                    exercise["sets"] = (exercise["sets"] as? [[String: Any]])?.map { set in
                        set.filter { !Self.setKeys.contains($0.key) }
                    }
                    return exercise
                }
                return session
            }
        }
        let storeData = try JSONSerialization.data(withJSONObject: store, options: [.sortedKeys])
        let manifest = BackupManifest(
            formatVersion: formatVersion, schemaVersion: ExportDocument.canonicalSchemaVersion,
            createdAt: Self.date,
            checksum: SHA256.hash(data: storeData).map { String(format: "%02x", $0) }.joined(), imageCount: 0
        )
        return try ZIPWriter.write(entries: [
            .init(path: "manifest.json", data: manifest.encoded(), lastModified: Self.date),
            .init(path: "store.json", data: storeData, lastModified: Self.date),
        ])
    }
}
