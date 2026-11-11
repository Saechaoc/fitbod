//
//  IncompatibleStoreRecoveryTests.swift
//  fitbodTests
//
//  Covers the outcomes of opening an on-disk store through
//  `FitbodModelContainer.make(storeURL:)`:
//
//    (a) The store was written with an incompatible model shape. SwiftData
//        throws, Core Data confirms that no migration can be inferred, and
//        the factory moves the store files into
//        `IncompatibleStores/<timestamp>/` (never deleting them) and builds a
//        fresh store.
//    (b) The store was written with an older ADDITIVE shape (an attribute that
//        the current model added later, with a default). SwiftData migrates it
//        automatically and the store opens in place with its data intact.
//    (c) The open fails for a reason that is not the schema: a file that
//        cannot be read or written, or contents that are not a store. Every
//        file stays where it is, the seed stamps stay set and `make` throws
//        `StoreOpenError`. Once the cause is gone, the same store opens with
//        its rows intact.
//    (d) An incompatible store that cannot be moved completely is put back
//        whole, and `make` throws.
//
//  The "old shapes" below are test-only @Model types named like the production
//  entities, so the entity names match the baseline schema.
//

import CoreData
import Foundation
import SwiftData
import Testing
@testable import fitbod

// MARK: - Test-only historical shapes

/// An older `Exercise` whose `name` is an Int. SwiftData cannot infer a
/// String <- Int attribute-type change, so opening it with the baseline
/// schema throws.
private enum IncompatibleShape {
    @Model final class Exercise {
        var name: Int = 0
        init() {}
    }
}

/// An older `PlateInventory` that predates `updatedAt` (an additive,
/// defaulted attribute in the current model).
private enum AdditiveOldShape {
    @Model final class PlateInventory {
        @Attribute(.unique) var id: UUID = UUID()
        var equipmentKindRaw: String = "barbell"
        var barWeight: Double = 20.0
        var availablePlatesData: Data = Data()
        var createdAt: Date = Date.now
        init() {}
    }
}

/// `Exercise` and `SetEntry` as they were before the RM-022 / RM-062 catalog
/// and set fields, attribute for attribute. The exercise's stimulus
/// relationship is left out; a store without it still opens (the
/// relationship column lives on the stimulus table).
private enum PreCatalogShape {
    @Model final class Exercise {
        #Unique<Exercise>([\.externalID])

        @Attribute(.unique) var id: UUID = UUID()
        var externalID: String? = nil
        var name: String = ""
        var canonicalName: String = ""
        var equipmentRaw: String = "other"
        var mechanicRaw: String = "compound"
        var forceRaw: String? = nil
        var levelRaw: String? = nil
        var patternRaw: String? = nil
        var category: String = "strength"
        var instructions: [String] = []
        var imagePaths: [String] = []
        @Attribute(.externalStorage) var imageData: Data? = nil
        var isCustom: Bool = false
        var primaryMuscleSlugsJoined: String = ""
        var createdAt: Date = Date.now
        var smallestIncrement: Double? = nil
        var barWeightOverride: Double? = nil
        var unitOverrideRaw: String? = nil
        var plateauWindowOverride: Int? = nil
        var plateauToleranceOverride: Double? = nil
        init() {}
    }

    @Model final class SetEntry {
        @Attribute(.unique) var id: UUID = UUID()
        var orderIndex: Int = 0
        var weight: Double = 0
        var reps: Int = 0
        var rpe: Double? = nil
        var rir: Int? = nil
        var restAfterSeconds: Int? = nil
        var tempoActual: String? = nil
        var notes: String? = nil
        var isWarmup: Bool = false
        var setTypeRaw: String = "working"
        var completedAt: Date = Date.now
        var partialReps: Int? = nil
        var clusterSubRepsJoined: String? = nil
        var isComplete: Bool = false
        var wasManualOverride: Bool = false
        init() {}
    }
}

