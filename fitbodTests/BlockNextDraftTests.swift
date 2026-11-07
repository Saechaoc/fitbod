//
//  BlockNextDraftTests.swift
//  fitbodTests
//
//  Start next and Plan custom open New block with the ended block's
//  routine, scheduling and training days (decided 2026-11-05): Start next
//  with the recommended preset, Plan custom with the default phases and
//  no name. A routine that is gone or archived is not carried over.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Next block draft", .serialized)
struct BlockNextDraftTests {

    /// An ended block on a two-session routine, fixed weekly on Mon and Thu.
    private func endedBlock(in context: ModelContext) throws -> Block {
        let routine = Split()
        context.insert(routine)
        routine.name = "Upper Lower"
        for position in 0..<2 {
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = routine
            slot.position = position
        }
        let block = Block()
        context.insert(block)
        block.name = "Spring Block"
        block.split = routine
        block.schedulingMode = .fixedWeekly
        block.trainingDays = [2, 5]
        block.endDate = Date(timeIntervalSince1970: 1_000)
        try context.save()
        return block
    }

    @Test("Start next fills in the preset and keeps the routine and its days")
    func startNextKeepsRoutine() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = try endedBlock(in: context)

        let draft = BlockDraft.next(after: block, template: BlockTemplates.generic)

        #expect(draft.name == "Generic Strength Meso")
        #expect(draft.phases.map(\.kind) == BlockTemplates.generic.phases.map(\.kind))
        #expect(draft.split?.id == block.split?.id)
        #expect(draft.schedulingMode == .fixedWeekly)
        #expect(draft.trainingDays == [2, 5])
        #expect(draft.missingPiece == nil, "The carried routine and days make it ready to save")
    }

    @Test("Plan custom keeps the routine, with the default phases and no name")
    func planCustomKeepsRoutine() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = try endedBlock(in: context)

        let draft = BlockDraft.next(after: block, template: nil)

        #expect(draft.name.isEmpty)
        #expect(draft.phases.map(\.weeks) == BlockDraft.newBlock().phases.map(\.weeks))
        #expect(draft.split?.id == block.split?.id)
        #expect(draft.trainingDays == [2, 5])
        #expect(draft.missingPiece == .name)
    }

    @Test("An archived routine is not carried over, nor its days")
    func archivedRoutineIsDropped() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = try endedBlock(in: context)
        block.split?.isArchived = true

        let draft = BlockDraft.next(after: block, template: BlockTemplates.generic)

        #expect(draft.split == nil)
        #expect(draft.schedulingMode == .rotation)
        #expect(draft.trainingDays.isEmpty)
    }

    @Test("A deleted routine leaves the draft without one")
    func deletedRoutineIsDropped() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = try endedBlock(in: context)
        block.split = nil

        let draft = BlockDraft.next(after: block, template: nil)

        #expect(draft.split == nil)
        #expect(draft.schedulingMode == .rotation)
    }
}
