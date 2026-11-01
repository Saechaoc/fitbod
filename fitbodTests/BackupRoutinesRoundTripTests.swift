import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import fitbod

// BackupRestorer and ModelContainer.mainContext are main-actor isolated.
@MainActor
@Suite("Backup routines and logged names")
struct BackupRoutinesRoundTripTests {
    private static let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Fresh restore keeps active and archived routines, ordered slots and links")
    func freshRestoreKeepsRoutinesAndLinks() async throws {
        let source = try makeContainer()
        let graph = try seedGraph(in: source.mainContext)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await BackupArchiver(modelContainer: source).archive(outputURL: url, now: Self.date)
        let destination = try makeContainer()
        try await restore(url, into: destination)
        try assertGraph(graph, in: destination.mainContext)
    }

    @Test("Restore replaces existing routines and leaves no dangling slot template")
    func restoreReplacesExistingRoutines() async throws {
        let source = try makeContainer()
        let graph = try seedGraph(in: source.mainContext)
        let destination = try makeContainer()
        let oldGraph = try seedGraph(in: destination.mainContext)
        let oldSplitIDs = Set(oldGraph.splits.map(\.id))
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await BackupArchiver(modelContainer: source).archive(outputURL: url, now: Self.date)
        try await restore(url, into: destination)
        try assertGraph(graph, in: destination.mainContext)
        let restoredIDs = Set(try destination.mainContext.fetch(FetchDescriptor<Split>()).map(\.id))
        #expect(restoredIDs.isDisjoint(with: oldSplitIDs))
    }