/// `SessionExercise` as it was before RM-066 named machines, attribute for
/// attribute, with no `MachineProfile` table. The relationships are left
/// out, as in `PreCatalogShape`; the store still opens.
private enum PreMachineShape {
    @Model final class SessionExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var orderIndex: Int = 0
        var targetSets: Int = 3
        var targetRepsLow: Int = 8
        var targetRepsHigh: Int = 12
        var targetRPE: Double? = nil
        var targetRIR: Int? = nil
        var prescribedRestSeconds: Int = 120
        var tempo: String? = nil
        var tracksTempo: Bool = false
        var tracksPartialReps: Bool = false
        var prescribedWeight: Double? = nil
        var pinnedNote: String? = nil
        var exerciseNameSnapshot: String = ""
        init() {}
    }
}

@MainActor
@Suite("IncompatibleStoreRecovery", .serialized)
struct IncompatibleStoreRecoveryTests {

    private let fm = FileManager.default

    private func makeDirectory() throws -> URL {
        let dir = fm.temporaryDirectory
            .appendingPathComponent("fitbod-recovery-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func contents(of dir: URL) -> [String] {
        ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    /// An isolated defaults suite carrying the seed stamps of a seeded store.
    private func stampedDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "fitbod-recovery-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(3, forKey: ExerciseLibraryImporter.seedVersionKey)
        defaults.set(true, forKey: PlateInventorySeeder.seededKey)
        return (defaults, suiteName)
    }

    private func stampsAreSet(in defaults: UserDefaults) -> Bool {
        defaults.integer(forKey: ExerciseLibraryImporter.seedVersionKey) == 3
            && defaults.bool(forKey: PlateInventorySeeder.seededKey)
    }

    /// Writes a store with the incompatible shape, then releases it. The
    /// `.default_SUPPORT` folder, where SwiftData keeps external attribute
    /// data, is added by hand because this shape has no such attribute.
    private func writeIncompatibleStore(at url: URL) throws {
        try autoreleasepool {
            let schema = Schema([IncompatibleShape.Exercise.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let ctx = ModelContext(container)
            let old = IncompatibleShape.Exercise()
            old.name = 42
            ctx.insert(old)
            try ctx.save()
        }
        let support = url.deletingLastPathComponent().appendingPathComponent(".default_SUPPORT", isDirectory: true)
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try Data("photo".utf8).write(to: support.appendingPathComponent("blob"))
    }

    private let storeFileNames = [".default_SUPPORT", "default.store", "default.store-shm", "default.store-wal"]

    // MARK: - (a) incompatible

    @Test("(a) incompatible store is moved aside with its siblings, not deleted, and a fresh store works")
    func incompatibleStoreIsMovedAside() throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        try writeIncompatibleStore(at: url)
        #expect(contents(of: dir) == storeFileNames)
        let originalStore = try Data(contentsOf: url)

        // Seed stamps from the old store's life, in an isolated defaults suite.
        let (defaults, suiteName) = try stampedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // The factory must not crash or throw.
        let container = try FitbodModelContainer.make(storeURL: url, defaults: defaults)

        // The fresh store must be re-seeded, so the seed stamps are cleared.
        #expect(defaults.object(forKey: ExerciseLibraryImporter.seedVersionKey) == nil)
        #expect(defaults.object(forKey: PlateInventorySeeder.seededKey) == nil)

        // The old store was moved with its siblings, not deleted.
        let archiveRoot = dir.appendingPathComponent("IncompatibleStores", isDirectory: true)
        let stamps = contents(of: archiveRoot)
        #expect(stamps.count == 1)
        let archived = archiveRoot.appendingPathComponent(try #require(stamps.first))
        #expect(contents(of: archived) == storeFileNames)
        #expect(try Data(contentsOf: archived.appendingPathComponent("default.store")) == originalStore)
        #expect(try Data(contentsOf: archived.appendingPathComponent(".default_SUPPORT/blob")) == Data("photo".utf8))

        // A fresh store sits at the original URL and is usable.
        #expect(fm.fileExists(atPath: url.path))
        let ctx = ModelContext(container)
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).isEmpty)
        let exercise = Exercise()
        exercise.name = "Fresh"
        ctx.insert(exercise)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    // MARK: - (b) additive

    @Test("(b) additive change opens the existing store in place with data intact")
    func additiveChangeOpensInPlace() throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let plateID = UUID()

        do {
            let schema = Schema([AdditiveOldShape.PlateInventory.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let ctx = ModelContext(container)
            let old = AdditiveOldShape.PlateInventory()
            old.id = plateID
            old.barWeight = 25
            old.equipmentKindRaw = "dumbbell"
            ctx.insert(old)
            try ctx.save()
        }

        let defaults = try #require(UserDefaults(suiteName: "fitbod-additive-\(UUID().uuidString)"))
        defaults.set(3, forKey: ExerciseLibraryImporter.seedVersionKey)
        let container = try FitbodModelContainer.make(storeURL: url, defaults: defaults)
        // Seed stamps stay untouched on an in-place open.
        #expect(defaults.integer(forKey: ExerciseLibraryImporter.seedVersionKey) == 3)

        // Nothing was moved aside.
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent("IncompatibleStores").path))

        // The old row survived, and the new attribute took its default.
        let rows = try ModelContext(container).fetch(FetchDescriptor<PlateInventory>())
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.id == plateID)
        #expect(row.barWeight == 25)
        #expect(row.equipmentKindRaw == "dumbbell")
        #expect(row.updatedAt <= Date.now)
    }

