//
//  RoutineBlockLinkageTests.swift
//  fitbodTests
//
//  Phase 4 coverage for RoutineDraft.blockID materialization.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineBlockLinkage", .serialized)
struct RoutineBlockLinkageTests {
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeExercise() -> Exercise {
        Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
    }

    private func makeValidDraft(blockID: UUID? = nil) -> RoutineDraft {
        let draft = RoutineDraft()
        draft.name = "Push Day"
        draft.blockID = blockID
        draft.append(exercise: makeExercise())
        return draft
    }

    private func fetchRoutine(_ routineID: UUID, context: ModelContext) throws -> SessionTemplate {
        let targetID = routineID
        let descriptor = FetchDescriptor<SessionTemplate>(
            predicate: #Predicate<SessionTemplate> { $0.id == targetID }
        )
        return try #require(try context.fetch(descriptor).first)
    }

    @Test("RoutineDraft blockID defaults nil")
    func routineDraftBlockIDDefaultsNil() {
        let draft = RoutineDraft()

        #expect(draft.blockID == nil)
    }

    @Test("RoutineDraft init from SessionTemplate populates blockID")
    func routineDraftInitFromRoutinePopulatesBlockID() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = SessionTemplate()
        routine.name = "Bench"
        routine.block = block
        context.insert(routine)
        try context.save()

        let draft = RoutineDraft(routine: routine)

        #expect(draft.blockID == block.id)
    }

    @Test("RoutineDraft save materializes SessionTemplate.block")
    func routineDraftSaveMaterializesRoutineBlock() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = SessionTemplate()
        context.insert(routine)

        let draft = makeValidDraft(blockID: block.id)
        draft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.block?.id == block.id)
    }

    @Test("RoutineDraft save with nil blockID nullifies SessionTemplate.block")
    func routineDraftSaveWithNilBlockIDNullifiesRoutineBlock() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = SessionTemplate()
        routine.name = "Bench"
        routine.block = block
        context.insert(routine)
        try context.save()

        let draft = RoutineDraft(routine: routine)
        draft.blockID = nil
        draft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.block == nil)
    }

    @Test("RoutineDraft save with unknown blockID leaves SessionTemplate.block nil")
    func routineDraftSaveWithUnknownBlockIDLeavesRoutineBlockNil() throws {
        let context = try makeContext()
        let routine = SessionTemplate()
        context.insert(routine)

        let draft = makeValidDraft(blockID: UUID())
        draft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.block == nil)
    }

    @Test("RoutineDraft round trip preserves block linkage across saves")
    func routineDraftRoundTripPreservesBlockLinkageAcrossSaves() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = SessionTemplate()
        context.insert(routine)

        let firstDraft = makeValidDraft(blockID: block.id)
        firstDraft.save(into: routine, context: context)
        try context.save()

        let secondDraft = RoutineDraft(routine: routine)
        secondDraft.name = "Bench Day"
        secondDraft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.name == "Bench Day")
        #expect(fetched.block?.id == block.id)
    }

    @Test("SessionTemplate linked to block can save block-required progression")
    func routineLinkedToBlockCanSaveBlockRequiredProgression() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        for kind in [ProgressionKind.block, .hybrid] {
            let routine = SessionTemplate()
            context.insert(routine)

            let draft = makeValidDraft(blockID: block.id)
            draft.progressionKind = kind
            draft.save(into: routine, context: context)
            try context.save()

            let fetched = try fetchRoutine(routine.id, context: context)
            #expect(fetched.block?.id == block.id)
            #expect(fetched.progressionKind == kind)
        }
    }

    @Test("SessionTemplate without block falls back from block-required progression")
    func routineWithoutBlockFallsBackFromBlockRequiredProgression() throws {
        let context = try makeContext()

        for kind in [ProgressionKind.block, .hybrid] {
            let routine = SessionTemplate()
            context.insert(routine)

            let draft = makeValidDraft(blockID: nil)
            draft.progressionKind = kind
            draft.save(into: routine, context: context)
            try context.save()

            let fetched = try fetchRoutine(routine.id, context: context)
            #expect(fetched.block == nil)
            #expect(fetched.progressionKind == .double)
            #expect(draft.progressionKind == .double)
        }
    }

    @Test("SessionTemplate with unresolved block falls back from block-required progression")
    func routineWithUnresolvedBlockFallsBackFromBlockRequiredProgression() throws {
        let context = try makeContext()
        let routine = SessionTemplate()
        context.insert(routine)

        let draft = makeValidDraft(blockID: UUID())
        draft.progressionKind = .hybrid
        draft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.block == nil)
        #expect(fetched.progressionKind == .double)
        #expect(draft.progressionKind == .double)
    }
}
