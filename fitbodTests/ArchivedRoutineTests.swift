import Foundation
import SwiftData
import Testing
@testable import fitbod

/// RM-026, D-33: an archived routine opens read only before it is
/// restored, and RESTORE, on its page or on the list, is the one write.
@MainActor
@Suite("Archived routine")
struct ArchivedRoutineTests {

    private enum Failure: Error { case disk }

    private static let day: TimeInterval = 24 * 3600

    /// An archived routine whose sessions Push, Pull and Legs were slotted
    /// out of order, used by a draft and by two blocks that ended 200 and
    /// 30 days ago, saved.
    private func archivedRoutine(in ctx: ModelContext) throws -> Split {
        let split = Split()
        ctx.insert(split)
        split.name = "Old Split"
        split.isArchived = true
        for (position, name) in [(1, "Pull"), (2, "Legs"), (0, "Push")] {
            let session = SessionTemplate()
            ctx.insert(session)
            session.name = name
            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.split = split
            slot.sessionTemplate = session
            slot.position = position
        }
        for (name, endedDaysAgo) in [("Winter Block", 200.0), ("Draft Block", nil), ("Summer Block", 30.0)] {
            let block = Block()
            ctx.insert(block)
            block.name = name
            block.split = split
            if let endedDaysAgo {
                block.startDate = Date.now.addingTimeInterval(-(endedDaysAgo + 42) * Self.day)
                block.endDate = Date.now.addingTimeInterval(-endedDaysAgo * Self.day)
            }
        }
        try ctx.save()
        return split
    }

    /// Each routine's archive flag, read through a fresh context, so it is
    /// what the store holds.
    private func storedFlags(in ctx: ModelContext) throws -> [Bool] {
        try ModelContext(ctx.container).fetch(FetchDescriptor<Split>()).map(\.isArchived)
    }

    @Test("The page lists the sessions in rotation order and the blocks a live one first, then newest ended first, and reading it writes nothing")
    func pageReadsWithoutWriting() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let split = try archivedRoutine(in: ctx)

        let sessions = ArchivedRoutineView.sessions(of: split)
        let blocks = ArchivedRoutineView.blocks(of: split)
        #expect(sessions.map { $0.sessionTemplate?.name } == ["Push", "Pull", "Legs"])
        #expect(blocks.map(\.name) == ["Draft Block", "Summer Block", "Winter Block"])
        #expect(blocks.map(\.derivedStatus) == [.draft, .completed, .completed])

        // Everything else the page draws from them.
        _ = sessions.compactMap(\.sessionTemplate).map { SessionTemplateSummary(template: $0).line }
        _ = blocks.filter { $0.derivedStatus == .completed }.map { PastBlocksView.line(of: $0) }
        #expect(!ctx.hasChanges)
        #expect(try storedFlags(in: ctx) == [true])
    }

    @Test("Restore saves the routine back into the routine lists; a failed save keeps it archived for a retry")
    func restoreSavesOrKeepsTheRoutineArchived() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let split = try archivedRoutine(in: ctx)

        #expect(throws: Failure.self) {
            try restoreRoutine(split, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(split.isArchived, "A failed restore must show the routine as the store holds it")
        #expect(try storedFlags(in: ctx) == [true])

        try restoreRoutine(split, context: ctx)
        #expect(!split.isArchived)
        #expect(try storedFlags(in: ctx) == [false])
    }
}
