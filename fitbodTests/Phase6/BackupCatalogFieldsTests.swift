//
//  BackupCatalogFieldsTests.swift
//  fitbodTests
//
//  The RM-022 / RM-062 fields in a backup (format 3) and the RM-066
//  machines (format 4):
//    - every new field survives archive and restore, and so does the
//      machine a workout was done on;
//    - a format-2 backup, which has none of the keys, still restores and the
//      fields take the model defaults;
//    - a workout naming a machine the backup lacks is refused before
//      anything is replaced;
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
        let machine = try #require(set.sessionExercise?.machine)
        #expect(machine.id == Self.machineID)
        #expect(machine.manufacturer == "Arsenal Strength" && machine.model == "Stair Climber")

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
        // With none stored it follows the equipment, a cardio machine here.
        #expect(exercise.tracking == .durationDistance)
        #expect(exercise.brand == nil)
        #expect(exercise.loadingRaw == nil)
        #expect(exercise.isHidden == false)

        let set = try #require(try destination.mainContext.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(set.isComplete)
        #expect(set.sessionExercise?.machine == nil)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<MachineProfile>()) == 0)
        #expect(set.startedAt == nil)
        #expect(set.durationSeconds == nil)
        #expect(set.distanceMeters == nil)
        #expect(set.level == nil)
    }

    @Test("a workout naming a machine the backup lacks is refused before anything is replaced")
    func missingMachineIsRefused() async throws {
        let source = try makeContainer()
        try seed(in: source.mainContext)
        let bytes = try await BackupArchiver(modelContainer: source).archiveData(now: Self.date)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try rewritten(bytes, formatVersion: ExportDocument.currentFormatVersion, stripNewKeys: false, dropMachines: true)
            .write(to: url, options: .atomic)

        let destination = try makeContainer()
        let kept = Exercise(name: "Kept", canonicalName: "kept", equipmentRaw: "barbell", mechanicRaw: "compound")
        destination.mainContext.insert(kept)
        try destination.mainContext.save()
        await #expect(throws: BackupRestorer.RestoreError.self) {
            try await restore(url, into: destination)
        }
        #expect(try destination.mainContext.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Kept"])
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
        // Rows as an older backup holds them: curated ids, before their curation.
        let curationURL = try #require(Bundle.main.url(forResource: "curation", withExtension: "json"))
        let curation = try JSONDecoder().decode([String: ExerciseCuration].self, from: Data(contentsOf: curationURL))
        let sorted = curation.sorted { $0.key < $1.key }
        let (externalID, curated) = try #require(sorted.first { $0.value.equipment != nil && $0.value.family != nil })
        let (machineID, machine) = try #require(sorted.first { $0.value.brand != nil && $0.value.loading != nil })
        let source = try makeContainer()
        let stale = Exercise(
            externalID: externalID, name: "Stale", canonicalName: "stale",
            equipmentRaw: Equipment.other.rawValue, mechanicRaw: Mechanic.compound.rawValue
        )
        source.mainContext.insert(stale)
        source.mainContext.insert(Exercise(
            externalID: machineID, name: "Stale machine", canonicalName: "stale machine",
            equipmentRaw: Equipment.machine.rawValue, mechanicRaw: Mechanic.compound.rawValue
        ))
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
        func restored(_ id: String) throws -> Exercise {
            try #require(try ModelContext(destination).fetch(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID == id })
            ).first)
        }
        let row = try restored(externalID)
        #expect(row.id == stale.id)
        #expect(row.equipmentRaw == curated.equipment)
        #expect(row.familyName == curated.family && row.variantLabel == curated.variant)
        let machineRow = try restored(machineID)
        #expect(machineRow.familyName == machine.family && machineRow.variantLabel == machine.variant)
        #expect(machineRow.brand == machine.brand && machineRow.loadingRaw == machine.loading)
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try FitbodModelContainer.make(inMemory: true)
    }

    private static let machineID = UUID(uuidString: "00000000-0000-0000-0000-000000000066")!

    /// One exercise and one completed set on a machine, with every new
    /// field set.
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
        let machine = MachineProfile()
        context.insert(machine)
        machine.id = Self.machineID
        machine.manufacturer = "Arsenal Strength"
        machine.model = "Stair Climber"
        machine.createdAt = Self.date
        logged.machine = machine
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
    /// keys formats 3 and 4 added, as a format-2 build wrote it, or with its
    /// machines left out while the workouts still name them.
    private func rewritten(
        _ archive: Data, formatVersion: Int, stripNewKeys: Bool, dropMachines: Bool = false
    ) throws -> Data {
        let entries = try ZIPReader.read(data: archive)
        let storeEntry = try #require(entries.first(where: { $0.path == "store.json" }))
        var store = try #require(JSONSerialization.jsonObject(with: storeEntry.data) as? [String: Any])
        store["formatVersion"] = formatVersion
        if stripNewKeys || dropMachines {
            store.removeValue(forKey: "machines")
        }
        if stripNewKeys {
            store["exercises"] = (store["exercises"] as? [[String: Any]])?.map { exercise in
                exercise.filter { !Self.exerciseKeys.contains($0.key) }
            }
            store["sessions"] = (store["sessions"] as? [[String: Any]])?.map { original in
                var session = original
                session["exercises"] = (session["exercises"] as? [[String: Any]])?.map { originalExercise in
                    var exercise = originalExercise
                    exercise.removeValue(forKey: "machineID")
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
