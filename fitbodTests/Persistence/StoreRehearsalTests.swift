//
//  StoreRehearsalTests.swift
//  fitbodTests
//
//  Rehearses an app upgrade on a copy of a real store. This is the populated
//  backup and recovery proof the roadmap asks for before a schema change
//  (RM-029).
//
//  Skipped unless FITBOD_REHEARSAL_STORE names a folder that holds
//  `default.store` and its siblings. `scripts/rehearse-store.sh` sets it and
//  fails when the tests did not run.
//
//  Opening a store migrates it in place, so every open here is on a copy.
//

import Foundation
import SQLite3
import SwiftData
import Testing
@testable import fitbod

private enum Rehearsal {
    private static func folder(_ key: String) -> URL? {
        ProcessInfo.processInfo.environment[key].map { URL(fileURLWithPath: $0) }
    }

    /// The folder that holds the store to rehearse on.
    static var storeFolder: URL? { folder("FITBOD_REHEARSAL_STORE") }
    /// Where the opened copy, the archive and the counts are kept. Unset, a
    /// temporary folder is used and removed.
    static var outputFolder: URL? { folder("FITBOD_REHEARSAL_OUT") }
    /// A backup written by an earlier build that must still restore.
    static var earlierArchive: URL? { folder("FITBOD_REHEARSAL_ARCHIVE") }
}

@MainActor
@Suite("StoreRehearsal", .serialized, .enabled(if: Rehearsal.storeFolder != nil))
struct StoreRehearsalTests {

    private let fm = FileManager.default

    @Test("a copy of the store opens in place with every row and survives a backup round trip")
    func storeOpensInPlaceAndRoundTrips() async throws {
        let work = try workFolder("round-trip")
        defer { removeIfTemporary(work) }

        // Row counts straight from SQLite, on a copy SwiftData never opens.
        let raw = try copyStore(into: work, as: "raw")
        let expected = try rowCounts(inStoreAt: raw)

        let container = try openCopy(in: work)
        var counts: [String: Int] = [:]
        for model in SchemaV7.models {
            counts[Schema.entityName(for: model)] = try count(model, in: container.mainContext)
        }
        #expect(counts == expected)

        let archive = work.appendingPathComponent("rehearsal.fitbodbackup")
        _ = try await BackupArchiver(modelContainer: container).archive(outputURL: archive)
        let restored = try await restore(archive, into: work)
        try expectSameDocument(container, restored)

        let lines = counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        try lines.joined(separator: "\n").write(
            to: work.appendingPathComponent("counts.txt"), atomically: true, encoding: .utf8
        )
    }

    @Test("a backup written by an earlier build restores to the same data",
          .enabled(if: Rehearsal.earlierArchive != nil))
    func earlierArchiveRestores() async throws {
        let archive = try #require(Rehearsal.earlierArchive)
        let work = try workFolder("earlier-archive")
        defer { removeIfTemporary(work) }

        let container = try openCopy(in: work)
        let restored = try await restore(archive, into: work)
        try expectSameDocument(container, restored)
        try "restored".write(to: work.appendingPathComponent("restored.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: - Steps

    private func workFolder(_ name: String) throws -> URL {
        let root = Rehearsal.outputFolder
            ?? fm.temporaryDirectory.appendingPathComponent("fitbod-rehearsal-\(UUID().uuidString)", isDirectory: true)
        let work = root.appendingPathComponent(name, isDirectory: true)
        try? fm.removeItem(at: work)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        return work
    }

    private func removeIfTemporary(_ work: URL) {
        if Rehearsal.outputFolder == nil { try? fm.removeItem(at: work.deletingLastPathComponent()) }
    }

    /// Copies the store folder and returns the copy's `default.store`.
    private func copyStore(into work: URL, as name: String) throws -> URL {
        let copy = work.appendingPathComponent(name, isDirectory: true)
        try fm.copyItem(at: try #require(Rehearsal.storeFolder), to: copy)
        return copy.appendingPathComponent("default.store")
    }

    /// Opens a copy the way the app does. Nothing may be moved aside, and the
    /// seed stamp must stay.
    private func openCopy(in work: URL) throws -> ModelContainer {
        let store = try copyStore(into: work, as: "opened")
        let defaults = try isolatedDefaults()
        defaults.set(1, forKey: ExerciseLibraryImporter.seedVersionKey)
        let container = try FitbodModelContainer.make(storeURL: store, defaults: defaults)
        let movedAside = store.deletingLastPathComponent().appendingPathComponent("IncompatibleStores")
        #expect(!fm.fileExists(atPath: movedAside.path))
        #expect(defaults.integer(forKey: ExerciseLibraryImporter.seedVersionKey) == 1)
        return container
    }

    /// Restores `archive` into a new, empty store on disk.
    private func restore(_ archive: URL, into work: URL) async throws -> ModelContainer {
        let folder = work.appendingPathComponent("restored", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try FitbodModelContainer.make(
            storeURL: folder.appendingPathComponent("default.store"), defaults: try isolatedDefaults()
        )
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: archive, context: container.mainContext)
        try await restorer.performRestore(url: archive, manifest: manifest, currentContainer: container)
        return container
    }

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "fitbod-rehearsal-\(UUID().uuidString)"))
    }

    private func count<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    /// Rows per entity, read from the Core Data tables (`Z` + entity name).
    /// A table the store does not have yet counts as empty.
    private func rowCounts(inStoreAt url: URL) throws -> [String: Int] {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        try #require(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        var counts: [String: Int] = [:]
        for model in SchemaV7.models {
            let entity = Schema.entityName(for: model)
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            let sql = "SELECT COUNT(*) FROM Z\(entity.uppercased())"
            if sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
               sqlite3_step(statement) == SQLITE_ROW {
                counts[entity] = Int(sqlite3_column_int64(statement, 0))
            } else {
                counts[entity] = 0
            }
        }
        return counts
    }

    private func expectSameDocument(_ lhs: ModelContainer, _ rhs: ModelContainer) throws {
        let a = try ExportSnapshot.document(in: lhs.mainContext, exportedAt: .distantPast).normalizedForEquality()
        let b = try ExportSnapshot.document(in: rhs.mainContext, exportedAt: .distantPast).normalizedForEquality()
        expectSame(a.exercises, b.exercises, "exercises")
        expectSame(a.routines, b.routines, "routines")
        expectSame(a.splits ?? [], b.splits ?? [], "splits")
        expectSame(a.routineFolders, b.routineFolders, "routine folders")
        expectSame(a.supersetGroups, b.supersetGroups, "superset groups")
        expectSame(a.sessions, b.sessions, "sessions")
        expectSame(a.blocks, b.blocks, "blocks")
        expectSame(a.muscleGroups, b.muscleGroups, "muscle groups")
        expectSame(a.exerciseMuscleStimuli, b.exerciseMuscleStimuli, "stimuli")
        expectSame(a.muscleVolumeTargets, b.muscleVolumeTargets, "volume targets")
        expectSame(a.plateInventories, b.plateInventories, "plate inventories")
        #expect(a.userSettings == b.userSettings)
        #expect(a.unitSystem == b.unitSystem)
    }

    /// Reports the count and the first differing row, not the whole array.
    private func expectSame<Row: Equatable>(_ a: [Row], _ b: [Row], _ name: String) {
        #expect(a.count == b.count, "\(name) count")
        if let (left, right) = zip(a, b).first(where: { $0 != $1 }) {
            Issue.record("\(name) differ, first at \(left) vs \(right)")
        }
    }
}
