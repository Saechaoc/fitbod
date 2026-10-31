//
//  BlockReviewTriggerTests.swift
//  fitbodTests
//
//  Ticket T70, finding F53. BlockLifecycleService.end gives an ended block
//  its end date, and Today opens the review of the block that ended last
//  until the lifter acknowledges it. A block that ended before it never
//  opens one. The copy checks pin the review's BRU layout and Today's sheet.
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

    // Phase 04.1 BRU-reskin: placeholder copy tests updated to match the new BRU layout.
    // The PRs section was deleted (moved to hero band stat cell with "COMING IN PHASE 6" sub-label).
    // "No logged sets in this block." moved to TONNAGE = "0" hero value — empty state is handled by
    // workingSetCount == 0 mapping to zero TONNAGE. The e1RM empty-state copy is preserved verbatim.
    @Test("BlockReviewView placeholder copy is verbatim (BRU 04.1)")
    func placeholderCopyVerbatim() throws {
        let source = try blockReviewSource()

        // e1RM empty-state copy preserved verbatim (plan spec: "Not enough sessions logged to compute deltas.")
        #expect(source.contains("\"Not enough sessions logged to compute deltas.\""))
        // PRs stat cell sub-label in hero band (Phase 6 placeholder — replaces old Section("PRs hit"))
        #expect(source.contains("\"COMING IN PHASE 6\""))
        // BRU section head copy (04.1 spec)
        #expect(source.contains("\"e1RM movement\""))
    }

    // Phase 04.1 BRU-reskin: "Start \(labelKind.capitalized) Block" + "Not now" replaced by
    // BRUButton(.signal, "Start next ▸") + BRUButton(.ghost, "Plan custom") per block-review.jsx lines 90-91.
    @Test("recommended CTA copy format is present (BRU 04.1)")
    func recommendedCTACopyFormat() throws {
        let source = try blockReviewSource()

        #expect(source.contains("\"Start next ▸\""))
        #expect(source.contains("\"Plan custom\""))
    }

    // Phase 04.1 BRU-reskin: Done toolbar button replaced by bottom action bar per plan must_haves.
    // "Start next ▸" BRUButton(.signal) is the primary acknowledge+transition CTA.
    @Test("done toolbar replaced by BRU bottom action bar (BRU 04.1)")
    func doneToolbarCopyVerbatim() throws {
        let source = try blockReviewSource()

        // New BRU bottom action bar CTAs
        #expect(source.contains("\"Start next ▸\""))
        #expect(source.contains("BRUButton"))
        // Old Done toolbar button must be gone
        #expect(!source.contains("Button(\"Done\")"))
    }

    // Phase 04.1 note: block review sheet wiring lives in TodayView.swift (not RootView.swift).
    // Test updated to check the correct file path.
    @Test("TodayView wires pending block review sheet")
    func todayViewWiresPendingBlockReviewSheet() throws {
        let source = try source("fitbod/Views/TodayView.swift")

        #expect(source.contains("pendingBlockReview"))
        #expect(source.contains(".sheet(item: $pendingBlockReview, onDismiss: showRecapAfterReview)"))
        #expect(source.contains("BlockReviewView(block: block)"))
        #expect(source.contains("BlockReviewStatistics.pendingReviewBlocks"))
    }

    private func blockReviewSource() throws -> String {
        try source("fitbod/Periodization/BlockReviewView.swift")
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