    @Test("(b) a store from before the catalog and set fields opens in place with the new fields at their defaults")
    func preCatalogStoreOpensInPlace() throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let exerciseID = UUID()
        let setID = UUID()

        do {
            let schema = Schema([PreCatalogShape.Exercise.self, PreCatalogShape.SetEntry.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let ctx = ModelContext(container)
            let dip = PreCatalogShape.Exercise()
            dip.id = exerciseID
            dip.name = "My Ring Dip"
            dip.isCustom = true
            dip.equipmentRaw = "bodyweight"
            ctx.insert(dip)
            let set = PreCatalogShape.SetEntry()
            set.id = setID
            set.weight = 0
            set.reps = 12
            set.isComplete = true
            ctx.insert(set)
            try ctx.save()
        }

        let container = try FitbodModelContainer.make(storeURL: url, defaults: try stampedDefaults().defaults)
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent("IncompatibleStores").path))

        let ctx = ModelContext(container)
        let exercise = try #require(try ctx.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.id == exerciseID)
        #expect(exercise.name == "My Ring Dip")
        #expect(exercise.familyName == nil)
        #expect(exercise.variantLabel == nil)
        #expect(exercise.aliasesJoined == "")
        #expect(exercise.trackingRaw == nil)
        #expect(exercise.brand == nil)
        #expect(exercise.loadingRaw == nil)
        #expect(exercise.isHidden == false)
        // An old custom bodyweight exercise still logs at zero added weight.
        #expect(exercise.tracking == .reps)

