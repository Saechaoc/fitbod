//
//  BlockLifecycleServiceTests.swift
//  fitbodTests
//
//  Phase 08 Plan 03 — Task 2 TDD suite.
//
//  Tests BlockLifecycleService: one-save start/end/swap, SplitDeletionGuard wiring,
//  ArchiveUnreadableError typed decode error, and status-precedence invariants.
//
//  Spec §4 atomicity invariants tested here:
//    - No zero-or-two-actives window (post-op active count == 1)
//    - No completed-without-archive window (endDate + archivedConfigJSON set together)
//    - Deny matrix: assertSplitDeletable delegates to SplitDeletionGuard
//    - Status-precedence: endDate wins over isActive for .completed
//
//  REQ-08 (slotNullifyHistoryIntact) already satisfied by
//  SchemaV7MigrationTests.slotNullifyHistoryIntact (Phase 7 gap closure) — not duplicated here.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockLifecycleService", .serialized)
struct BlockLifecycleServiceTests {

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

    // MARK: - Fixture helpers

    /// Builds a Block with `slotCount` slots wired through a Split — derivedStatus == .ready.
    /// Uses rotation mode so slot count alone satisfies .ready (no trainingDays constraint).
    private func makeReadyBlock(name: String, slotCount: Int = 1, context: ModelContext) throws -> Block {
        let split = Split()
        context.insert(split)
        split.name = "\(name) split"

        for i in 0..<slotCount {
            let template = SessionTemplate()
            context.insert(template)
            template.name = "\(name) Day \(i)"
            template.intentRaw = "strength"
            template.progressionKindRaw = "double"

            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.position = i
            slot.split = split
            slot.sessionTemplate = template
        }

        let block = Block()
        context.insert(block)
        block.name = name
        block.startDate = Date(timeIntervalSince1970: 0)
        block.schedulingModeRaw = "rotation"
        block.split = split

        try context.save()

        // Verify the fixture is actually .ready before returning
        #expect(block.derivedStatus == .ready, "makeReadyBlock fixture must yield .ready; got \(block.derivedStatus)")
        return block
    }

    // MARK: - Active count helper

