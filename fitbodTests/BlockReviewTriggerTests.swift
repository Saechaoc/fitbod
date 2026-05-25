//
//  BlockReviewTriggerTests.swift
//  fitbodTests
//
//  Phase 4 coverage for end-of-block review trigger wiring and copy.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockReviewTrigger", .serialized)
struct BlockReviewTriggerTests {
    private let day: TimeInterval = 86_400

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func insertBlock(
        in context: ModelContext,
        now: Date,
        isActive: Bool,
        endOffsetDays: Double?,
        reviewedAt: Date? = nil
    ) throws -> Block {
        let block = Block()
        block.name = "Review Candidate"
        block.startDate = now.addingTimeInterval(-14 * day)
        block.endDate = endOffsetDays.map { now.addingTimeInterval($0 * day) }
        block.isActive = isActive
        block.reviewedAt = reviewedAt
        context.insert(block)
        try context.save()
        return block
    }

    private func pendingReviews(in context: ModelContext, now: Date) throws -> [Block] {
        try BlockReviewStatistics.pendingReviewBlocks(context: context, now: now)
    }

    @Test("trigger predicate matches ended active unreviewed block")
    func triggerPredicateMatchesEndedActiveUnreviewedBlock() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: -1)

        #expect(try pendingReviews(in: context, now: now).count == 1)
    }

    @Test("trigger excludes active but unended block")
    func triggerExcludesActiveButUnendedBlock() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: 7)

        #expect(try pendingReviews(in: context, now: now).isEmpty)
    }

    @Test("trigger excludes ended but inactive block")
    func triggerExcludesEndedButInactiveBlock() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(in: context, now: now, isActive: false, endOffsetDays: -1)

        #expect(try pendingReviews(in: context, now: now).isEmpty)
    }

    @Test("trigger excludes ended active but reviewed block")
    func triggerExcludesEndedActiveButReviewedBlock() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(
            in: context,
            now: now,
            isActive: true,
            endOffsetDays: -1,
            reviewedAt: now.addingTimeInterval(-day)
        )

        #expect(try pendingReviews(in: context, now: now).isEmpty)
    }

    @Test("trigger excludes block with nil end date")
    func triggerExcludesBlockWithNilEndDate() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: nil)

        #expect(try pendingReviews(in: context, now: now).isEmpty)
    }

    @Test("trigger returns at least one if invariant is violated")
    func triggerReturnsAtLeastOneIfInvariantIsViolated() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: -1)
        _ = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: -2)

        let matches = try pendingReviews(in: context, now: now)
        #expect(matches.count >= 1)
        #expect(matches.first != nil)
    }

    @Test("acknowledgment removes block from trigger set")
    func acknowledgmentRemovesBlockFromTriggerSet() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = try insertBlock(in: context, now: now, isActive: true, endOffsetDays: -1)
        #expect(try pendingReviews(in: context, now: now).count == 1)

        try BlockReviewStatistics.acknowledge(block: block, context: context, now: now)

        #expect(try pendingReviews(in: context, now: now).isEmpty)
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
        #expect(source.contains(".sheet(item: $pendingBlockReview)"))
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
