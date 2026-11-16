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
    /// out of order, used by an active, a ready and a draft block and by
    /// two blocks that ended 200 and 30 days ago, saved.
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
        // A phase makes a named block on a routine with sessions ready.
        for (name, isActive) in [("Ready Block", false), ("Active Block", true)] {
            let block = Block()
            ctx.insert(block)
            block.name = name
            block.split = split
            block.isActive = isActive
            let phase = BlockPhase()
            ctx.insert(phase)
            phase.block = block
        }
        try ctx.save()
        return split
    }

    /// Each routine's archive flag, read through a fresh context, so it is
    /// what the store holds.
    private func storedFlags(in ctx: ModelContext) throws -> [Bool] {
        try ModelContext(ctx.container).fetch(FetchDescriptor<Split>()).map(\.isArchived)
    }

    /// The page's two helpers only; ArchiveRoutineUITests proves that
    /// opening the page leaves the routine archived.
    @Test("The page's helpers read the sessions in rotation order and the blocks the active one first, then ready and draft ones, then the ended ones, newest first, and write nothing")
    func helpersReadInOrderWithoutWriting() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let split = try archivedRoutine(in: ctx)

        let blocks = ArchivedRoutineView.blocks(of: split)
        #expect(ArchivedRoutineView.sessions(of: split).map { $0.sessionTemplate?.name } == ["Push", "Pull", "Legs"])
        #expect(blocks.map(\.name) == ["Active Block", "Ready Block", "Draft Block", "Summer Block", "Winter Block"])
        #expect(blocks.map(\.derivedStatus) == [.active, .ready, .draft, .completed, .completed])
        #expect(!ctx.hasChanges)
        #expect(try storedFlags(in: ctx) == [true])
    }

    @Test("Restore saves the routine back into the routine lists; a failed save rolls back and keeps it archived for a retry")
    func restoreSavesOrKeepsTheRoutineArchived() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let split = try archivedRoutine(in: ctx)

        #expect(throws: Failure.self) {
            try restoreRoutine(split, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(split.isArchived, "A failed restore must show the routine as the store holds it")
        #expect(!ctx.hasChanges, "A failed restore must leave nothing for a later save to write")
        #expect(try storedFlags(in: ctx) == [true])

        try restoreRoutine(split, context: ctx)
        #expect(!split.isArchived)
        #expect(try storedFlags(in: ctx) == [false])
    }
}
