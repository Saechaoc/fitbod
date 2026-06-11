//
//  WarmupDeloadIntegrationTests.swift
//  fitbodTests
//
//  Phase 4 coverage for passing scheduled deload context into WarmupRamp.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WarmupDeloadIntegration", .serialized)
struct WarmupDeloadIntegrationTests {
    private let day: TimeInterval = 86_400

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

    @discardableResult
    private func seedBarbellInventory(in context: ModelContext) throws -> PlateInventory {
        let inventory = PlateInventory()
        inventory.equipmentKind = .barbell
        inventory.barWeight = 20
        inventory.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)
        context.insert(inventory)
        try context.save()
        return inventory
    }

    private func makeBlock(
        in context: ModelContext,
        startDate: Date,
        phases: [(BlockPhaseKind, Int, Double, Double)]
    ) -> Block {
        let block = Block()
        block.name = "Warmup Block"
        block.startDate = startDate
        block.endDate = startDate.addingTimeInterval(Double(phases.reduce(0) { $0 + $1.1 } * 7) * day)
        block.isActive = true
        context.insert(block)
        block.phases = phases.enumerated().map { index, spec in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = spec.0.rawValue
            phase.weeks = spec.1
            phase.volumeMultiplier = spec.2
            phase.intensityMultiplier = spec.3
            context.insert(phase)
            return phase
        }
        return block
    }

    private func makeRoutineWithCompoundExercise(in context: ModelContext, block: Block?) -> (SessionTemplate, Exercise) {
        let exercise = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        context.insert(exercise)

        let routine = SessionTemplate()
        routine.name = "Push Day"
        routine.block = block
        // Phase 3.1 (PIVOT-01): intent + progression live on SessionTemplate.
        routine.intentRaw = Intent.strength.rawValue
        routine.progressionKindRaw = ProgressionKind.double.rawValue
        context.insert(routine)

        let routineExercise = SessionExerciseTemplate()
        routineExercise.sessionTemplate = routine
        routineExercise.exercise = exercise
        routineExercise.orderIndex = 0
        routineExercise.targetSets = 4
        routineExercise.targetRepsLow = 5
        routineExercise.targetRepsHigh = 5
        context.insert(routineExercise)

        return (routine, exercise)
    }

    private func seedPriorCompletedSession(
        in context: ModelContext,
        exercise: Exercise,
        date: Date
    ) throws {
        let session = Session()
        session.startedAt = date
        session.completedAt = date.addingTimeInterval(3_600)
        session.routineSnapshotName = "Prior"
        // Phase 3.1 (PIVOT-02): intent + progression live on Session.
        session.intentRaw = Intent.strength.rawValue
        context.insert(session)

        let sessionExercise = SessionExercise()
        sessionExercise.session = session
        sessionExercise.exercise = exercise
        context.insert(sessionExercise)

        let entry = SetEntry()
        entry.sessionExercise = sessionExercise
        entry.orderIndex = 0
        entry.weight = 100
        entry.reps = 5
        entry.rpe = 8
        entry.isWarmup = false
        entry.setTypeRaw = SetType.working.rawValue
        entry.isComplete = true
        entry.completedAt = date.addingTimeInterval(1_800)
        context.insert(entry)

        try context.save()
    }

    private func warmupCount(in session: Session) -> Int {
        let sessionExercise = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }.first
        return (sessionExercise?.sets ?? []).filter { $0.isWarmup }.count
    }

    @Test("warmup generation skipped on deload week")
    func warmupGenerationSkippedOnDeloadWeek() throws {
        let context = try makeContext()
        try seedBarbellInventory(in: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let deloadDate = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]
        )
        let (routine, exercise) = makeRoutineWithCompoundExercise(in: context, block: block)
        try seedPriorCompletedSession(in: context, exercise: exercise, date: start.addingTimeInterval(-7 * day))

        #expect(PeriodizationEngine.phase(for: block, on: deloadDate)?.kind == .deload)
        // Phase 8 (CR-01): pass activeBlock so deload phase resolves and warmups are skipped.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: deloadDate, context: context)

        #expect(warmupCount(in: session) == 0)
    }

    @Test("warmup generation active on accumulation week")
    func warmupGenerationActiveOnAccumulationWeek() throws {
        let context = try makeContext()
        try seedBarbellInventory(in: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]
        )
        let (routine, exercise) = makeRoutineWithCompoundExercise(in: context, block: block)
        try seedPriorCompletedSession(in: context, exercise: exercise, date: start.addingTimeInterval(-7 * day))

        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: start, context: context)

        #expect(warmupCount(in: session) >= 3)
    }

    @Test("warmup generation active on intensification week")
    func warmupGenerationActiveOnIntensificationWeek() throws {
        let context = try makeContext()
        try seedBarbellInventory(in: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let today = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.intensification, 1, 0.85, 0.88)]
        )
        let (routine, exercise) = makeRoutineWithCompoundExercise(in: context, block: block)
        try seedPriorCompletedSession(in: context, exercise: exercise, date: start.addingTimeInterval(-7 * day))

        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: today, context: context)

        #expect(warmupCount(in: session) >= 3)
    }

    @Test("warmup generation active when routine has no block")
    func warmupGenerationActiveWhenRoutineHasNoBlock() throws {
        let context = try makeContext()
        try seedBarbellInventory(in: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let (routine, exercise) = makeRoutineWithCompoundExercise(in: context, block: nil)
        try seedPriorCompletedSession(in: context, exercise: exercise, date: start.addingTimeInterval(-7 * day))

        let session = try SessionFactory.start(template: routine, on: start, context: context)

        #expect(warmupCount(in: session) >= 3)
    }

    @Test("warmup generation active on past end of block")
    func warmupGenerationActiveOnPastEndOfBlock() throws {
        let context = try makeContext()
        try seedBarbellInventory(in: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(in: context, startDate: start, phases: [(.deload, 1, 0.5, 0.75)])
        let endDate = try #require(block.endDate)
        let today = endDate.addingTimeInterval(day)
        let (routine, exercise) = makeRoutineWithCompoundExercise(in: context, block: block)
        try seedPriorCompletedSession(in: context, exercise: exercise, date: start.addingTimeInterval(-7 * day))

        #expect(PeriodizationEngine.phase(for: block, on: today) == nil)
        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: today, context: context)

        #expect(warmupCount(in: session) >= 3)
    }
}
