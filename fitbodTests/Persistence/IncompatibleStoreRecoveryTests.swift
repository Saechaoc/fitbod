//
//  IncompatibleStoreRecoveryTests.swift
//  fitbodTests
//
//  Covers the two outcomes of opening an on-disk store through
//  `FitbodModelContainer.make(storeURL:)`:
//
//    (a) The store was written with an incompatible model shape. SwiftData
//        throws, the factory moves the store files into
//        `IncompatibleStores/<timestamp>/` (never deleting them) and builds a
//        fresh store.
//    (b) The store was written with an older ADDITIVE shape (an attribute that
//        the current model added later, with a default). SwiftData migrates it
//        automatically and the store opens in place with its data intact.
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

@MainActor
@Suite("IncompatibleStoreRecovery", .serialized)
struct IncompatibleStoreRecoveryTests {

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func contents(of dir: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    @Test("(a) incompatible store is moved aside, not deleted, and a fresh store works")
    func incompatibleStoreIsMovedAside() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        // Write a store with the incompatible shape, then release it.
        do {
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
        #expect(FileManager.default.fileExists(atPath: url.path))
        let originalSize = try #require(
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        ).intValue

        // Seed stamps from the old store's life, in an isolated defaults suite.
        let suiteName = "fitbod-recovery-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(3, forKey: ExerciseLibraryImporter.seedVersionKey)
        defaults.set(true, forKey: PlateInventorySeeder.seededKey)

        // The factory must not crash or throw.
        let container = try FitbodModelContainer.make(storeURL: url, defaults: defaults)

        // The fresh store must be re-seeded, so the seed stamps are cleared.
        #expect(defaults.object(forKey: ExerciseLibraryImporter.seedVersionKey) == nil)
        #expect(defaults.object(forKey: PlateInventorySeeder.seededKey) == nil)

        // The old store was moved, not deleted.
        let archiveRoot = dir.appendingPathComponent("IncompatibleStores", isDirectory: true)
        let stamps = contents(of: archiveRoot)
        #expect(stamps.count == 1)
        let archived = archiveRoot.appendingPathComponent(try #require(stamps.first))
        let archivedStore = archived.appendingPathComponent("default.store")
        #expect(FileManager.default.fileExists(atPath: archivedStore.path))
        let archivedSize = try #require(
            try FileManager.default.attributesOfItem(atPath: archivedStore.path)[.size] as? NSNumber
        ).intValue
        #expect(archivedSize == originalSize)

        // A fresh store sits at the original URL and is usable.
        #expect(FileManager.default.fileExists(atPath: url.path))
        let ctx = ModelContext(container)
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).isEmpty)
        let exercise = Exercise()
        exercise.name = "Fresh"
        ctx.insert(exercise)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test("(b) additive change opens the existing store in place with data intact")
    func additiveChangeOpensInPlace() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
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
        #expect(!FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("IncompatibleStores").path))

        // The old row survived, and the new attribute took its default.
        let rows = try ModelContext(container).fetch(FetchDescriptor<PlateInventory>())
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.id == plateID)
        #expect(row.barWeight == 25)
        #expect(row.equipmentKindRaw == "dumbbell")
        #expect(row.updatedAt <= Date.now)
    }

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
