//
//  RelaunchPersistenceTests.swift
//  fitbodTests
//
//  T133 - what the lifter changed is still there after the app closes and
//  opens again:
//   1. `editedVolumeTargetSurvivesRelaunch` - the launch's
//      `MuscleVolumeTargetSeeder` keeps a volume target the lifter edited
//      (F311).
//   2. `startedBlockStaysActiveAfterRelaunch` - a block started through
//      `BlockLifecycleService.start` is still the one active block (F370).
//
//  Each test writes through a first container on an on-disk store and
//  releases it, then opens a second container on the same file the way
//  `fitbodApp.init` does. Both contexts have autosave off, so only the
//  saves the code under test makes reach the disk; reading the same
//  in-memory context back would pass even if they never did.
//
//  ## Test isolation
//
//  Swift Testing creates a new instance per test, with its own store
//  directory and defaults suite that `deinit` removes, so tests share
//  nothing mutable and the suite needs no `.serialized`. Each launch's
//  container is released inside an `autoreleasepool` before the next one
//  opens, as `MilestoneOnePersistenceTests` does. A store used on the main
//  thread can stay open until the main run loop idles, after `deinit` has
//  deleted it; SQLite then logs "vnode unlinked while in use", which is
//  harmless because the test has already read the store.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("Relaunch persistence")
final class RelaunchPersistenceTests {

    // MARK: - Helpers

    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RelaunchPersistenceTests.\(UUID().uuidString)", isDirectory: true)
    private let defaultsSuiteName = "RelaunchPersistenceTests.\(UUID().uuidString)"

    /// Where the container factory clears the seed stamps if it ever moves
    /// the store aside; never `UserDefaults.standard`, which the hosted
    /// tests share with the app on the phone (F296).
    private let defaults: UserDefaults

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    /// Opens this test's store the way a launch does, in a context that
    /// writes to disk only when the code under test saves.
    private func launch() throws -> ModelContext {
        let context = ModelContext(try FitbodModelContainer.make(
            storeURL: directory.appendingPathComponent("default.store"), defaults: defaults
        ))
        context.autosaveEnabled = false
        return context
    }

    // MARK: - Test 1: an edited volume target

    @Test("A volume target the lifter edited keeps its value when the next launch reseeds")
    @MainActor // MuscleVolumeTargetSeeder is main-actor isolated.
    func editedVolumeTargetSurvivesRelaunch() throws {
        let editedMEV = try autoreleasepool {
            let context = try launch()
            context.insert(MuscleGroup(slug: "chest", displayName: "Chest"))
            context.insert(MuscleGroup(slug: "lats", displayName: "Lats"))
            MuscleVolumeTargetSeeder.seedIfNeeded(in: context)

            let targets = try context.fetch(FetchDescriptor<MuscleVolumeTarget>())
            // One step up on chest's MEV, written the way MuscleVolumeTargetStepper writes it.
            let chest = try #require(targets.first { $0.muscle?.slug == "chest" })
            chest.mev += 1
            chest.userEdited = true
            // An unedited target left on an older landmark: the next
            // launch's seeder refreshing it proves that the seeder ran.
            let lats = try #require(targets.first { $0.muscle?.slug == "lats" })
            lats.mev -= 1
            try context.save()
            return chest.mev
        }

        try autoreleasepool {
            let context = try launch()
            MuscleVolumeTargetSeeder.seedIfNeeded(in: context)

            let targets = try context.fetch(FetchDescriptor<MuscleVolumeTarget>())
            let chest = targets.filter { $0.muscle?.slug == "chest" }
            #expect(chest.count == 1, "The relaunch must keep one chest target, not add a default beside the edit")
            #expect(chest.first?.mev == editedMEV, "The relaunch's seeder must keep the lifter's edit")
            #expect(chest.first?.userEdited == true)
            let lats = targets.first { $0.muscle?.slug == "lats" }
            #expect(lats?.mev == RPVolumeLandmarks.landmark(for: "lats").mev, "The relaunch's seeder must refresh an unedited target")
        }
    }

    // MARK: - Test 2: a started block

    @Test("A block started through BlockLifecycleService is the one active block after a relaunch")
    func startedBlockStaysActiveAfterRelaunch() throws {
        let startedID = try autoreleasepool {
            let context = try launch()
            let routine = Split()
            context.insert(routine)
            routine.name = "Upper / Lower"
            let session = SessionTemplate()
            context.insert(session)
            session.name = "Upper A"
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = routine
            slot.sessionTemplate = session
            let spring = readyBlock("Spring Block", routine: routine, in: context)
            let summer = readyBlock("Summer Block", routine: routine, in: context)
            try context.save()

            let springStart = Date(timeIntervalSince1970: 1_790_000_000)
            try BlockLifecycleService.start(block: spring, context: context, now: springStart)
            // Spring Block is active, so this start also ends it, in the same save.
            try BlockLifecycleService.start(block: summer, context: context, now: springStart.addingTimeInterval(7 * 86_400))
            return summer.id
        }

        let activeIDs = try autoreleasepool {
            try launch().fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true })).map(\.id)
        }
        #expect(activeIDs == [startedID], "Only the block started last may be active after a relaunch")
    }

    /// A named block with one phase on `routine`, which is all `.ready` needs.
    private func readyBlock(_ name: String, routine: Split, in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = name
        block.split = routine
        let phase = BlockPhase()
        context.insert(phase)
        phase.block = block
        return block
    }
}