    @Test("Format one replaces existing routines with none and restores the exported log name")
    func legacyFormatRestoresWithoutRoutines() async throws {
        let source = try makeContainer()
        _ = try seedGraph(in: source.mainContext)
        let bytes = try await BackupArchiver(modelContainer: source).archiveData(now: Self.date)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try legacyArchive(from: bytes).write(to: url, options: .atomic)
        let destination = try makeContainer()
        _ = try seedGraph(in: destination.mainContext)
        try await restore(url, into: destination)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<Split>()) == 0)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<SplitSessionSlot>()) == 0)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<SessionTemplate>()) == 2)
        let logged = try #require(destination.mainContext.fetch(FetchDescriptor<SessionExercise>()).first)
        #expect(logged.exerciseNameSnapshot == "Original Lift")
        #expect(logged.displayName == "Original Lift")
        #expect(logged.exercise?.name == "Current Library Name")
    }

    @Test("Backup, JSON and CSV preserve the logged name after library rename or deletion", arguments: [false, true])
    func loggedNameSurvivesLibraryChanges(deleteExercise: Bool) async throws {
        let source = try makeContainer()
        let logged = try seedLoggedExercise(in: source.mainContext)
        let exercise = try #require(logged.exercise)
        if deleteExercise {
            try ExerciseDeletion.delete(exercise, context: source.mainContext)
        } else {
            exercise.name = "Current Library Name"
        }
        try source.mainContext.save()
        #expect(logged.displayName == "Original Lift")
        let service = ExportService(modelContainer: source)
        let document = try await service.snapshotDocument()
        #expect(document.sessions.first?.exercises.first?.exerciseName == "Original Lift")
        let csv = try await service.renderCSV()
        #expect(String(decoding: csv.data, as: UTF8.self).contains("Original Lift"))
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await BackupArchiver(modelContainer: source).archive(outputURL: url, now: Self.date)
        let destination = try makeContainer()
        try await restore(url, into: destination)
        let restored = try #require(destination.mainContext.fetch(FetchDescriptor<SessionExercise>()).first)
        #expect(restored.exerciseNameSnapshot == "Original Lift")
        #expect(restored.displayName == "Original Lift")
        #expect((restored.exercise == nil) == deleteExercise)
    }

    private struct Graph {
        let splits: [Split]
        let block: Block
        let workout: Session
    }

    @Test("Malformed routine graph is rejected before replacing existing data", arguments: [
        "duplicateSplit", "duplicateSlot", "missingTemplate", "missingSplit", "missingSlot"
    ])
    func malformedGraphKeepsDestinationIntact(fault: String) async throws {
        let source = try makeContainer()
        _ = try seedGraph(in: source.mainContext)
        let archive = try await BackupArchiver(modelContainer: source).archiveData(now: Self.date)
        let entries = try ZIPReader.read(data: archive)
        let store = try #require(entries.first(where: { $0.path == "store.json" }))
        var json = try #require(JSONSerialization.jsonObject(with: store.data) as? [String: Any])
        var splits = try #require(json["splits"] as? [[String: Any]])
        switch fault {
        case "duplicateSplit": splits.append(splits[0])
        case "duplicateSlot":
            let firstSlots = try #require(splits[0]["slots"] as? [[String: Any]])
            var otherSlots = try #require(splits[1]["slots"] as? [[String: Any]])
            otherSlots[0]["id"] = firstSlots[0]["id"]
            splits[1]["slots"] = otherSlots
        case "missingTemplate":
            var slots = try #require(splits[0]["slots"] as? [[String: Any]])
            slots[0]["sessionTemplateID"] = UUID().uuidString
            splits[0]["slots"] = slots
        case "missingSplit":
            var blocks = try #require(json["blocks"] as? [[String: Any]])
            blocks[0]["splitID"] = UUID().uuidString
            json["blocks"] = blocks
        default:
            var sessions = try #require(json["sessions"] as? [[String: Any]])
            sessions[0]["slotID"] = UUID().uuidString
            json["sessions"] = sessions
        }
        json["splits"] = splits
        let bytes = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let manifest = BackupManifest(formatVersion: 2,
            schemaVersion: ExportDocument.canonicalSchemaVersion, createdAt: Self.date,
            checksum: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), imageCount: 0)
        let url = archiveURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try ZIPWriter.write(entries: [
            .init(path: "manifest.json", data: manifest.encoded(), lastModified: Self.date),
            .init(path: "store.json", data: bytes, lastModified: Self.date)
        ]).write(to: url)
        let destination = try makeContainer()
        _ = try seedGraph(in: destination.mainContext)
        let beforeSplits = Set(try destination.mainContext.fetch(FetchDescriptor<Split>()).map(\.id))
        let beforeWorkouts = Set(try destination.mainContext.fetch(FetchDescriptor<Session>()).map(\.id))
        let beforeExercises = Set(try destination.mainContext.fetch(FetchDescriptor<SessionExercise>()).map(\.id))
        let beforeSets = Set(try destination.mainContext.fetch(FetchDescriptor<SetEntry>()).map(\.id))
        let beforeSlots = try destination.mainContext.fetch(FetchDescriptor<SplitSessionSlot>())
            .map { ($0.id, $0.sessionTemplate?.id) }
        let restorer = BackupRestorer()
        let checked = try await restorer.preflight(url: url, context: destination.mainContext)
        do {
            try await restorer.performRestore(url: url, manifest: checked, currentContainer: destination)
            Issue.record("Malformed routine graph must be rejected")
        } catch let error as BackupRestorer.RestoreError {
            switch error {
            case .decodeFailed: break
            default: Issue.record("Expected decodeFailed, got \(error)")
            }
        }
        #expect(Set(try destination.mainContext.fetch(FetchDescriptor<Split>()).map(\.id)) == beforeSplits)
        #expect(Set(try destination.mainContext.fetch(FetchDescriptor<Session>()).map(\.id)) == beforeWorkouts)
        #expect(Set(try destination.mainContext.fetch(FetchDescriptor<SessionExercise>()).map(\.id)) == beforeExercises)
        #expect(Set(try destination.mainContext.fetch(FetchDescriptor<SetEntry>()).map(\.id)) == beforeSets)
        let afterSlots = try destination.mainContext.fetch(FetchDescriptor<SplitSessionSlot>())
        #expect(afterSlots.count == beforeSlots.count)
        for (id, templateID) in beforeSlots {
            #expect(afterSlots.first(where: { $0.id == id })?.sessionTemplate?.id == templateID)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let name = "BackupRoutinesRoundTripTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        return try FitbodModelContainer.make(inMemory: true, defaults: defaults)
    }

    private func seedGraph(in context: ModelContext) throws -> Graph {
        let templates = (0..<2).map { index in
            let template = SessionTemplate()
            context.insert(template)
            template.name = "Session \(index + 1)"
            return template
        }
        let splits = (0..<2).map { index in
            let split = Split()
            context.insert(split)
            // Same names ensure restore attaches by id rather than guessing by name.
            split.name = "Routine"
            split.createdAt = Self.date.addingTimeInterval(Double(index))
            split.isArchived = index == 1
            for position in [1, 0] {
                let slot = SplitSessionSlot()
                context.insert(slot)
                slot.position = position
                slot.split = split
                slot.sessionTemplate = templates[(position + index) % templates.count]
            }
            return split
        }
        let block = Block()
        context.insert(block)
        block.name = "Rotation Block"
        block.startDate = Self.date
        block.isActive = true
        block.split = splits[0]
        let logged = try seedLoggedExercise(in: context)
        let workout = try #require(logged.session)
        workout.block = block
        workout.slot = try #require(splits[0].slots?.first(where: { $0.position == 1 }))
        try context.save()
        return Graph(splits: splits, block: block, workout: workout)
    }

    private func seedLoggedExercise(in context: ModelContext) throws -> SessionExercise {
        let exercise = Exercise()
        context.insert(exercise)
        exercise.name = "Original Lift"
        exercise.canonicalName = "original lift"
        exercise.isCustom = true
        let workout = Session()
        context.insert(workout)
        workout.startedAt = Self.date
        workout.completedAt = Self.date.addingTimeInterval(60)
        let logged = SessionExercise()
        context.insert(logged)
        logged.exercise = exercise
        logged.exerciseNameSnapshot = exercise.name
        logged.session = workout
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = logged
        set.weight = 25
        set.reps = 12
        set.isComplete = true
        set.completedAt = Self.date.addingTimeInterval(30)
        try context.save()
        return logged
    }

    private func assertGraph(_ expected: Graph, in context: ModelContext) throws {
        let restored = try context.fetch(FetchDescriptor<Split>())
        #expect(restored.count == 2)
        for original in expected.splits {
            let split = try #require(restored.first(where: { $0.id == original.id }))
            #expect(split.name == original.name)
            #expect(split.createdAt == original.createdAt)
            #expect(split.isArchived == original.isArchived)
            let expectedSlots = (original.slots ?? []).sorted { $0.position < $1.position }
            let restoredSlots = (split.slots ?? []).sorted { $0.position < $1.position }
            #expect(restoredSlots.map(\.id) == expectedSlots.map(\.id))
            #expect(restoredSlots.map(\.position) == [0, 1])
            #expect(restoredSlots.map { $0.sessionTemplate?.id } == expectedSlots.map { $0.sessionTemplate?.id })
            #expect(restoredSlots.allSatisfy { $0.split?.id == split.id })
        }
        let slots = try context.fetch(FetchDescriptor<SplitSessionSlot>())
        #expect(slots.count == 4)
        let templateIDs = Set(try context.fetch(FetchDescriptor<SessionTemplate>()).map(\.id))
        for slot in slots {
            let templateID = try #require(slot.sessionTemplate?.id)
            #expect(templateIDs.contains(templateID))
        }
        let block = try #require(context.fetch(FetchDescriptor<Block>()).first)
        #expect(block.id == expected.block.id)
        #expect(block.split?.id == expected.block.split?.id)
        let workout = try #require(context.fetch(FetchDescriptor<Session>()).first)
        #expect(workout.id == expected.workout.id)
        #expect(workout.slot?.id == expected.workout.slot?.id)
        #expect(workout.block?.id == block.id)
    }

    private func restore(_ url: URL, into container: ModelContainer) async throws {
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: url, context: container.mainContext)
        try await restorer.performRestore(url: url, manifest: manifest, currentContainer: container)
    }

    private func archiveURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("routines-\(UUID().uuidString).fitbodbackup")
    }

    private func legacyArchive(from archive: Data) throws -> Data {
        let entries = try ZIPReader.read(data: archive)
        let storeEntry = try #require(entries.first(where: { $0.path == "store.json" }))
        var store = try #require(JSONSerialization.jsonObject(with: storeEntry.data) as? [String: Any])
        store["formatVersion"] = 1
        store.removeValue(forKey: "splits")
        store["blocks"] = (store["blocks"] as? [[String: Any]])?.map { original in
            var block = original
            block.removeValue(forKey: "splitID")
            return block
        }
        store["sessions"] = (store["sessions"] as? [[String: Any]])?.map { original in
            var session = original
            session.removeValue(forKey: "slotID")
            session["exercises"] = (session["exercises"] as? [[String: Any]])?.map { originalExercise in
                var exercise = originalExercise
                exercise.removeValue(forKey: "exerciseNameSnapshot")
                return exercise
            }
            return session
        }
        store["exercises"] = (store["exercises"] as? [[String: Any]])?.map { original in
            var exercise = original
            exercise["name"] = "Current Library Name"
            return exercise
        }
        let storeData = try JSONSerialization.data(withJSONObject: store, options: [.sortedKeys])
        let manifest = BackupManifest(
            formatVersion: 1, schemaVersion: ExportDocument.canonicalSchemaVersion,
            createdAt: Self.date,
            checksum: SHA256.hash(data: storeData).map { String(format: "%02x", $0) }.joined(), imageCount: 0
        )
        return try ZIPWriter.write(entries: [
            .init(path: "manifest.json", data: manifest.encoded(), lastModified: Self.date),
            .init(path: "store.json", data: storeData, lastModified: Self.date),
        ])
    }
}
