//
//  TodayResolverTests.swift
//  fitbodTests
//
//  Spec §9 scheduler suite — covers the unified rotation predicate and
//  fixedWeekly branch of TodayResolver.
//
//  Each @Test maps to a distinct fall-out path in the unified predicate,
//  proving that ad-hoc, deleted-slot, swapped-split, and in-progress
//  sessions are all excluded by the same predicate, not enumerated cases.
//
//  Suite shape mirrors SplitDeletionGuardTests (Phase 7):
//    @MainActor + @Suite(.serialized) + SchemaV7 in-memory container.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("TodayResolver", .serialized)
struct TodayResolverTests {

    // MARK: - Context

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Fixtures

    /// Builds and inserts a Block with a fresh Split wired and `slotCount`
    /// SplitSessionSlot rows at positions 0…slotCount-1.
    ///
    /// Insert-before-relate convention (CLAUDE.md SwiftData rule):
    /// every object is inserted into context before any relationship assignment.
    @discardableResult
    private func makeBlock(
        slotCount: Int,
        mode: SchedulingMode = .rotation,
        context ctx: ModelContext
    ) throws -> (block: Block, split: Split, slots: [SplitSessionSlot]) {
        let split = Split()
        ctx.insert(split)
        split.name = "Test Split"

        var slots: [SplitSessionSlot] = []
        for i in 0..<slotCount {
            let template = SessionTemplate()
            ctx.insert(template)
            template.name = "Day \(i)"

            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.position = i
            slot.sessionTemplate = template
            slot.split = split
            slots.append(slot)
        }

        let block = Block()
        ctx.insert(block)
        block.name = "Test Block"
        block.isActive = true
        block.split = split
        block.schedulingMode = mode

        try ctx.save()
        return (block, split, slots)
    }

    /// Inserts a completed Session anchored to `slot` and `block`.
    @discardableResult
    private func completeSession(
        slot: SplitSessionSlot,
        block: Block,
        startedAt: Date,
        context ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(3600)
        session.block = block
        session.slot = slot
        try ctx.save()
        return session
    }

    // MARK: - Rotation tests

