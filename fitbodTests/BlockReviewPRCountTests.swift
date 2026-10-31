//
//  BlockReviewPRCountTests.swift
//  fitbodTests
//
//  Ticket T99, finding F142. The block review's PRS stat counts the working
//  sets logged during the block that set a PR, by the in-workout banner's
//  check: the lifter's finished history replays oldest first through
//  PRDetector from an empty table, so a set counts only when it beats every
//  set logged before it, in the block or before it.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockReviewPRCount", .serialized)
struct BlockReviewPRCountTests {
    private let day: TimeInterval = 86_400
    private let started = Date(timeIntervalSince1970: 1_780_000_000)

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeBench(in context: ModelContext) -> Exercise {
        let bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        context.insert(bench)
        return bench
    }

    /// A four-week block that ran from `started`, ended.
    private func makeBlock(in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = "Peak Block"
        block.startDate = started
        block.endDate = started + 28 * day
        return block
    }

    /// A workout of `exercise` on `date` with one working set of `weight`
    /// x `reps`, finished an hour later unless `finished` is false.
    private func logWorkout(
        of exercise: Exercise,
        on date: Date,
        weight: Double,
        reps: Int,
        block: Block? = nil,
        finished: Bool = true,
        in context: ModelContext
    ) {
        let session = Session()
        context.insert(session)
        session.startedAt = date
        session.completedAt = finished ? date + 3_600 : nil
        session.block = block

        let sessionExercise = SessionExercise()
        context.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = exercise

        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = sessionExercise
        set.weight = weight
        set.reps = reps
        set.completedAt = date + 600
        set.isComplete = true
        set.setTypeRaw = SetType.working.rawValue
    }

    private func prCount(of block: Block, in context: ModelContext) throws -> Int {
        BlockReviewStatistics.prCount(context: context, start: block.startDate, end: try #require(block.endDate))
    }

    @Test("only the block's 105 x 5 sets a PR when an earlier 100 x 5 came before the block")
    func countsOnlyTheSetsThatBeatEarlierHistory() throws {
        let context = try makeContext()
        let bench = makeBench(in: context)
        let block = makeBlock(in: context)
        logWorkout(of: bench, on: started - 7 * day, weight: 100, reps: 5, in: context)
        logWorkout(of: bench, on: started + 7 * day, weight: 100, reps: 5, block: block, in: context)
        logWorkout(of: bench, on: started + 14 * day, weight: 105, reps: 5, block: block, in: context)
        try context.save()

        let count = try prCount(of: block, in: context)
        #expect(count == 1,
                "The block's 100 x 5 ties the earlier one, and its 105 x 5 is one set however many PR kinds it sets")
    }

    @Test("an unfinished workout in the block and a workout after it never count")
    func onlyTheBlocksFinishedWorkoutsCount() throws {
        let context = try makeContext()
        let bench = makeBench(in: context)
        let block = makeBlock(in: context)
        logWorkout(of: bench, on: started - 7 * day, weight: 100, reps: 5, in: context)
        logWorkout(of: bench, on: started + 7 * day, weight: 105, reps: 5, block: block, in: context)
        logWorkout(of: bench, on: started + 14 * day, weight: 110, reps: 5, block: block, finished: false, in: context)
        logWorkout(of: bench, on: started + 35 * day, weight: 115, reps: 5, in: context)
        try context.save()

        let count = try prCount(of: block, in: context)
        #expect(count == 1, "Only the finished 105 x 5 in the block counts")
    }
}
