//
//  RollBackTests.swift
//  fitbodTests
//
//  A rolled-back change must not stay on screen. SwiftData (Xcode 26.5)
//  leaves loaded models showing the discarded values after
//  `ModelContext.rollback()` until they are fetched again. After a save
//  that really failed, the first fetch refreshes nothing; the failed-save
//  cases below catch that (RM-002).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RollBack", .serialized)
struct RollBackTests {

    @Test("a rolled-back edit reads the saved value again")
    func rolledBackEditReadsSavedValue() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        bench.name = "Discarded"
        SessionSetActions.rollBack(ctx)

        #expect(bench.name == "Bench")
        #expect(!ctx.hasChanges)
    }

    @Test("a rolled-back delete leaves the model readable and saved")
    func rolledBackDeleteKeepsModel() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        ctx.delete(bench)
        SessionSetActions.rollBack(ctx)

        #expect(!bench.isDeleted)
        #expect(bench.name == "Bench")
        #expect(try ctx.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test("a rolled-back insert is gone")
    func rolledBackInsertIsGone() throws {
        let ctx = try LoggerFixtures.makeContext()
        _ = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        _ = LoggerFixtures.exercise("Discarded", in: ctx)
        SessionSetActions.rollBack(ctx)

        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Bench"])
    }

    // MARK: - After a save that failed

    /// A block named "Strength" and a workout with one logged 100 x 5 set,
    /// saved on disk, then read through a second context on the same store
    /// whose every save fails, as a full disk's would.
    @MainActor
    private struct FailingStore {
        let directory: URL
        let context: ModelContext
        let block: Block
        let set: SetEntry

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("RollBack-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("rollback.store")
            let (blockID, setID) = try autoreleasepool {
                let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
                let block = Block()
                ctx.insert(block)
                block.name = "Strength"
                let session = try LoggerFixtures.session(
                    exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: .now, completedAt: nil,
                    sets: [(100, 5, true)], in: ctx
                )
                return (block.id, try #require(session.exercises?.first?.sets?.first).id)
            }
            let schema = Schema(versionedSchema: FitbodModelContainer.CurrentSchema.self)
            context = ModelContext(try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false)
            ))
            block = try #require(try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == blockID })).first)
            set = try #require(try context.fetch(FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == setID })).first)
        }
    }

    @Test("after a failed save, rolled-back edits on two kinds of model read the saved values again")
    func failedSaveEditsReadSavedValues() throws {
        let store = try FailingStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        store.block.name = "Discarded"
        store.block.reviewedAt = .now
        store.set.weight = 140
        store.set.reps = 1

        #expect(throws: (any Error).self) { try SessionSetActions.saveOrRollBack(store.context) }

        #expect(store.block.name == "Strength")
        #expect(store.block.reviewedAt == nil)
        #expect(store.set.weight == 100)
        #expect(store.set.reps == 5)
        #expect(!store.context.hasChanges)
    }

    @Test("after a failed save, a rolled-back delete is back in its exercise")
    func failedSaveDeleteIsBack() throws {
        let store = try FailingStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let exercise = try #require(store.set.sessionExercise)
        store.context.delete(store.set)

        #expect(throws: (any Error).self) { try SessionSetActions.saveOrRollBack(store.context) }

        #expect(!store.set.isDeleted)
        #expect(store.set.weight == 100)
        #expect(exercise.sets?.map(\.persistentModelID) == [store.set.persistentModelID])
        #expect(try store.context.fetchCount(FetchDescriptor<SetEntry>()) == 1)
    }

    @Test("after a failed save, rolled-back inserts are gone, from fetches and from their exercise")
    func failedSaveInsertsAreGone() throws {
        let store = try FailingStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let exercise = try #require(store.set.sessionExercise)
        let added = SetEntry()
        store.context.insert(added)
        added.sessionExercise = exercise
        let block = Block()
        store.context.insert(block)
        block.name = "Discarded"

        #expect(throws: (any Error).self) { try SessionSetActions.saveOrRollBack(store.context) }

        #expect(try store.context.fetch(FetchDescriptor<Block>()).map(\.name) == ["Strength"])
        #expect(try store.context.fetchCount(FetchDescriptor<SetEntry>()) == 1)
        // Compared by identifier: reading a discarded set's values crashes.
        #expect(exercise.sets?.map(\.persistentModelID) == [store.set.persistentModelID])
        #expect(!store.context.hasChanges)
    }

    @Test("a refused edit is not written by a later save that succeeds")
    func refusedEditIsNotSavedLater() throws {
        let ctx = try LoggerFixtures.makeContext()
        let block = Block()
        ctx.insert(block)
        block.name = "Strength"
        let slot = SplitSessionSlot()
        ctx.insert(slot)
        let routine = SessionTemplate()
        ctx.insert(routine)
        slot.sessionTemplate = routine
        try ctx.save()

        // A writable store's save fails validation: `.deny` keeps a slot that still holds its routine.
        block.name = "Discarded"
        ctx.delete(slot)
        #expect(throws: (any Error).self) { try SessionSetActions.saveOrRollBack(ctx) }
        #expect(block.name == "Strength")

        block.notes = "Later"
        try ctx.save()
        let stored = try #require(try ModelContext(ctx.container).fetch(FetchDescriptor<Block>()).first)
        #expect(stored.name == "Strength")
        #expect(stored.notes == "Later")
    }
}