    @Test("rotation: no completed sessions → slot 0")
    func rotationNoSessionsReturnsSlot0() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 4, context: ctx)

        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 0)
        } else {
            Issue.record("Expected .session(slot 0), got \(resolution)")
        }
        // Verify it matches one of our known slots
        let expected = slots.first(where: { $0.position == 0 })
        if case .session(let slot) = resolution {
            #expect(slot.id == expected?.id)
        }
    }

    @Test("rotation: latest completed at position 2 → next is position 3")
    func rotationAdvancesFromPosition2To3() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 4, context: ctx)
        let base = Date(timeIntervalSinceReferenceDate: 0)
        try completeSession(slot: slots[0], block: block, startedAt: base, context: ctx)
        try completeSession(slot: slots[1], block: block, startedAt: base.addingTimeInterval(86400), context: ctx)
        try completeSession(slot: slots[2], block: block, startedAt: base.addingTimeInterval(172800), context: ctx)

        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 3)
        } else {
            Issue.record("Expected .session(slot 3), got \(resolution)")
        }
    }

    @Test("rotation: latest completed at last position → wraps to slot 0")
    func rotationWrapsFromLastSlotToZero() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 4, context: ctx)
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // Complete all 4 slots — latest is slot[3]
        for i in 0..<4 {
            try completeSession(slot: slots[i], block: block, startedAt: base.addingTimeInterval(Double(i) * 86400), context: ctx)
        }

        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 0, "Should wrap: (3+1) % 4 == 0")
        } else {
            Issue.record("Expected .session(slot 0) after wrap, got \(resolution)")
        }
    }

    @Test("rotation: ad-hoc latest session (slot=nil) is skipped; prior live-slot session anchors")
    func rotationSkipsAdHocSession() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 4, context: ctx)
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // A real slotted session at position 1 (older)
        try completeSession(slot: slots[1], block: block, startedAt: base, context: ctx)

        // An ad-hoc session (slot=nil) that is NEWER than the slotted one
        let adhoc = Session()
        ctx.insert(adhoc)
        adhoc.startedAt = base.addingTimeInterval(86400)
        adhoc.completedAt = base.addingTimeInterval(90000)
        adhoc.block = block
        adhoc.slot = nil   // ad-hoc
        try ctx.save()

        // Rotation should skip the ad-hoc and anchor on the slotted session at position 1
        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 2, "Should advance past position 1 (the live anchor), not 0")
        } else {
            Issue.record("Expected .session(slot 2), got \(resolution)")
        }
    }

    @Test("rotation: swapped-split session (slot.split != block.split) is skipped")
    func rotationSkapsSwappedSplitSession() throws {
        let ctx = try makeContext()
        let (block, _, _) = try makeBlock(slotCount: 3, context: ctx)

        // A separate split with its own slot — simulates a prior split that was swapped out
        let oldSplit = Split()
        ctx.insert(oldSplit)
        oldSplit.name = "Old Split"

        let oldTemplate = SessionTemplate()
        ctx.insert(oldTemplate)
        oldTemplate.name = "Old Day A"

        let oldSlot = SplitSessionSlot()
        ctx.insert(oldSlot)
        oldSlot.position = 2
        oldSlot.sessionTemplate = oldTemplate
        oldSlot.split = oldSplit
        try ctx.save()

        // Session referencing the OLD slot (slot.split != block.split)
        let staleSession = Session()
        ctx.insert(staleSession)
        staleSession.startedAt = Date(timeIntervalSinceReferenceDate: 86400)
        staleSession.completedAt = Date(timeIntervalSinceReferenceDate: 90000)
        staleSession.block = block
        staleSession.slot = oldSlot   // swapped-split slot
        try ctx.save()

        // No qualifying anchor → should fall back to slot 0
        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 0, "Swapped-split session must be skipped; anchor falls back to slot 0")
        } else {
            Issue.record("Expected .session(slot 0), got \(resolution)")
        }
    }

    @Test("rotation: in-progress session (completedAt=nil) does not advance rotation — Pitfall 5")
    func rotationIgnoresInProgressSession() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 3, context: ctx)

        // An in-progress session at position 0 (completedAt == nil)
        let inProgress = Session()
        ctx.insert(inProgress)
        inProgress.startedAt = Date(timeIntervalSinceReferenceDate: 0)
        inProgress.completedAt = nil   // still running
        inProgress.block = block
        inProgress.slot = slots[0]
        try ctx.save()

        // Resolver must ignore in-progress session; no completed anchor → slot 0
        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 0, "In-progress session must not advance rotation; still at slot 0")
        } else {
            Issue.record("Expected .session(slot 0), got \(resolution)")
        }
    }

    @Test("rotation: reorder — next position computed against current slot positions")
    func rotationComputesNextAgainstCurrentPositions() throws {
        // Spec §5: position arithmetic uses the CURRENT slot graph, not the
        // position stored on the anchor session's slot object.
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 4, context: ctx)
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // Complete slot at position 1
        try completeSession(slot: slots[1], block: block, startedAt: base, context: ctx)

        // Simulate a reorder by changing current slot positions in the split.
        // Slot that was at position 1 is now at position 3 (reordered).
        // The resolver reads slot.position from the live graph at query time.
        slots[1].position = 3
        slots[3].position = 1
        try ctx.save()

        // Anchor slot now reports position 3 → next = (3+1) % 4 = 0
        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 0, "After reorder, anchor.position == 3 → next is 0")
        } else {
            Issue.record("Expected .session(slot 0) after reorder, got \(resolution)")
        }
    }

    @Test("rotation: deleted-slot (session.slot nullified) reads as ad-hoc and is skipped")
    func rotationSkipsDeletedSlotSession() throws {
        let ctx = try makeContext()
        let (block, _, slots) = try makeBlock(slotCount: 3, context: ctx)
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // A prior slotted session at position 0 (older)
        try completeSession(slot: slots[0], block: block, startedAt: base, context: ctx)

        // A newer completed session whose slot was nullified (simulates SplitSessionSlot delete)
        let nullifiedSession = Session()
        ctx.insert(nullifiedSession)
        nullifiedSession.startedAt = base.addingTimeInterval(86400)
        nullifiedSession.completedAt = base.addingTimeInterval(90000)
        nullifiedSession.block = block
        nullifiedSession.slot = nil   // nullified — slot was deleted
        try ctx.save()

        // Nullified-slot session is skipped; anchor falls back to the slotted session at position 0
        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .session(let slot) = resolution {
            #expect(slot.position == 1, "Nullified-slot session skipped; anchor at 0 → next is 1")
        } else {
            Issue.record("Expected .session(slot 1), got \(resolution)")
        }
    }

    @Test("rotation: split emptied mid-block (0 slots) → .emptySplit, no crash — Pitfall 3")
    func rotationZeroSlotsReturnsEmptySplit() throws {
        let ctx = try makeContext()
        // Build with 0 slots — simulates a mid-block split that was emptied
        let (block, _, _) = try makeBlock(slotCount: 0, context: ctx)

        let resolution = TodayResolver.resolve(block: block, context: ctx)

        // Must return .emptySplit, not crash (Pitfall-3 guard)
        if case .emptySplit = resolution {
            // pass
        } else {
            Issue.record("Expected .emptySplit for zero-slot block, got \(resolution)")
        }
    }

    // MARK: - fixedWeekly tests

    @Test("fixedWeekly: weekday present at stored index 1, 4 slots → slot position 1")
    func fixedWeeklyWeekdayAtIndex1Returns1() throws {
        let ctx = try makeContext()
        let (block, _, _) = try makeBlock(slotCount: 4, mode: .fixedWeekly, context: ctx)

        // Store trainingDays with Sunday(1), Wednesday(4), Friday(6), Saturday(7)
        // Index of Wednesday is 1 → position = 1 % 4 = 1
        block.trainingDays = [1, 4, 6, 7]
        try ctx.save()

        // Pin a calendar to Gregorian, firstWeekday = 1 (Sun-first)
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1

        // Construct a "Wednesday" date — weekday component == 4 in gregorian(1=Sun)
        // Use a known Wednesday: 2026-01-07 is a Wednesday
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 7   // Wednesday
        let wednesday = cal.date(from: comps)!
        #expect(cal.component(.weekday, from: wednesday) == 4)  // sanity-check

        let resolution = TodayResolver.resolve(block: block, context: ctx, today: wednesday, calendar: cal)

        if case .session(let slot) = resolution {
            #expect(slot.position == 1, "storedIndex(4 in [1,4,6,7]) == 1 → position 1%4 == 1")
        } else {
            Issue.record("Expected .session(position 1), got \(resolution)")
        }
    }

    @Test("fixedWeekly: weekday absent → .restDay")
    func fixedWeeklyAbsentWeekdayReturnsRestDay() throws {
        let ctx = try makeContext()
        let (block, _, _) = try makeBlock(slotCount: 3, mode: .fixedWeekly, context: ctx)

        // trainingDays: Monday(2), Wednesday(4), Friday(6) — no Sunday(1)
        block.trainingDays = [2, 4, 6]
        try ctx.save()

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1

        // Sunday = weekday 1 — not in trainingDays
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 4   // Sunday 2026-01-04
        let sunday = cal.date(from: comps)!
        #expect(cal.component(.weekday, from: sunday) == 1)

        let resolution = TodayResolver.resolve(block: block, context: ctx, today: sunday, calendar: cal)

        if case .restDay = resolution {
            // pass
        } else {
            Issue.record("Expected .restDay for absent weekday, got \(resolution)")
        }
    }

    @Test("fixedWeekly: count drift — trainingDays has 5 entries, 3 slots, stored index 4 → position 4%3==1")
    func fixedWeeklyCountDriftModGuard() throws {
        let ctx = try makeContext()
        let (block, _, _) = try makeBlock(slotCount: 3, mode: .fixedWeekly, context: ctx)

        // 5 training days stored but only 3 slots (mid-block drift)
        // trainingDays: [1, 2, 3, 4, 5] — Saturday(7) is index 4
        block.trainingDays = [1, 2, 3, 4, 7]   // 7=Sat at storedIndex 4
        try ctx.save()

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1

        // Saturday 2026-01-10
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 10
        let saturday = cal.date(from: comps)!
        #expect(cal.component(.weekday, from: saturday) == 7)

        // storedIndex == 4, slotCount == 3 → position = 4 % 3 = 1
        let resolution = TodayResolver.resolve(block: block, context: ctx, today: saturday, calendar: cal)

        if case .session(let slot) = resolution {
            #expect(slot.position == 1, "4 % 3 == 1; mod is the runtime guard for slot-count drift")
        } else {
            Issue.record("Expected .session(position 1) for drift case, got \(resolution)")
        }
    }

    @Test("fixedWeekly: 0 slots → .emptySplit")
    func fixedWeeklyZeroSlotsReturnsEmptySplit() throws {
        let ctx = try makeContext()
        let (block, _, _) = try makeBlock(slotCount: 0, mode: .fixedWeekly, context: ctx)

        block.trainingDays = [2, 4, 6]
        try ctx.save()

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1

        // Monday 2026-01-05 (weekday 2 — in trainingDays)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 5
        let monday = cal.date(from: comps)!
        #expect(cal.component(.weekday, from: monday) == 2)

        let resolution = TodayResolver.resolve(block: block, context: ctx, today: monday, calendar: cal)

        if case .emptySplit = resolution {
            // pass
        } else {
            Issue.record("Expected .emptySplit for zero-slot fixedWeekly block, got \(resolution)")
        }
    }

    // MARK: - Shared / edge cases

    @Test("block.split == nil → .noBlock")
    func nilSplitReturnsNoBlock() throws {
        let ctx = try makeContext()

        let block = Block()
        ctx.insert(block)
        block.name = "Splitless Block"
        block.isActive = true
        block.split = nil
        try ctx.save()

        let resolution = TodayResolver.resolve(block: block, context: ctx)

        if case .noBlock = resolution {
            // pass
        } else {
            Issue.record("Expected .noBlock for block without split, got \(resolution)")
        }
    }
}
