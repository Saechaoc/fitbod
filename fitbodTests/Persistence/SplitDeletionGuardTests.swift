//
//  SplitDeletionGuardTests.swift
//  fitbodTests
//
//  WR-03 (Phase 7 review): verifies the service-layer deny rule for Split
//  deletion/archive (spec §4). A Split referenced by any non-completed
//  (draft / ready / active) block must NOT be deletable; a Split referenced
//  only by completed blocks (or by no block) is deletable.
//
//  SwiftData's `.deny` is unconditional, so this conditional rule lives in
//  `SplitDeletionGuard` rather than the schema — these tests pin that
//  contract. Mirrors the SchemaV7MigrationTests in-memory V7 container shape.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SplitDeletionGuard", .serialized)
struct SplitDeletionGuardTests {

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

    /// Builds a split with one slot so a referencing block can reach .ready.
    private func makeSplitWithSlot(_ ctx: ModelContext, name: String) -> Split {
        let split = Split()
        ctx.insert(split)
        split.name = name

        let template = SessionTemplate()
        ctx.insert(template)
        template.name = "\(name) session"

        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = template
        return split
    }

    @Test("A split with no referencing blocks is deletable")
    func unreferencedSplitIsDeletable() throws {
        let ctx = try makeContext()
        let split = makeSplitWithSlot(ctx, name: "Orphan")
        try ctx.save()

        #expect(SplitDeletionGuard.canDelete(split))
        #expect(throws: Never.self) { try SplitDeletionGuard.assertDeletable(split) }
    }

    @Test("A split referenced only by a completed block is deletable")
    func completedBlockReferenceIsDeletable() throws {
        let ctx = try makeContext()
        let split = makeSplitWithSlot(ctx, name: "Done")

        let block = Block()
        ctx.insert(block)
        block.name = "Finished Block"
        block.endDate = Date(timeIntervalSinceNow: -86400)   // → derivedStatus == .completed
        block.split = split
        try ctx.save()

        #expect(block.derivedStatus == .completed)
        #expect(SplitDeletionGuard.canDelete(split))
        #expect(throws: Never.self) { try SplitDeletionGuard.assertDeletable(split) }
    }

    @Test("A split referenced by an active (non-completed) block is NOT deletable")
    func activeBlockReferenceIsDenied() throws {
        let ctx = try makeContext()
        let split = makeSplitWithSlot(ctx, name: "Live")

        let block = Block()
        ctx.insert(block)
        block.name = "Active Block"
        block.isActive = true                 // → derivedStatus == .active (non-completed)
        block.split = split
        try ctx.save()

        #expect(block.derivedStatus == .active)
        #expect(!SplitDeletionGuard.canDelete(split))
        #expect(throws: SplitDeletionError.referencedByLiveBlock) {
            try SplitDeletionGuard.assertDeletable(split)
        }
    }

    @Test("A split referenced by a draft block is NOT deletable")
    func draftBlockReferenceIsDenied() throws {
        let ctx = try makeContext()
        // No slot wired → block stays .draft even with a split attached.
        let split = Split()
        ctx.insert(split)
        split.name = "Draft-referenced"

        let block = Block()
        ctx.insert(block)
        block.name = "Draft Block"
        block.split = split                   // attached but zero slots → .draft
        try ctx.save()

        #expect(block.derivedStatus == .draft)
        #expect(!SplitDeletionGuard.canDelete(split))
        #expect(throws: SplitDeletionError.referencedByLiveBlock) {
            try SplitDeletionGuard.assertDeletable(split)
        }
    }

    @Test("A live block reference denies deletion even when a completed block also references the split")
    func mixedReferencesDenyOnLiveBlock() throws {
        let ctx = try makeContext()
        let split = makeSplitWithSlot(ctx, name: "Shared")

        let completed = Block()
        ctx.insert(completed)
        completed.name = "Completed"
        completed.endDate = Date(timeIntervalSinceNow: -86400)
        completed.split = split

        let active = Block()
        ctx.insert(active)
        active.name = "Active"
        active.isActive = true
        active.split = split
        try ctx.save()

        #expect(!SplitDeletionGuard.canDelete(split))
        #expect(throws: SplitDeletionError.referencedByLiveBlock) {
            try SplitDeletionGuard.assertDeletable(split)
        }
    }
}
