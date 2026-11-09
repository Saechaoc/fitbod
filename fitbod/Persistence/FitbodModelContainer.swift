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
//  When an on-disk store does not open, SwiftData throws the same
//  `SwiftDataError.loadIssueModelContainer` for an incompatible schema, an
//  unreadable file and a damaged file. The factory therefore asks Core Data,
//  read-only, why the store does not open. That is the app's one direct use
//  of Core Data.
//
//    - Core Data cannot infer a migration (NSCocoaErrorDomain 134140,
//      `NSMigrationMissingMappingModelError`): the schema is incompatible.
//      The factory moves the store files aside into
//      `IncompatibleStores/<ISO8601 timestamp>/` next to the store (never
//      deleting them), clears the seed stamps (exercise library seed
//      version, plate inventory flag) so the next store is seeded instead of
//      staying empty, and creates a fresh store.
//    - Any other reason, or none: every file stays where it is and `make`
//      throws `StoreOpenError`. The app shows a retry screen, and a later
//      `make` opens the same store.
//
//  `make` also throws when an incompatible store cannot be moved (the files
//  already moved are put back first) or when the fresh store cannot be built.
//
//  Reasons seen on iOS 26.5 for stores that stay: unreadable store 257;
//  unreadable `-shm` or `-wal` 256 with SQLite 14; not a database 259;
//  truncated NSSQLiteErrorDomain 11; a migration Core Data can infer but
//  SwiftData could not apply 134110 with SQLite 8.
//
//  shortcut: for a store that needs a migration Core Data can infer, the
//  read-only question always answers 134110 with SQLite 8, because it may
//  not write, whatever stopped SwiftData's own attempt (a read-only file, or
//  rows that break a new unique constraint). Those stores all stay and the
//  real reason is only in the system log. Upgrade when one of those cases
//  has to be told from the others.
//

import CoreData
import Foundation
import OSLog
import SwiftData

public enum FitbodModelContainer {

    /// The schema the running app reads and writes.
    public typealias CurrentSchema = SchemaV7

    private static let logger = Logger(subsystem: "com.fitbod", category: "persistence")

    /// Thrown by `make` when the on-disk store did not open and Core Data
    /// does not say that its schema is the cause. Every store file is still
    /// where it was, so a later `make` can open it.
    public struct StoreOpenError: Error {
        /// Core Data's reason when it gives one, otherwise what SwiftData threw.
        public let reason: any Error
    }

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

        let url = storeURL ?? defaultStoreURL
        let config = ModelConfiguration(schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // SwiftData throws `SwiftDataError.loadIssueModelContainer` for
            // every failure, so the reason has to come from Core Data.
            let reason = coreDataOpenError(storeAt: url, schema: schema)
            logger.error("Store at \(url.path, privacy: .public) could not be opened: \(summary(of: reason ?? error), privacy: .public)")
            // Core Data reports a missing mapping model only when it cannot
            // infer a migration from the store's schema to the app's. Any
            // other reason, or none, leaves every file where it is.
            guard let reason, reason.domain == NSCocoaErrorDomain,
                  reason.code == NSMigrationMissingMappingModelError else {
                throw StoreOpenError(reason: reason ?? error)
            }
            let root = incompatibleStoresRoot
                ?? url.deletingLastPathComponent().appendingPathComponent("IncompatibleStores", isDirectory: true)
            let destination = try moveAside(storeAt: url, into: root)
            logger.error("Moved incompatible store to \(destination.path, privacy: .public); creating a fresh store.")
            // The next store at this URL starts empty, whether it is built
            // here or by a later `make`, so it has to be seeded.
            clearSeedStamps(in: defaults)
            return try ModelContainer(for: schema, configurations: config)
        }
    }

    /// Core Data's reason why the store at `url` does not open with `schema`,
    /// or `nil` when it has none. The store is opened read-only, so asking
    /// can neither change nor migrate it. With the migration options Core
    /// Data tries to infer a migration. It reports 134140 when it cannot
    /// and 134110 when it can but may not write, which tells an incompatible
    /// schema from an additive one.
    static func coreDataOpenError(storeAt url: URL, schema: Schema) -> NSError? {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: schema) else { return nil }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        do {
            let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: [
                NSReadOnlyPersistentStoreOption: true,
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
            ])
            try? coordinator.remove(store)
            return nil
        } catch {
            return error as NSError
        }
    }

    /// The error's domain and code, with the SQLite code when Core Data gives
    /// one on the error or on the error under it, such as
    /// "NSCocoaErrorDomain 256, SQLite 4618". For the log and the retry screen.
    static func summary(of error: any Error) -> String {
        let error = ((error as? StoreOpenError)?.reason ?? error) as NSError
        let sqlite = error.userInfo[NSSQLiteErrorDomain]
            ?? (error.userInfo[NSUnderlyingErrorKey] as? NSError)?.userInfo[NSSQLiteErrorDomain]
        return "\(error.domain) \(error.code)" + (sqlite.map { ", SQLite \($0)" } ?? "")
    }

    /// Where `make()` keeps the store when no `storeURL` is passed.
    static var defaultStoreURL: URL {
        ModelConfiguration(schema: Schema(versionedSchema: CurrentSchema.self)).url
    }

    /// The store file plus the siblings SQLite and SwiftData keep next to it:
    /// `-shm`, `-wal` and the `.<name>_SUPPORT` folder.
    static func storeFiles(for url: URL) -> [URL] {
        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        return [
            url,
            dir.appendingPathComponent(name + "-shm"),
            dir.appendingPathComponent(name + "-wal"),
            dir.appendingPathComponent("." + url.deletingPathExtension().lastPathComponent + "_SUPPORT", isDirectory: true),
        ]
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
    /// `<root>/<ISO8601 timestamp>/`. Never deletes a file. When one of them
    /// cannot be moved, the ones already moved go back and the error is
    /// thrown: a store split between two folders would next open as a new,
    /// empty store beside a stale `-wal`.
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

        var moved: [(source: URL, target: URL)] = []
        do {
            for source in storeFiles(for: url) where fm.fileExists(atPath: source.path) {
                let target = destination.appendingPathComponent(source.lastPathComponent)
                try fm.moveItem(at: source, to: target)
                moved.append((source, target))
            }
        } catch {
            for (source, target) in moved.reversed() {
                do {
                    try fm.moveItem(at: target, to: source)
                } catch {
                    logger.error("Could not put \(target.path, privacy: .public) back: \(summary(of: error), privacy: .public)")
                }
            }
            rmdir(destination.path) // removes the folder only when it is empty
            throw error
        }
        return destination
    }
}
