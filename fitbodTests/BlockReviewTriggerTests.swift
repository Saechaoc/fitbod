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
//  RM-013. Today's notice opens the review through BlockReviewPresenter,
//  whose close records it once, keeping the first date. A close that cannot
//  save leaves the review pending and says so until a later close saves.
//
//  RM-016. A save that fails at Start next is made by the review's close,
//  which says so under the row that opened the review only if it fails too.
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

    // MARK: - Closing the review (RM-013)

    /// Opens `block`'s review and closes it at `now`, as the sheet does.
    private func openAndClose(
        _ block: Block, with presenter: inout BlockReviewPresenter, in context: ModelContext, now: Date
    ) {
        presenter.open(block)
        presenter.showing = nil
        presenter.close(in: context, now: now)
    }

    @Test("opening the review records nothing; closing it records it and the notice clears")
    func firstCloseRecordsTheReview() throws {
        let context = try makeContext()
        let block = try startBlock("Strength", at: started, in: context)
        let ended = started + 7 * day
        try BlockLifecycleService.end(block: block, context: context, now: ended)

        var presenter = BlockReviewPresenter()
        presenter.open(block)
        #expect(block.reviewedAt == nil, "Opening the review must not record it")
        #expect(try pendingReviews(in: context, now: ended + day) == [block.id])

        presenter.showing = nil
        presenter.close(in: context, now: ended + day)
        #expect(block.reviewedAt == ended + day)
        #expect(!presenter.isUnsaved(block))
        #expect(try pendingReviews(in: context, now: ended + 2 * day).isEmpty)
    }

    @Test("a second close keeps the first review's date")
    func secondCloseKeepsTheFirstDate() throws {
        let context = try makeContext()
        let block = try startBlock("Strength", at: started, in: context)
        let ended = started + 7 * day
        try BlockLifecycleService.end(block: block, context: context, now: ended)
        var presenter = BlockReviewPresenter()
        openAndClose(block, with: &presenter, in: context, now: ended + day)

        openAndClose(block, with: &presenter, in: context, now: ended + 5 * day)

        #expect(block.reviewedAt == ended + day, "Reopening a review must not move its date")
        #expect(!presenter.isUnsaved(block))
    }

    /// A disk store, in a folder of its own that the caller removes, with
    /// Strength ended at `ended` and its review pending.
    private func storeWithEndedBlock(ended: Date) throws -> (folder: URL, url: URL, blockID: UUID) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlockReviewTrigger-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("review.store")
        let blockID = try autoreleasepool {
            let context = ModelContext(try FitbodModelContainer.make(storeURL: url))
            let block = try startBlock("Strength", at: started, in: context)
            try BlockLifecycleService.end(block: block, context: context, now: ended)
            return block.id
        }
        return (folder, url, blockID)
    }

    /// The store at `url` opened so that every save fails, as a full disk would.
    private func readOnlyContext(_ url: URL) throws -> ModelContext {
        let schema = Schema(versionedSchema: FitbodModelContainer.CurrentSchema.self)
        return ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false)
        ))
    }

    private func block(_ id: UUID, in context: ModelContext) throws -> Block {
        try #require(try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == id })).first)
    }

    @Test("a close that cannot save keeps the review pending and says so, until a later close saves")
    func failedCloseKeepsTheReviewPending() throws {
        let ended = started + 7 * day
        let store = try storeWithEndedBlock(ended: ended)
        defer { try? FileManager.default.removeItem(at: store.folder) }

        var presenter = BlockReviewPresenter()
        try autoreleasepool {
            let readOnly = try readOnlyContext(store.url)
            let unsaved = try block(store.blockID, in: readOnly)
            openAndClose(unsaved, with: &presenter, in: readOnly, now: ended + day)
            #expect(unsaved.reviewedAt == nil, "A failed save must leave the review unseen")
            #expect(!readOnly.hasChanges, "Nothing may stay pending for a later save to write")
            #expect(presenter.isUnsaved(unsaved), "The opening row must say the review was not saved")
            #expect(try pendingReviews(in: readOnly, now: ended + day) == [store.blockID], "The notice must stay")
        }

        let context = ModelContext(try FitbodModelContainer.make(storeURL: store.url))
        let reopened = try block(store.blockID, in: context)
        #expect(try pendingReviews(in: context, now: ended + 2 * day) == [store.blockID], "The failed close wrote nothing")
        openAndClose(reopened, with: &presenter, in: context, now: ended + 2 * day)
        #expect(reopened.reviewedAt == ended + 2 * day)
        #expect(!presenter.isUnsaved(reopened), "A close that saves clears the line")
        #expect(try pendingReviews(in: context, now: ended + 3 * day).isEmpty)
    }

    // MARK: - Start next's save (RM-016)

    @Test("a save that fails at Start next is made by the review's close, which shows no line")
    func closeRecordsAReviewStartNextCouldNotSave() throws {
        let ended = started + 7 * day
        let store = try storeWithEndedBlock(ended: ended)
        defer { try? FileManager.default.removeItem(at: store.folder) }

        try autoreleasepool {
            let readOnly = try readOnlyContext(store.url)
            let unsaved = try block(store.blockID, in: readOnly)
            BlockReviewStatistics.acknowledgeBeforeNextBlock(block: unsaved, context: readOnly)
            #expect(unsaved.reviewedAt == nil, "A failed save must leave the review unseen")
            #expect(!readOnly.hasChanges, "Nothing may stay pending for a later save to write")
        }

        // New block closes, and the review closes with it.
        let context = ModelContext(try FitbodModelContainer.make(storeURL: store.url))
        let reviewed = try block(store.blockID, in: context)
        var presenter = BlockReviewPresenter()
        openAndClose(reviewed, with: &presenter, in: context, now: ended + day)
        #expect(reviewed.reviewedAt == ended + day, "The close must record the review Start next could not")
        #expect(!presenter.isUnsaved(reviewed), "A close that saves shows no line")
        #expect(try pendingReviews(in: context, now: ended + 2 * day).isEmpty)
    }

    @Test("when Start next's save and the close's both fail, the review stays pending and its row says so")
    func failedStartNextAndCloseKeepTheReviewPending() throws {
        let ended = started + 7 * day
        let store = try storeWithEndedBlock(ended: ended)
        defer { try? FileManager.default.removeItem(at: store.folder) }

        try autoreleasepool {
            let readOnly = try readOnlyContext(store.url)
            let unsaved = try block(store.blockID, in: readOnly)
            var presenter = BlockReviewPresenter()
            presenter.open(unsaved)
            BlockReviewStatistics.acknowledgeBeforeNextBlock(block: unsaved, context: readOnly)
            #expect(unsaved.reviewedAt == nil, "A failed save must leave the review unseen")

            // New block closes, and the review's close tries again in the
            // same context: a review still read as seen would skip the save.
            presenter.showing = nil
            presenter.close(in: readOnly, now: ended + day)
            #expect(unsaved.reviewedAt == nil, "A second failed save must leave the review unseen")
            #expect(!readOnly.hasChanges, "Nothing may stay pending for a later save to write")
            #expect(presenter.isUnsaved(unsaved), "The row that opened the review must say it was not saved")
            #expect(try pendingReviews(in: readOnly, now: ended + day) == [store.blockID], "The notice must stay")
        }
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
