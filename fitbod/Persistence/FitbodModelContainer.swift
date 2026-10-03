//
//  FitbodModelContainer.swift
//  fitbod
//
//  The ONE place a `ModelContainer` is built. `fitbodApp`,
//  `PreviewModelContainer` and the unit tests all go through `make(...)`.
//
//  The container is built from the baseline schema (`SchemaV7`) with NO
//  migration plan. SwiftData therefore applies its automatic lightweight
//  migration to additive changes (new optional or defaulted attributes, new
//  entities) and opens the existing store in place.
//
//  Anything SwiftData cannot migrate automatically makes `ModelContainer`
//  creation throw. For an on-disk store the factory then moves the store
//  files aside into `IncompatibleStores/<ISO8601 timestamp>/` next to the
//  store (never deleting them), logs the event, and creates a fresh store.
//  Because seeding is guarded by UserDefaults stamps (exercise library seed
//  version, plate inventory flag), a moved-aside store also clears those
//  stamps so the fresh store is re-seeded instead of staying empty.
//  Only if the fresh store also fails to build does `make` throw, and the app
//  turns that into a `fatalError`.
//

import Foundation
import OSLog
import SwiftData

public enum FitbodModelContainer {

    /// The schema the running app reads and writes.
    public typealias CurrentSchema = SchemaV7

    private static let logger = Logger(subsystem: "com.fitbod", category: "persistence")

    /// Builds the container.
    /// - Parameters:
    ///   - inMemory: `true` for previews and tests that need no persistence.
    ///   - storeURL: explicit on-disk store location. `nil` uses SwiftData's
    ///     default store location (`default.store` in Application Support).
    ///     Ignored when `inMemory` is `true`.
    ///   - incompatibleStoresRoot: where moved-aside stores go. `nil` uses
    ///     `IncompatibleStores/` next to the store.
    ///   - defaults: where the seed stamps live; cleared after a move-aside.
    public static func make(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        incompatibleStoresRoot: URL? = nil,
        defaults: UserDefaults = .standard
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)

        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: config)
        }

        let url = storeURL ?? ModelConfiguration(schema: schema).url
        let config = ModelConfiguration(schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.error("Store at \(url.path, privacy: .public) could not be opened: \(String(describing: error), privacy: .public)")
            let root = incompatibleStoresRoot
                ?? url.deletingLastPathComponent().appendingPathComponent("IncompatibleStores", isDirectory: true)
            let destination = try moveAside(storeAt: url, into: root)
            logger.error("Moved incompatible store to \(destination.path, privacy: .public); creating a fresh store.")
            let fresh = try ModelContainer(for: schema, configurations: config)
            clearSeedStamps(in: defaults)
            return fresh
        }
    }

    /// The seeders skip work when these stamps are set. A brand-new store is
    /// empty, so the stamps must go or the exercise library stays empty.
    /// Mirrors `PlateInventorySeeder.seededKey` (that type is main-actor
    /// isolated); `IncompatibleStoreRecoveryTests` pins the two together.
    static let plateInventorySeededKey = "plateInventorySeeded"

    static func clearSeedStamps(in defaults: UserDefaults) {
        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        defaults.removeObject(forKey: plateInventorySeededKey)
    }

    /// Moves the store file, its `-shm` / `-wal` siblings and the
    /// `.<name>_SUPPORT` folder (when present) into
    /// `<root>/<ISO8601 timestamp>/`. Never deletes anything.
    @discardableResult
    static func moveAside(storeAt url: URL, into root: URL, now: Date = Date()) throws -> URL {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
        var destination = root.appendingPathComponent(stamp, isDirectory: true)
        var suffix = 1
        while fm.fileExists(atPath: destination.path) {
            destination = root.appendingPathComponent("\(stamp)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        let candidates = [
            url,
            dir.appendingPathComponent(name + "-shm"),
            dir.appendingPathComponent(name + "-wal"),
            dir.appendingPathComponent("." + url.deletingPathExtension().lastPathComponent + "_SUPPORT", isDirectory: true),
        ]
        for source in candidates where fm.fileExists(atPath: source.path) {
            try fm.moveItem(at: source, to: destination.appendingPathComponent(source.lastPathComponent))
        }
        return destination
    }
}
