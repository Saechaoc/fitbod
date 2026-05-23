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

    @Test("BlockReviewView placeholder copy is verbatim")
    func placeholderCopyVerbatim() throws {
        let source = try blockReviewSource()

        #expect(source.contains("\"Coming in Phase 6. Full PR detection ships with the progress views update.\""))
        #expect(source.contains("\"Not enough sessions logged to compute deltas.\""))
        #expect(source.contains("\"No logged sets in this block.\""))
    }

    @Test("recommended CTA copy format is present")
    func recommendedCTACopyFormat() throws {
        let source = try blockReviewSource()

        #expect(source.contains("\"Start \\(labelKind.capitalized) Block\""))
        #expect(source.contains("\"Not now\""))
    }

    @Test("done toolbar copy is verbatim")
    func doneToolbarCopyVerbatim() throws {
        let source = try blockReviewSource()

        #expect(source.contains("Button(\"Done\")"))
    }

    @Test("TodayView wires pending block review sheet")
    func todayViewWiresPendingBlockReviewSheet() throws {
        let source = try source("fitbod/App/RootView.swift")

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
