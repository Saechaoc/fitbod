//
//  BlockLifecycleEntryPointsTests.swift
//  fitbodTests
//
//  Ticket T67, finding F49: EDIT BLOCK changes a saved block's routine only
//  through BlockLifecycleService, which refuses an active block. An active
//  block keeps its routine; a draft or ready block still takes a new one.
//  F48, the unmounted BlockCard's End Block, was not reproduced; the END
//  BLOCK users reach is covered by BlockLifecycleEntryPointsUITests.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockLifecycleEntryPoints", .serialized)
struct BlockLifecycleEntryPointsTests {
    private let started = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("SAVE CHANGES never gives the active block a new routine")
    func savingAnEditKeepsTheActiveBlocksRoutine() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let routine = try makeRoutine("Upper / Lower", sessions: 2, in: context)
        let other = try makeRoutine("Full Body", sessions: 1, in: context)
        let block = try makeBlock("Strength", routine: routine, in: context)
        try BlockLifecycleService.start(block: block, context: context, now: started)

        let draft = BlockDraft(block: block)
        draft.name = "Strength II"
        draft.split = other
        #expect(throws: BlockLifecycleError.splitChangeOnActiveBlock) {
            try draft.save(into: context)
        }

        let saved = try #require(try fetchBlock(block.id, in: ModelContext(container)))
        #expect(saved.split?.id == routine.id, "The active block must keep its routine")
        #expect(saved.name == "Strength", "A refused save must leave the block as it was")
        #expect(saved.derivedStatus == .active)
        #expect(saved.startDate == started)
    }

    @Test("SAVE CHANGES swaps a ready block's routine and keeps it ready")
    func savingAnEditSwapsAReadyBlocksRoutine() throws {
        let context = try makeContext()
        let routine = try makeRoutine("Upper / Lower", sessions: 2, in: context)
        let other = try makeRoutine("Full Body", sessions: 1, in: context)
        let block = try makeBlock("Strength", routine: routine, in: context)
        #expect(block.derivedStatus == .ready)

        let draft = BlockDraft(block: block)
        draft.name = "Strength II"
        draft.split = other
        try draft.save(into: context)

        #expect(block.split?.id == other.id)
        #expect(block.name == "Strength II")
        #expect(block.derivedStatus == .ready, "A new routine never starts a block")
    }

    @Test("SAVE CHANGES attaches a routine to a draft block, which makes it ready")
    func savingAnEditAttachesARoutineToADraftBlock() throws {
        let context = try makeContext()
        let routine = try makeRoutine("Full Body", sessions: 1, in: context)
        let block = try makeBlock("Base", routine: nil, in: context)
        #expect(block.derivedStatus == .draft)

        let draft = BlockDraft(block: block)
        draft.split = routine
        try draft.save(into: context)

        #expect(block.split?.id == routine.id)
        #expect(block.derivedStatus == .ready)
    }

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeRoutine(_ name: String, sessions: Int, in context: ModelContext) throws -> Split {
        let split = Split()
        context.insert(split)
        split.name = name
        for position in 0..<sessions {
            let template = SessionTemplate()
            context.insert(template)
            template.name = "\(name) \(position + 1)"
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.position = position
            slot.split = split
            slot.sessionTemplate = template
        }
        try context.save()
        return split
    }

    /// A named one-phase rotation block: ready on a routine, a draft without one.
    private func makeBlock(_ name: String, routine: Split?, in context: ModelContext) throws -> Block {
        let block = Block()
        context.insert(block)
        block.name = name
        block.split = routine
        let phase = BlockPhase()
        context.insert(phase)
        phase.block = block
        phase.nameRaw = BlockPhaseKind.accumulation.rawValue
        phase.weeks = 2
        try context.save()
        return block
    }

    private func fetchBlock(_ id: UUID, in context: ModelContext) throws -> Block? {
        try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == id })).first
    }
}
