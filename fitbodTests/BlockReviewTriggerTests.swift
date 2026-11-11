//
//  BlockReviewTriggerTests.swift
//  fitbodTests
//
//  Ticket T70, finding F53. BlockLifecycleService.end gives an ended block
//  its end date, and Today opens the review of the block that ended last
//  until the lifter acknowledges it. A block that ended before it never
//  opens one.
//
//  Ticket T86, finding F96. While any block is active, no review opens, so
//  a review put off with Plan custom stops once the lifter starts a block.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockReviewTrigger", .serialized)
struct BlockReviewTriggerTests {
    private let day: TimeInterval = 86_400
    private let started = Date(timeIntervalSince1970: 1_780_000_000)

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// A named one-phase rotation block on a one-session routine, started
    /// through BlockLifecycleService at `start`.
    private func startBlock(_ name: String, at start: Date, in context: ModelContext) throws -> Block {
        let split = Split()
        context.insert(split)
        split.name = "\(name) Routine"
        let template = SessionTemplate()
        context.insert(template)
        template.name = "\(name) Day"
        let slot = SplitSessionSlot()
        context.insert(slot)
        slot.position = 0
        slot.split = split
        slot.sessionTemplate = template

        let block = Block()
        context.insert(block)
        block.name = name
        block.split = split
        let phase = BlockPhase()
        context.insert(phase)
        phase.block = block
        phase.nameRaw = BlockPhaseKind.accumulation.rawValue
        phase.weeks = 4
        try context.save()

        try BlockLifecycleService.start(block: block, context: context, now: start)
        return block
    }

    private func pendingReviews(in context: ModelContext, now: Date) throws -> [UUID] {
        try BlockReviewStatistics.pendingReviewBlocks(context: context, now: now).map(\.id)
    }

    @Test("a block that BlockLifecycleService.end ends opens its review")
    func endedBlockOpensItsReview() throws {
        let context = try makeContext()
        let block = try startBlock("Strength", at: started, in: context)
        #expect(try pendingReviews(in: context, now: started + day).isEmpty, "An active block has no review")

        try BlockLifecycleService.end(block: block, context: context, now: started + 7 * day)

        #expect(try pendingReviews(in: context, now: started + 7 * day) == [block.id])
    }

    @Test("the review keeps opening until the lifter acknowledges it")
    func reviewKeepsOpeningUntilAcknowledged() throws {
        let context = try makeContext()
        let block = try startBlock("Strength", at: started, in: context)
        let ended = started + 7 * day
        try BlockLifecycleService.end(block: block, context: context, now: ended)
        #expect(try pendingReviews(in: context, now: ended + day) == [block.id])
        #expect(try pendingReviews(in: context, now: ended + 30 * day) == [block.id])

        try BlockReviewStatistics.acknowledge(block: block, context: context, now: ended + 30 * day)

        #expect(try pendingReviews(in: context, now: ended + 31 * day).isEmpty)
    }

    @Test("only the block that ended last opens a review")
    func onlyTheBlockThatEndedLastOpensAReview() throws {
        let context = try makeContext()
        let base = try startBlock("Base", at: started, in: context)
        try BlockLifecycleService.end(block: base, context: context, now: started + 7 * day)
        let peak = try startBlock("Peak", at: started + 8 * day, in: context)
        try BlockLifecycleService.end(block: peak, context: context, now: started + 14 * day)
        let now = started + 15 * day

        #expect(try pendingReviews(in: context, now: now) == [peak.id])

        try BlockReviewStatistics.acknowledge(block: peak, context: context, now: now)
        #expect(try pendingReviews(in: context, now: now).isEmpty,
                "A block that ended before the last one never opens a review")
    }

    @Test("no review opens while a newer block is active")
    func noReviewOpensWhileANewerBlockIsActive() throws {
        let context = try makeContext()
        let base = try startBlock("Base", at: started, in: context)
        try BlockLifecycleService.end(block: base, context: context, now: started + 7 * day)
        #expect(try pendingReviews(in: context, now: started + 8 * day) == [base.id])

        _ = try startBlock("Peak", at: started + 9 * day, in: context)

        #expect(try pendingReviews(in: context, now: started + 10 * day).isEmpty,
                "An active block stops the review of the block that ended before it")
    }

    @Test("starting the next block ends the active one, whose review never opens")
    func blockEndedByStartingTheNextNeverOpensItsReview() throws {
        let context = try makeContext()
        let base = try startBlock("Base", at: started, in: context)
        let peak = try startBlock("Peak", at: started + 7 * day, in: context)
        #expect(base.endDate != nil, "Starting Peak must end Base")

        #expect(try pendingReviews(in: context, now: started + 8 * day).isEmpty,
                "No review opens while Peak is active")

        try BlockLifecycleService.end(block: peak, context: context, now: started + 14 * day)
        #expect(try pendingReviews(in: context, now: started + 15 * day) == [peak.id])
        try BlockReviewStatistics.acknowledge(block: peak, context: context, now: started + 15 * day)
        #expect(try pendingReviews(in: context, now: started + 16 * day).isEmpty,
                "A block that ended before the last one never opens a review")
    }

    @Test("a planned end date still ahead neither opens a review nor hides one")
    func plannedEndDateAheadIsNotAnEnding() throws {
        let context = try makeContext()
        let block = try startBlock("Strength", at: started, in: context)
        let ended = started + 7 * day
        try BlockLifecycleService.end(block: block, context: context, now: ended)
        // Older builds saved a block's planned end as its end date.
        let planned = Block()
        context.insert(planned)
        planned.name = "Planned"
        planned.endDate = ended + 60 * day
        try context.save()

        #expect(try pendingReviews(in: context, now: ended + day) == [block.id])
    }
}
