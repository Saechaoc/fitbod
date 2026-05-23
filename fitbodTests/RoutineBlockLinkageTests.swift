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
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
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

    private func fetchRoutine(_ routineID: UUID, context: ModelContext) throws -> Routine {
        let targetID = routineID
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.id == targetID }
        )
        return try #require(try context.fetch(descriptor).first)
    }

    @Test("RoutineDraft blockID defaults nil")
    func routineDraftBlockIDDefaultsNil() {
        let draft = RoutineDraft()

        #expect(draft.blockID == nil)
    }

    @Test("RoutineDraft init from Routine populates blockID")
    func routineDraftInitFromRoutinePopulatesBlockID() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = Routine()
        routine.name = "Bench"
        routine.block = block
        context.insert(routine)
        try context.save()

        let draft = RoutineDraft(routine: routine)

        #expect(draft.blockID == block.id)
    }

    @Test("RoutineDraft save materializes Routine.block")
    func routineDraftSaveMaterializesRoutineBlock() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = Routine()
        context.insert(routine)

        let draft = makeValidDraft(blockID: block.id)
        draft.save(into: routine, context: context)
        try context.save()

        let fetched = try fetchRoutine(routine.id, context: context)
        #expect(fetched.block?.id == block.id)
    }

    @Test("RoutineDraft save with nil blockID nullifies Routine.block")
    func routineDraftSaveWithNilBlockIDNullifiesRoutineBlock() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Peak"
        context.insert(block)

        let routine = Routine()
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

    @Test("RoutineDraft save with unknown blockID leaves Routine.block nil")
    func routineDraftSaveWithUnknownBlockIDLeavesRoutineBlockNil() throws {
        let context = try makeContext()
        let routine = Routine()
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

        let routine = Routine()
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
}