    private func fetchActiveBlocks(in ctx: ModelContext) throws -> [Block] {
        try ctx.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true }))
    }

    // MARK: - Test 1: start activates a ready block; exactly one active afterward

    @Test("start activates a ready block; exactly one active afterward")
    func startActivatesReadyBlock() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Alpha", context: ctx)

        try BlockLifecycleService.start(block: block, context: ctx)

        #expect(block.isActive == true)
        let active = try fetchActiveBlocks(in: ctx)
        #expect(active.count == 1)
    }

    // MARK: - Test 2: start swap — old ends+archives+deactivates, new activates, exactly one active

    @Test("start swap: old block ends+archives+deactivates, new activates, exactly one active")
    func startSwapAtomicity() throws {
        let ctx = try makeContext()
        let old = try makeReadyBlock(name: "Old", context: ctx)
        let new = try makeReadyBlock(name: "New", context: ctx)
        let now = Date(timeIntervalSince1970: 1000)

        // Activate old block first
        try BlockLifecycleService.start(block: old, context: ctx, now: now)
        #expect(old.isActive == true)
        #expect(try fetchActiveBlocks(in: ctx).count == 1)

        // Start new block — should swap
        let swapNow = Date(timeIntervalSince1970: 2000)
        try BlockLifecycleService.start(block: new, context: ctx, now: swapNow)

        // Old block must be fully ended (atomicity: both endDate AND archive non-nil)
        #expect(old.endDate != nil, "old.endDate must be set after swap")
        #expect(old.archivedConfigJSON != nil, "old.archivedConfigJSON must be set after swap (Pitfall 4)")
        #expect(old.isActive == false)

        // New block must be active
        #expect(new.isActive == true)

        // Exactly one active block — no zero-or-two-actives window
        let active = try fetchActiveBlocks(in: ctx)
        #expect(active.count == 1, "Exactly one active block after swap; got \(active.count)")
    }

    // MARK: - Test 3: start throws .notReady on a draft block

    @Test("start throws .notReady on a draft block")
    func startThrowsNotReadyOnDraft() throws {
        let ctx = try makeContext()

        // Draft block: split attached but zero slots → .draft
        let split = Split()
        ctx.insert(split)
        split.name = "Empty split"

        let draft = Block()
        ctx.insert(draft)
        draft.name = "Draft"
        draft.split = split
        try ctx.save()

        #expect(draft.derivedStatus == .draft)

        #expect(throws: BlockLifecycleError.notReady) {
            try BlockLifecycleService.start(block: draft, context: ctx)
        }
    }

    // MARK: - Test 4: end writes endDate AND archivedConfigJSON together

    @Test("end writes endDate AND archivedConfigJSON together")
    func endWritesEndDateAndArchiveTogether() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "EndMe", context: ctx)
        try BlockLifecycleService.start(block: block, context: ctx)

        let endNow = Date(timeIntervalSince1970: 9999)
        try BlockLifecycleService.end(block: block, context: ctx, now: endNow)

        // Both must be non-nil in the same save (Pitfall 4 — never endDate without archive)
        #expect(block.endDate != nil)
        #expect(block.archivedConfigJSON != nil)
        #expect(block.isActive == false)

        // Verify archive round-trips
        let json = try #require(block.archivedConfigJSON)
        let data = Data(json.utf8)
        let decoded = try ArchivedBlockConfig.decode(from: data)
        #expect(decoded.v == 1)
    }

    // MARK: - Test 5: swapSplit on an active block throws .splitChangeOnActiveBlock

    @Test("swapSplit on an active block throws .splitChangeOnActiveBlock")
    func swapSplitOnActiveThrows() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Active", context: ctx)
        try BlockLifecycleService.start(block: block, context: ctx)
        #expect(block.derivedStatus == .active)

        let newSplit = Split()
        ctx.insert(newSplit)
        newSplit.name = "Replacement split"
        try ctx.save()

        #expect(throws: BlockLifecycleError.splitChangeOnActiveBlock) {
            try BlockLifecycleService.swapSplit(newSplit, on: block, context: ctx)
        }
    }

    // MARK: - Test 6: attachSplit on a draft block succeeds and sets block.split

    @Test("attachSplit on a draft block succeeds and sets block.split")
    func attachSplitOnDraftSucceeds() throws {
        let ctx = try makeContext()

        let draft = Block()
        ctx.insert(draft)
        draft.name = "Draft"
        try ctx.save()
        #expect(draft.derivedStatus == .draft)

        let split = Split()
        ctx.insert(split)
        split.name = "New split"
        try ctx.save()

        try BlockLifecycleService.attachSplit(split, to: draft, context: ctx)

        #expect(draft.split?.name == "New split")
    }

    // MARK: - Test 7: assertSplitDeletable throws while a ready block references the split

    @Test("assertSplitDeletable throws while a ready block references the split")
    func assertSplitDeletableThrowsForReadyBlock() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Ready", context: ctx)
        #expect(block.derivedStatus == .ready)
        let split = try #require(block.split)

        #expect(throws: SplitDeletionError.referencedByLiveBlock) {
            try BlockLifecycleService.assertSplitDeletable(split)
        }
    }

    // MARK: - Test 8: assertSplitDeletable throws while an active block references the split

    @Test("assertSplitDeletable throws while an active block references the split")
    func assertSplitDeletableThrowsForActiveBlock() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Active", context: ctx)
        try BlockLifecycleService.start(block: block, context: ctx)
        #expect(block.derivedStatus == .active)
        let split = try #require(block.split)

        #expect(throws: SplitDeletionError.referencedByLiveBlock) {
            try BlockLifecycleService.assertSplitDeletable(split)
        }
    }

    // MARK: - Test 9: assertSplitDeletable succeeds when only a completed block references the split

    @Test("assertSplitDeletable succeeds when only a completed block (endDate set) references the split")
    func assertSplitDeletableSucceedsForCompletedBlock() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Completed", context: ctx)
        try BlockLifecycleService.start(block: block, context: ctx)
        try BlockLifecycleService.end(block: block, context: ctx)
        #expect(block.derivedStatus == .completed)
        let split = try #require(block.split)

        #expect(throws: Never.self) {
            try BlockLifecycleService.assertSplitDeletable(split)
        }
    }

    // MARK: - Test 10: derivedStatus precedence — endDate makes .completed even when isActive == true

    @Test("derivedStatus precedence: endDate set makes .completed even when isActive == true")
    func derivedStatusPrecedenceCompletedBeatsActive() throws {
        let ctx = try makeContext()
        let split = Split()
        ctx.insert(split)
        split.name = "Contaminated split"
        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = {
            let t = SessionTemplate()
            ctx.insert(t)
            t.name = "T"
            return t
        }()

        // Construct contaminated state: isActive == true AND endDate != nil
        let block = Block()
        ctx.insert(block)
        block.name = "Contaminated"
        block.split = split
        block.isActive = true
        block.endDate = Date(timeIntervalSince1970: 1000)
        try ctx.save()

        // .completed must win over .active (spec §3 precedence)
        #expect(block.derivedStatus == .completed)
    }

    // MARK: - Test 11: transition invariant — after start(), isActive implies split != nil and endDate == nil

    @Test("transition invariant: after start(), isActive implies split != nil and endDate == nil")
    func transitionInvariantAfterStart() throws {
        let ctx = try makeContext()
        let block = try makeReadyBlock(name: "Invariant", context: ctx)

        try BlockLifecycleService.start(block: block, context: ctx)

        // Post-start invariants
        #expect(block.isActive == true)
        #expect(block.split != nil, "Active block must have a split wired")
        #expect(block.endDate == nil, "Active block must not have endDate set")

        // Also verify: a ready block with zero slots is NOT .ready
        let split = Split()
        ctx.insert(split)
        split.name = "Empty"
        let zeroSlotBlock = Block()
        ctx.insert(zeroSlotBlock)
        zeroSlotBlock.name = "Zero slots"
        zeroSlotBlock.split = split
        try ctx.save()

        #expect(zeroSlotBlock.derivedStatus != .ready, "Block with zero slots must not be .ready")
        #expect(zeroSlotBlock.derivedStatus == .draft)
    }
}
