//
//  SessionBlockSnapshotTests.swift
//  fitbodTests
//
//  Phase 4 coverage for the Session.block snapshot relationship.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionBlockSnapshot", .serialized)
struct SessionBlockSnapshotTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeBlock(in context: ModelContext, startDate: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Block {
        let block = Block()
        block.name = "Hypertrophy I"
        block.startDate = startDate
        block.endDate = startDate.addingTimeInterval(28 * 86_400)
        block.isActive = true
        context.insert(block)

        let phase = BlockPhase()
        phase.block = block
        phase.orderIndex = 0
        phase.nameRaw = BlockPhaseKind.accumulation.rawValue
        phase.weeks = 4
        phase.volumeMultiplier = 1.0
        phase.intensityMultiplier = 0.75
        context.insert(phase)
        block.phases = [phase]
        return block
    }

    private func makeRoutine(in context: ModelContext, block: Block?) -> SessionTemplate {
        let exercise = Exercise.previewSample(name: "Bench Press", equipment: .barbell, mechanic: .compound)
        context.insert(exercise)

        let routine = SessionTemplate()
        routine.name = "Push Day"
        routine.block = block
        // Phase 3.1 (PIVOT-01): progression lives on SessionTemplate.
        routine.progressionKindRaw = ProgressionKind.double.rawValue
        context.insert(routine)

        let routineExercise = SessionExerciseTemplate()
        routineExercise.sessionTemplate = routine
        routineExercise.exercise = exercise
        routineExercise.orderIndex = 0
        routineExercise.targetSets = 3
        routineExercise.targetRepsLow = 5
        routineExercise.targetRepsHigh = 5
        context.insert(routineExercise)
        return routine
    }

    private func fetchSession(_ id: UUID, context: ModelContext) throws -> Session {
        let targetID = id
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == targetID }
        )
        return try #require(try context.fetch(descriptor).first)
    }

    @Test("session block snapshots routine block")
    func sessionBlockSnapshotsRoutineBlock() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let routine = makeRoutine(in: context, block: block)
        try context.save()

        let session = try SessionFactory.start(template: routine, on: block.startDate, context: context)

        #expect(session.block?.id == block.id)
    }

    @Test("detaching routine block after start does not mutate session block")
    func detachingRoutineBlockAfterStartDoesNotMutateSessionBlock() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let routine = makeRoutine(in: context, block: block)
        try context.save()

        let session = try SessionFactory.start(template: routine, on: block.startDate, context: context)
        routine.block = nil
        try context.save()

        let fetched = try fetchSession(session.id, context: context)
        #expect(fetched.block?.id == block.id)
    }

    @Test("session block is nil when routine has no block")
    func sessionBlockIsNilWhenRoutineHasNoBlock() throws {
        let context = try makeContext()
        let routine = makeRoutine(in: context, block: nil)
        try context.save()

        let session = try SessionFactory.start(template: routine, on: .now, context: context)

        #expect(session.block == nil)
    }

    @Test("editing block name after snapshot propagates through reference")
    func editingBlockNameAfterSnapshotPropagatesViaReference() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let routine = makeRoutine(in: context, block: block)
        try context.save()

        let session = try SessionFactory.start(template: routine, on: block.startDate, context: context)
        block.name = "Renamed"
        try context.save()

        let fetched = try fetchSession(session.id, context: context)
        #expect(fetched.block?.name == "Renamed")
    }

    @Test("deleting block after snapshot nullifies session block")
    func deletingBlockAfterSnapshotNullifiesSessionBlock() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let routine = makeRoutine(in: context, block: block)
        try context.save()

        let session = try SessionFactory.start(template: routine, on: block.startDate, context: context)
        context.delete(block)
        try context.save()

        let fetched = try fetchSession(session.id, context: context)
        #expect(fetched.block == nil)
    }
}