        let set = try #require(try ctx.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(set.id == setID)
        #expect(set.reps == 12)
        #expect(set.isComplete)
        #expect(set.startedAt == nil)
        #expect(set.durationSeconds == nil)
        #expect(set.distanceMeters == nil)
        #expect(set.level == nil)
    }

    @Test("(b) a store from before machines opens in place, its logs without a machine, and takes one")
    func preMachineStoreOpensInPlace() throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let logID = UUID()

        do {
            let schema = Schema([PreMachineShape.SessionExercise.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let ctx = ModelContext(container)
            let log = PreMachineShape.SessionExercise()
            log.id = logID
            log.exerciseNameSnapshot = "Hack Squat (Machine)"
            log.prescribedWeight = 140
            ctx.insert(log)
            try ctx.save()
        }

        let container = try FitbodModelContainer.make(storeURL: url, defaults: try stampedDefaults().defaults)
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent("IncompatibleStores").path))

        let ctx = ModelContext(container)
        let log = try #require(try ctx.fetch(FetchDescriptor<SessionExercise>()).first)
        #expect(log.id == logID)
        #expect(log.exerciseNameSnapshot == "Hack Squat (Machine)" && log.prescribedWeight == 140)
        #expect(log.machine == nil)

        let machine = MachineProfile()
        ctx.insert(machine)
        machine.manufacturer = "Panatta"
        machine.model = "Super Hack Squat"
        log.machine = machine
        try ctx.save()
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<SessionExercise>()).first)
        #expect(reread.machine?.displayName == "Panatta Super Hack Squat")
    }

    // MARK: - (c) failures that are not the schema

    /// Ways an open fails that have nothing to do with the schema. Each can
    /// be undone.
    enum Damage: CaseIterable {
        /// The store file cannot be read.
        case unreadableStore
        /// The `-shm` file cannot be opened.
        case unreadableSharedMemory
        /// The `-wal` file cannot be opened.
        case unreadableWriteAheadLog
        /// The store file holds bytes that are not a database.
        case overwrittenStore

        /// What Core Data reports on iOS 26.5, as `summary(of:)` prints it.
        var coreDataReason: String {
            switch self {
            case .unreadableStore: "NSCocoaErrorDomain 257"
            case .unreadableSharedMemory, .unreadableWriteAheadLog: "NSCocoaErrorDomain 256, SQLite 14"
            case .overwrittenStore: "NSCocoaErrorDomain 259, SQLite 26"
            }
        }

        func apply(to url: URL) throws {
            let fm = FileManager.default
            switch self {
            case .unreadableStore: try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
            case .unreadableSharedMemory: try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path + "-shm")
            case .unreadableWriteAheadLog: try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path + "-wal")
            case .overwrittenStore: try Data(repeating: 0x5A, count: 8192).write(to: url)
            }
        }

        func undo(at url: URL, storeBytes: Data) throws {
            let fm = FileManager.default
            switch self {
            case .unreadableStore: try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            case .unreadableSharedMemory: try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path + "-shm")
            case .unreadableWriteAheadLog: try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path + "-wal")
            case .overwrittenStore: try storeBytes.write(to: url)
            }
        }
    }

    @Test("(c) a failure that is not the schema leaves the store in place, and it opens once the cause is gone",
          arguments: Damage.allCases)
    func nonSchemaFailureKeepsTheStore(_ damage: Damage) throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let (defaults, suiteName) = try stampedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // A store holding one finished workout, released before it is damaged.
        try autoreleasepool {
            let context = ModelContext(try FitbodModelContainer.make(storeURL: url, defaults: defaults))
            let exercise = LoggerFixtures.exercise("Bench Press", in: context)
            try LoggerFixtures.session(
                exercise: exercise, startedAt: .now, completedAt: .now,
                sets: [(100, 5, true), (102.5, 4, true)], in: context
            )
        }
        #expect(contents(of: dir) == storeFileNames)
        let storeBytes = try Data(contentsOf: url)

        try damage.apply(to: url)
        let error = #expect(throws: FitbodModelContainer.StoreOpenError.self) {
            try FitbodModelContainer.make(storeURL: url, defaults: defaults)
        }
        // SwiftData throws one error for every failure; the reason the app
        // shows is Core Data's.
        #expect(error.map(FitbodModelContainer.summary(of:)) == damage.coreDataReason)

        // The store, -shm, -wal and _SUPPORT are where they were, nothing was
        // moved aside, and the seeders still see a seeded store.
        #expect(contents(of: dir) == storeFileNames)
        #expect(stampsAreSet(in: defaults))

        try damage.undo(at: url, storeBytes: storeBytes)
        #expect(try Data(contentsOf: url) == storeBytes, "The failed open must not change the store file")

        // The retry opens the same store with the workout intact.
        try autoreleasepool {
            let context = ModelContext(try FitbodModelContainer.make(storeURL: url, defaults: defaults))
            let workouts = try context.fetch(FetchDescriptor<Session>())
            #expect(workouts.count == 1)
            let sets = (workouts.first?.exercises?.first?.sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
            #expect(sets.map(\.weight) == [100, 102.5])
            #expect(sets.map(\.reps) == [5, 4])
            #expect(workouts.first?.exercises?.first?.exerciseNameSnapshot == "Bench Press")
        }
        #expect(contents(of: dir) == storeFileNames)
        #expect(stampsAreSet(in: defaults))
    }

    @Test("(c) a store that still needs an additive migration stays in place when it cannot be written")
    func pendingMigrationOnAReadOnlyStoreKeepsTheStore() throws {
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let plateID = UUID()
        let (defaults, suiteName) = try stampedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try autoreleasepool {
            let schema = Schema([AdditiveOldShape.PlateInventory.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let ctx = ModelContext(container)
            let old = AdditiveOldShape.PlateInventory()
            old.id = plateID
            old.barWeight = 25
            ctx.insert(old)
            try ctx.save()
        }
        let before = contents(of: dir)
        let storeBytes = try Data(contentsOf: url)

        // The store's schema differs from the app's, as an incompatible
        // store's does, but the migration fails only because the file is
        // read-only. Core Data reports a failed migration (134110), not a
        // missing mapping model (134140).
        try fm.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        let error = #expect(throws: FitbodModelContainer.StoreOpenError.self) {
            try FitbodModelContainer.make(storeURL: url, defaults: defaults)
        }
        #expect(error.map(FitbodModelContainer.summary(of:)) == "NSCocoaErrorDomain 134110, SQLite 8")
        #expect(contents(of: dir) == before)
        #expect(stampsAreSet(in: defaults))
        #expect(try Data(contentsOf: url) == storeBytes, "The failed open must not change the store file")

        // Writable again: the same store migrates in place with its row.
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        let container = try FitbodModelContainer.make(storeURL: url, defaults: defaults)
        let rows = try ModelContext(container).fetch(FetchDescriptor<PlateInventory>())
        #expect(rows.count == 1)
        #expect(rows.first?.id == plateID)
        #expect(rows.first?.barWeight == 25)
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent("IncompatibleStores").path))
        #expect(stampsAreSet(in: defaults))
    }

    // MARK: - (d) partial move

    @Test("(d) an incompatible store that cannot be moved completely is put back whole")
    func partialMoveAsideIsPutBack() throws {
        let dir = try makeDirectory()
        let support = dir.appendingPathComponent(".default_SUPPORT", isDirectory: true)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: support.path)
            try? fm.removeItem(at: dir)
        }
        let url = dir.appendingPathComponent("default.store")
        let (defaults, suiteName) = try stampedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try writeIncompatibleStore(at: url)
        let storeBytes = try Data(contentsOf: url)

        // A folder moves to another parent only when the folder itself is
        // writable, so the fourth move fails after the store, -shm and -wal
        // have already moved.
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: support.path)

        #expect(throws: CocoaError.self) {
            try FitbodModelContainer.make(storeURL: url, defaults: defaults)
        }

        // Every file is back where it was and nothing is left in the archive.
        let archiveRoot = dir.appendingPathComponent("IncompatibleStores", isDirectory: true)
        #expect(contents(of: dir).filter { $0 != "IncompatibleStores" } == storeFileNames)
        #expect(contents(of: archiveRoot).isEmpty)
        #expect(try Data(contentsOf: url) == storeBytes)
        #expect(try Data(contentsOf: support.appendingPathComponent("blob")) == Data("photo".utf8))
        // The old store is still the one at the URL, so it is still stamped.
        #expect(stampsAreSet(in: defaults))
    }

    // MARK: - Factory basics

    @Test("plate inventory seed key mirrors the seeder's key")
    func plateKeyMirrorsSeeder() {
        #expect(FitbodModelContainer.plateInventorySeededKey == PlateInventorySeeder.seededKey)
    }

    @Test("in-memory container builds without touching disk")
    func inMemoryBuilds() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        #expect(container.schema.entities.count == SchemaV7.models.count)
    }
}
