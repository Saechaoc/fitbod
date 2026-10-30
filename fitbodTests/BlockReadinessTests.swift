//
//  BlockReadinessTests.swift
//  fitbodTests
//
//  Ticket T11: the one readiness rule. A block is ready with a name, at
//  least one phase, and a routine with at least one session, whose
//  training days match its sessions under fixed weekly scheduling.
//  `Block.derivedStatus` and New Block's SAVE AS READY both call
//  `Block.firstMissingPiece`.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockReadiness", .serialized)
struct BlockReadinessTests {
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    @Test("Each missing piece is named first in order", arguments: SchedulingMode.allCases)
    func namesEachMissingPieceInOrder(mode: SchedulingMode) {
        // Every piece present unless an argument takes it away: a two-session routine on two days.
        func firstMissing(
            name: String = "Base", phases: Int = 1, sessions: Int? = 2, days: Int = 2
        ) -> BlockMissingPiece? {
            Block.firstMissingPiece(
                name: name, phaseCount: phases, sessionCount: sessions,
                schedulingMode: mode, trainingDayCount: days
            )
        }

        #expect(firstMissing(name: "", phases: 0, sessions: nil, days: 0) == .name)
        #expect(firstMissing(name: " \n ") == .name)
        #expect(firstMissing(phases: 0, sessions: nil) == .phase)
        #expect(firstMissing(sessions: nil) == .routine)
        #expect(firstMissing(sessions: 0, days: 0) == .session)
        // Rotation never asks for training days.
        let wrongDays: BlockMissingPiece? = mode == .fixedWeekly ? .trainingDays(2) : nil
        #expect(firstMissing(days: 0) == wrongDays)
        #expect(firstMissing(days: 3) == wrongDays)
        #expect(firstMissing() == nil)
    }

    @Test("A saved block's status follows its draft's missing piece", arguments: SchedulingMode.allCases)
    func savedBlockAgreesWithItsDraft(mode: SchedulingMode) throws {
        let context = try makeContext()
        let emptyRoutine = try makeRoutine(sessions: 0, in: context)
        let routine = try makeRoutine(sessions: 2, in: context)
        let drafts = [
            makeDraft(name: "", phases: 1, routine: routine, days: [2, 4]),
            makeDraft(name: "No phase", phases: 0, routine: routine, days: [2, 4]),
            makeDraft(name: "No routine", phases: 1, routine: nil, days: []),
            makeDraft(name: "Empty routine", phases: 1, routine: emptyRoutine, days: []),
            makeDraft(name: "One day", phases: 1, routine: routine, days: [2]),
            makeDraft(name: "Every piece", phases: 1, routine: routine, days: [4, 2]),
        ]

        for draft in drafts {
            draft.schedulingMode = mode
            let expected = draft.missingPiece
            try draft.save(into: context)
            let id = try #require(draft.id)
            let block = try #require(try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == id })).first)
            #expect(block.missingPiece == expected, "\(draft.name)")
            #expect(block.derivedStatus == (expected == nil ? .ready : .draft), "\(draft.name)")
        }
    }

    @Test("A block with a routine but no phase or no name is a draft and cannot start",
          arguments: [BlockMissingPiece.phase, .name])
    func routineAloneDoesNotMakeABlockReady(missing: BlockMissingPiece) throws {
        let context = try makeContext()
        let routine = try makeRoutine(sessions: 1, in: context)
        let block = Block()
        context.insert(block)
        block.name = missing == .name ? "" : "Routine only"
        block.split = routine
        if missing != .phase {
            let phase = BlockPhase()
            context.insert(phase)
            phase.block = block
            phase.nameRaw = BlockPhaseKind.accumulation.rawValue
            phase.weeks = 1
        }
        try context.save()

        #expect(block.missingPiece == missing)
        #expect(block.derivedStatus == .draft)
        #expect(throws: BlockLifecycleError.notReady) {
            try BlockLifecycleService.start(block: block, context: context)
        }
        #expect(block.isActive == false)
    }

    @Test("Completed and active keep their precedence over missing pieces")
    func completedAndActiveIgnoreMissingPieces() throws {
        let context = try makeContext()
        let active = Block()
        context.insert(active)
        active.isActive = true
        let completed = Block()
        context.insert(completed)
        completed.isActive = true
        completed.endDate = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(active.missingPiece == .name)
        #expect(active.derivedStatus == .active)
        #expect(completed.derivedStatus == .completed)
    }

    @Test("PICK N DAYS counts the routine's sessions")
    func pickDaysCountsSessions() {
        #expect(BlockMissingPiece.trainingDays(1).actionTitle == "PICK 1 DAY")
        #expect(BlockMissingPiece.trainingDays(3).actionTitle == "PICK 3 DAYS")
    }

    // MARK: - Fixtures

    /// A saved routine with `sessions` sessions, one template each.
    private func makeRoutine(sessions: Int, in context: ModelContext) throws -> Split {
        let split = Split()
        context.insert(split)
        split.name = "\(sessions)-session routine"
        for position in 0..<sessions {
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

    private func makeDraft(name: String, phases: Int, routine: Split?, days: [Int]) -> BlockDraft {
        let draft = BlockDraft()
        draft.name = name
        draft.phases = (0..<phases).map { _ in
            BlockPhaseDraft(kind: .accumulation, weeks: 1, volumeMultiplier: 1.2, intensityMultiplier: 0.70)
        }
        draft.split = routine
        draft.trainingDays = days
        return draft
    }
}
