//
//  BlockReviewMathTests.swift
//  fitbodTests
//
//  Phase 4 coverage for BlockReviewView statistics and acknowledge write.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockReviewMath", .serialized)
struct BlockReviewMathTests {
    private let day: TimeInterval = 86_400

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeExercise(_ name: String = "Bench Press") -> Exercise {
        Exercise(
            name: name,
            canonicalName: name.lowercased(),
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
    }

    private func makeBlock(
        start: Date = Date(timeIntervalSince1970: 1_700_000_000),
        end: Date? = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(14 * 86_400)
    ) -> Block {
        let block = Block()
        block.name = "Peak Block"
        block.startDate = start
        block.endDate = end
        block.isActive = true
        return block
    }

    @discardableResult
    private func insertSet(
        in context: ModelContext,
        block: Block?,
        exercise: Exercise,
        date: Date,
        weight: Double,
        reps: Int,
        isComplete: Bool = true,
        isWarmup: Bool = false
    ) -> SetEntry {
        let session = Session()
        session.startedAt = date
        session.completedAt = date
        session.block = block
        context.insert(session)

        let sessionExercise = SessionExercise()
        sessionExercise.session = session
        sessionExercise.exercise = exercise
        context.insert(sessionExercise)

        let set = SetEntry()
        set.sessionExercise = sessionExercise
        set.weight = weight
        set.reps = reps
        set.completedAt = date
        set.isComplete = isComplete
        set.isWarmup = isWarmup
        set.setTypeRaw = SetType.working.rawValue
        context.insert(set)
        return set
    }

    @Test("E1RMHelper Epley uses weight times reps factor")
    func e1RMHelperEpleyFormula() {
        #expect(abs(E1RMHelper.epley(weight: 100, reps: 5) - 116.666) < 0.01)
        #expect(E1RMHelper.epley(weight: 100, reps: 0) == 100)
        #expect(E1RMHelper.epley(weight: 100, reps: 11) == 100)
    }

    @Test("total volume sums completed working sets over block range")
    func totalVolumeSumsOverBlockRange() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(14 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        for offset in [1, 2, 3] {
            insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(Double(offset) * day), weight: 100, reps: 5)
            insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(Double(offset) * day + 60), weight: 100, reps: 5)
        }
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(-day), weight: 100, reps: 5)
        try context.save()

        #expect(BlockReviewStatistics.totalVolume(context: context, start: start, end: end) == 3_000)
    }

    @Test("total volume excludes warmup and incomplete sets")
    func totalVolumeExcludesWarmupAndIncompleteSets() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5)
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5, isWarmup: true)
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5, isComplete: false)
        try context.save()

        #expect(BlockReviewStatistics.totalVolume(context: context, start: start, end: end) == 500)
    }

    @Test("e1RM delta positive for improved top set")
    func e1RMDeltaPositiveForImprovedTopSet() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(14 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5)
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(10 * day), weight: 105, reps: 5)
        try context.save()

        let delta = try #require(BlockReviewStatistics.e1RMDeltas(context: context, start: start, end: end).first)
        #expect(delta.exerciseName == "Bench Press")
        #expect(abs(delta.delta - 5.83) < 0.1)
    }

    @Test("e1RM delta negative for regressed top set")
    func e1RMDeltaNegativeForRegressedTopSet() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(14 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 105, reps: 5)
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(10 * day), weight: 100, reps: 5)
        try context.save()

        let delta = try #require(BlockReviewStatistics.e1RMDeltas(context: context, start: start, end: end).first)
        #expect(delta.delta < 0)
    }

    @Test("e1RM delta is zero for unchanged top set")
    func e1RMDeltaIsZeroForUnchangedTopSet() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(14 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5)
        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(10 * day), weight: 100, reps: 5)
        try context.save()

        let delta = try #require(BlockReviewStatistics.e1RMDeltas(context: context, start: start, end: end).first)
        #expect(abs(delta.delta) < 0.001)
    }

    @Test("empty deltas when less than two sessions per exercise")
    func emptyDeltasWhenLessThanTwoSessionsPerExercise() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(14 * day)
        let block = makeBlock(start: start, end: end)
        let exercise = makeExercise()
        context.insert(block)
        context.insert(exercise)

        insertSet(in: context, block: block, exercise: exercise, date: start.addingTimeInterval(day), weight: 100, reps: 5)
        try context.save()

        #expect(BlockReviewStatistics.e1RMDeltas(context: context, start: start, end: end).isEmpty)
    }

    @Test("recommended next kind for block ending in deload")
    func recommendedNextKindForBlockEndingInDeload() {
        let block = makeBlock()
        let phase = BlockPhase()
        phase.orderIndex = 0
        phase.nameRaw = BlockPhaseKind.deload.rawValue
        block.phases = [phase]

        #expect(BlockReviewStatistics.recommendedNextKind(for: block) == .accumulation)
    }

    @Test("recommended next kind for block ending in realization")
    func recommendedNextKindForBlockEndingInRealization() {
        let block = makeBlock()
        let phase = BlockPhase()
        phase.orderIndex = 0
        phase.nameRaw = BlockPhaseKind.realization.rawValue
        block.phases = [phase]

        #expect(BlockReviewStatistics.recommendedNextKind(for: block) == .deload)
    }

    @Test("acknowledge records reviewedAt and changes nothing else on the block")
    func acknowledgeRecordsOnlyReviewedAt() throws {
        let context = try makeContext()
        let block = makeBlock()
        context.insert(block)
        try context.save()
        let start = block.startDate
        let end = block.endDate
        let reviewedAt = Date(timeIntervalSince1970: 1_700_010_000)

        try BlockReviewStatistics.acknowledge(block: block, context: context, now: reviewedAt)

        #expect(block.reviewedAt == reviewedAt)
        #expect(block.isActive, "Acknowledging never writes isActive")
        #expect(block.startDate == start)
        #expect(block.endDate == end)
    }

    @Test("acknowledge writes only reviewedAt, in a transaction")
    func acknowledgeTransactionWrapperIsPresent() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("fitbod/Periodization/BlockReviewView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("try context.transaction"))
        #expect(source.contains("block.reviewedAt = now"))
        #expect(!source.contains("isActive = "), "Only BlockLifecycleService ends a block")
    }
}
