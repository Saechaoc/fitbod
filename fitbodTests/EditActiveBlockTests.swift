//
//  EditActiveBlockTests.swift
//  fitbodTests
//
//  Ticket T65: saving an edit keeps the block's active state. Every builder
//  save (SAVE DRAFT, SAVE AS READY, SAVE CHANGES) is `BlockDraft.save(into:)`,
//  and it never starts, ends or deactivates a block; only
//  `BlockLifecycleService` does.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("EditActiveBlock", .serialized)
struct EditActiveBlockTests {
    private let earlier = Date(timeIntervalSince1970: 1_780_000_000)
    private let later = Date(timeIntervalSince1970: 1_781_000_000)

    @Test("SAVE CHANGES on the active block keeps it active, with no end date")
    func savingAnEditKeepsTheActiveBlockActive() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let routine = try makeRoutine(in: context)
        let finished = try makeReadyBlock("Last Block", routine: routine, in: context)
        try makeReadyBlock("Next Block", routine: routine, in: context)
        let current = try makeReadyBlock("Strength", routine: routine, in: context)
        try BlockLifecycleService.start(block: finished, context: context, now: earlier)
        try BlockLifecycleService.start(block: current, context: context, now: later)
        let others = try states(except: current.id, in: context)

        let draft = BlockDraft(block: current)
        draft.name = "Strength II"
        #expect(draft.isValid, "SAVE CHANGES needs a name and a phase")
        try draft.save(into: context)

        let saved = try #require(try fetchBlock(current.id, in: ModelContext(container)))
        #expect(saved.name == "Strength II")
        #expect(saved.isActive, "SAVE CHANGES must not deactivate the active block")
        #expect(saved.endDate == nil)
        #expect(saved.derivedStatus == .active)
        #expect(try states(except: current.id, in: context) == others, "No other block may change")
    }

    @Test("SAVE AS READY saves a new block ready, not active")
    func savingANewBlockNeverStartsIt() throws {
        let context = try makeContext()
        let routine = try makeRoutine(in: context)
        let current = try makeReadyBlock("Strength", routine: routine, in: context)
        try BlockLifecycleService.start(block: current, context: context, now: earlier)

        let draft = BlockDraft.newBlock()
        draft.name = "Next Block"
        draft.split = routine
        #expect(draft.missingPiece == nil, "SAVE AS READY needs every piece of a ready block")
        try draft.save(into: context)

        let id = try #require(draft.id)
        let saved = try #require(try fetchBlock(id, in: context))
        #expect(!saved.isActive, "Only BlockLifecycleService.start starts a block")
        #expect(saved.derivedStatus == .ready)
        #expect(try activeIDs(in: context) == [current.id])
        #expect(current.endDate == nil)
    }

    @Test("SAVE CHANGES on an inactive block keeps it inactive and the active block active")
    func savingAnEditKeepsAnInactiveBlockInactive() throws {
        let context = try makeContext()
        let routine = try makeRoutine(in: context)
        let current = try makeReadyBlock("Strength", routine: routine, in: context)
        let next = try makeReadyBlock("Next Block", routine: routine, in: context)
        try BlockLifecycleService.start(block: current, context: context, now: earlier)
        let others = try states(except: next.id, in: context)

        let draft = BlockDraft(block: next)
        draft.name = "Next Block II"
        try draft.save(into: context)

        #expect(next.name == "Next Block II")
        #expect(!next.isActive)
        #expect(next.derivedStatus == .ready)
        #expect(try states(except: next.id, in: context) == others, "No other block may change")
    }

    @Test("An edit opened before its block ended cannot restart it")
    func staleEditCannotRestartAnEndedBlock() throws {
        let context = try makeContext()
        let routine = try makeRoutine(in: context)
        let first = try makeReadyBlock("Strength", routine: routine, in: context)
        let second = try makeReadyBlock("Next Block", routine: routine, in: context)
        try BlockLifecycleService.start(block: first, context: context, now: earlier)
        let draft = BlockDraft(block: first)

        // Starting the second block ends the first while its edit is open.
        try BlockLifecycleService.start(block: second, context: context, now: later)
        draft.name = "Strength II"
        try draft.save(into: context)

        #expect(first.derivedStatus == .completed)
        #expect(first.endDate == later)
        #expect(try activeIDs(in: context) == [second.id])
    }

    // MARK: - Fixtures

    /// Everything a save could change on a block it does not edit.
    private struct BlockState: Equatable {
        let name: String
        let isActive: Bool
        let startDate: Date
        let endDate: Date?
        let archivedConfigJSON: String?
        let splitID: UUID?
        let phaseCount: Int

        init(_ block: Block) {
            name = block.name
            isActive = block.isActive
            startDate = block.startDate
            endDate = block.endDate
            archivedConfigJSON = block.archivedConfigJSON
            splitID = block.split?.id
            phaseCount = block.phases?.count ?? 0
        }
    }

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeRoutine(in context: ModelContext) throws -> Split {
        let split = Split()
        context.insert(split)
        split.name = "Upper / Lower"
        for position in 0..<2 {
            let template = SessionTemplate()
            context.insert(template)
            template.name = "Day \(position + 1)"
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.position = position
            slot.split = split
            slot.sessionTemplate = template
        }
        try context.save()
        return split
    }

    @discardableResult
    private func makeReadyBlock(_ name: String, routine: Split, in context: ModelContext) throws -> Block {
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
        #expect(block.derivedStatus == .ready, "\(name) must start out ready")
        return block
    }

    private func fetchBlock(_ id: UUID, in context: ModelContext) throws -> Block? {
        try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == id })).first
    }

    private func activeIDs(in context: ModelContext) throws -> [UUID] {
        try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true })).map(\.id)
    }

    private func states(except id: UUID, in context: ModelContext) throws -> [UUID: BlockState] {
        let blocks = try context.fetch(FetchDescriptor<Block>()).filter { $0.id != id }
        return Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, BlockState($0)) })
    }
}
