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
//   3. `blockRunSurvivesRelaunches` - the roadmap's P1 acceptance: a block
//      authored, rescheduled and trained through its deload keeps its
//      schedule, its workouts' prescriptions and, once ended, its frozen
//      plan across relaunches.
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

    // MARK: - Test 3: a whole block, from plan to review

    @Test("A block's schedule, frozen plan and workouts survive relaunches")
    @MainActor // BlockDraft, SessionFactory and the review are main-actor isolated.
    func blockRunSurvivesRelaunches() throws {
        let calendar = Calendar.current
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10)))
        #expect(calendar.component(.weekday, from: monday) == 2, "The plan starts on a Monday")
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
        }
        let order = ["A", "C", "B"]

        // Launch 1: author the block, reorder its sessions, change its
        // training days, start it, and train Mon, Wed, Fri and the
        // deload week's Monday.
        let (blockID, unwantedID) = try autoreleasepool { () throws -> (UUID, UUID) in
            let context = try launch()
            let exercise = Exercise.previewSample(name: "Leg Press", equipment: .machine, mechanic: .compound)
            context.insert(exercise)
            let routine = Split()
            context.insert(routine)
            routine.name = "Relaunch Routine"
            var slots: [SplitSessionSlot] = []
            for (position, name) in ["A", "B", "C"].enumerated() {
                let session = SessionTemplate()
                context.insert(session)
                session.name = name
                session.intentRaw = Intent.strength.rawValue
                session.progressionKindRaw = ProgressionKind.double.rawValue
                let item = SessionExerciseTemplate()
                context.insert(item)
                item.sessionTemplate = session
                item.exercise = exercise
                item.targetSets = 4
                item.targetRepsLow = 5
                item.targetRepsHigh = 8
                let slot = SplitSessionSlot()
                context.insert(slot)
                slot.split = routine
                slot.position = position
                slot.sessionTemplate = session
                slots.append(slot)
            }
            // The routine's drag reorder: A, C, B.
            reindexSlots([slots[0], slots[2], slots[1]])
            try context.save()

            let draft = BlockDraft()
            draft.name = "Relaunch Block"
            draft.phases = [
                BlockPhaseDraft(kind: .accumulation, weeks: 1, volumeMultiplier: 1.0, intensityMultiplier: 0.75),
                BlockPhaseDraft(kind: .deload, weeks: 1, volumeMultiplier: 0.5, intensityMultiplier: 0.75),
            ]
            draft.split = routine
            try draft.save(into: context)
            let block = try #require(try context.fetch(FetchDescriptor<Block>()).first)
            // The overview's day chips: fixed weekly, picked Fri, Mon, Wed.
            block.schedulingMode = .fixedWeekly
            block.trainingDays = TrainingDaysWriter.sort(weekdays: [6, 2, 4], using: calendar)
            try context.save()
            try BlockLifecycleService.start(block: block, context: context, now: monday)

            let unwanted = Block()
            context.insert(unwanted)
            unwanted.name = "Unwanted"
            try context.save()

            for offset in [0, 2, 4, 7] {
                let date = day(offset)
                guard case .session(let slot) = TodayResolver.resolve(
                    block: block, context: context, today: date, calendar: calendar
                ), let session = slot.sessionTemplate else {
                    Issue.record("Day \(offset) schedules no session")
                    continue
                }
                let workout = try SessionFactory.start(
                    template: session, slot: slot, activeBlock: block, on: date, context: context
                )
                // Every work set at its prescription, 8 reps; 100 the first time.
                for exerciseLog in workout.exercises ?? [] {
                    let load = (exerciseLog.prescribedWeight ?? 0) > 0 ? exerciseLog.prescribedWeight ?? 100 : 100
                    for set in exerciseLog.sets ?? [] where !set.isWarmup {
                        set.weight = load
                        set.reps = 8
                        set.rpe = 8
                        set.isComplete = true
                        set.completedAt = date.addingTimeInterval(Double(set.orderIndex + 1) * 180)
                    }
                }
                workout.completedAt = date.addingTimeInterval(3_600)
                try context.save()
            }
            return (block.id, unwanted.id)
        }

        // Launch 2: the schedule and every workout read back as saved, the
        // schedule still resolves, and the block ends.
        try autoreleasepool {
            let context = try launch()
            let block = try #require(try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == blockID })).first)
            #expect(block.derivedStatus == .active)
            #expect(block.schedulingMode == .fixedWeekly)
            #expect(block.trainingDays == [2, 4, 6])
            let slots = (block.split?.slots ?? []).sorted { $0.position < $1.position }
            #expect(slots.compactMap { $0.sessionTemplate?.name } == order)

            let workouts = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)]))
            #expect(workouts.map { $0.slot?.sessionTemplate?.name } == ["A", "C", "B", "A"])
            #expect(workouts.map { $0.exercises?.first?.prescribedWeight } == [0, 102.5, 105, 105],
                    "Double progression adds 2.5 a workout, and the deload week holds 105")
            #expect(workouts.map { ($0.exercises?.first?.sets ?? []).filter { !$0.isWarmup }.count } == [4, 4, 4, 2],
                    "The deload week halves the work sets")
            #expect(workouts.allSatisfy { $0.block?.id == blockID })
            guard case .session(let wednesday) = TodayResolver.resolve(
                block: block, context: context, today: day(9), calendar: calendar
            ) else {
                Issue.record("The deload week's Wednesday schedules no session")
                return
            }
            #expect(wednesday.sessionTemplate?.name == "C")

            let unwanted = try #require(try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == unwantedID })).first)
            try BlockLifecycleService.delete(unwanted, context: context)
            try BlockLifecycleService.end(block: block, context: context, now: day(10))
            try BlockReviewStatistics.acknowledge(block: block, context: context, now: day(10))
        }

        // Launch 3: the ended block, its frozen plan, its review and its
        // workouts are all still there, and the deleted draft is gone.
        try autoreleasepool {
            let context = try launch()
            let blocks = try context.fetch(FetchDescriptor<Block>())
            #expect(blocks.map(\.id) == [blockID], "The deleted draft stays deleted")
            let block = try #require(blocks.first)
            #expect(block.derivedStatus == .completed)
            #expect(block.reviewedAt != nil)
            let archive = try BlockLifecycleService.decodeArchive(try #require(block.archivedConfigJSON))
            #expect(archive.mode == SchedulingMode.fixedWeekly.rawValue)
            #expect(archive.trainingDays == [2, 4, 6])
            #expect(archive.split.slots.map(\.sessionName) == order)
            #expect(archive.phases.map(\.kind) == [BlockPhaseKind.accumulation.rawValue, BlockPhaseKind.deload.rawValue])
            let workouts = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)]))
            #expect(workouts.map { $0.exercises?.first?.prescribedWeight } == [0, 102.5, 105, 105],
                    "Each workout keeps the prescription it was given")
        }
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
