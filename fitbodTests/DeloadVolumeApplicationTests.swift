//
//  DeloadVolumeApplicationTests.swift
//  fitbodTests
//
//  Phase 4 coverage for scheduled deload working-set volume cuts.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("DeloadVolumeApplication", .serialized)
struct DeloadVolumeApplicationTests {
    private let day: TimeInterval = 86_400

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeBlock(
        in context: ModelContext,
        startDate: Date,
        phases: [(BlockPhaseKind, Int, Double, Double)]
    ) -> Block {
        let block = Block()
        block.name = "Deload Test"
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

    private func makeRoutine(
        in context: ModelContext,
        block: Block?,
        targetSets: [Int]
    ) -> SessionTemplate {
        let routine = SessionTemplate()
        routine.name = "Volume Test"
        routine.block = block
        // Phase 3.1 (PIVOT-01): progression lives on SessionTemplate.
        routine.progressionKindRaw = ProgressionKind.double.rawValue
        context.insert(routine)

        for (index, sets) in targetSets.enumerated() {
            let exercise = Exercise.previewSample(
                name: "Exercise \(index)",
                equipment: .machine,
                mechanic: .isolation
            )
            context.insert(exercise)

            let routineExercise = SessionExerciseTemplate()
            routineExercise.sessionTemplate = routine
            routineExercise.exercise = exercise
            routineExercise.orderIndex = index
            routineExercise.targetSets = sets
            routineExercise.targetRepsLow = 8
            routineExercise.targetRepsHigh = 10
            context.insert(routineExercise)
        }
        return routine
    }

    private func workingSetCounts(in session: Session) -> [Int] {
        (session.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { sessionExercise in
                (sessionExercise.sets ?? []).filter { !$0.isWarmup }.count
            }
    }

    /// The `isWarmup == false` filter excludes Phase 3 auto-generated warm-up SetEntries from the working-set count. D-12 / BLOCK-04 only halves the working set count; warm-up ramps are independently skipped by `WarmupRamp.deloadActive`.
    @Test("deload week halves working set count")
    func deloadWeekHalvesWorkingSetCount() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let deloadDate = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]
        )
        let routine = makeRoutine(in: context, block: block, targetSets: [4])
        try context.save()

        #expect(PeriodizationEngine.phase(for: block, on: deloadDate)?.kind == .deload)
        // Phase 8 (CR-01): pass activeBlock so deload phase resolution fires.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: deloadDate, context: context)

        #expect(workingSetCounts(in: session) == [2])
    }

    @Test("deload week clamps to one set when targetSets is one")
    func deloadWeekClampsToOneSetWhenTargetSetsIsOne() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let deloadDate = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]
        )
        let routine = makeRoutine(in: context, block: block, targetSets: [1])
        try context.save()

        // Phase 8 (CR-01): pass activeBlock so deload phase resolution fires.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: deloadDate, context: context)

        #expect(workingSetCounts(in: session) == [1])
    }

    @Test("accumulation week keeps target set count")
    func accumulationWeekKeepsTargetSetCount() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(in: context, startDate: start, phases: [(.accumulation, 4, 1.0, 0.75)])
        let routine = makeRoutine(in: context, block: block, targetSets: [3])
        try context.save()

        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: start, context: context)

        #expect(workingSetCounts(in: session) == [3])
    }

    @Test("intensification week keeps target set count")
    func intensificationWeekKeepsTargetSetCount() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let today = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.intensification, 1, 0.85, 0.88)]
        )
        let routine = makeRoutine(in: context, block: block, targetSets: [3])
        try context.save()

        #expect(PeriodizationEngine.phase(for: block, on: today)?.kind == .intensification)
        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: today, context: context)

        #expect(workingSetCounts(in: session) == [3])
    }

    @Test("realization week keeps target set count")
    func realizationWeekKeepsTargetSetCount() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let today = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.realization, 1, 0.6, 0.97)]
        )
        let routine = makeRoutine(in: context, block: block, targetSets: [3])
        try context.save()

        #expect(PeriodizationEngine.phase(for: block, on: today)?.kind == .realization)
        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: today, context: context)

        #expect(workingSetCounts(in: session) == [3])
    }

    @Test("no block keeps target set count")
    func noBlockKeepsTargetSetCount() throws {
        let context = try makeContext()
        let routine = makeRoutine(in: context, block: nil, targetSets: [4])
        try context.save()

        let session = try SessionFactory.start(template: routine, on: .now, context: context)

        #expect(workingSetCounts(in: session) == [4])
    }

    @Test("past end of block keeps target set count")
    func pastEndOfBlockKeepsTargetSetCount() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(in: context, startDate: start, phases: [(.deload, 1, 0.5, 0.75)])
        let end = try #require(block.endDate)
        let routine = makeRoutine(in: context, block: block, targetSets: [4])
        try context.save()

        #expect(PeriodizationEngine.phase(for: block, on: end.addingTimeInterval(day)) == nil)
        // Phase 8 (CR-01): pass activeBlock so prescription context is correct.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: end.addingTimeInterval(day), context: context)

        #expect(workingSetCounts(in: session) == [4])
    }

    @Test("multiple exercises in deload are all halved")
    func multipleExercisesInDeloadAllHalved() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let deloadDate = start.addingTimeInterval(8 * day)
        let block = makeBlock(
            in: context,
            startDate: start,
            phases: [(.accumulation, 1, 1.0, 0.75), (.deload, 1, 0.5, 0.75)]
        )
        let routine = makeRoutine(in: context, block: block, targetSets: [4, 5, 6])
        try context.save()

        // Phase 8 (CR-01): pass activeBlock so deload phase resolution fires.
        let session = try SessionFactory.start(template: routine, activeBlock: block, on: deloadDate, context: context)

        #expect(workingSetCounts(in: session) == [2, 2, 3])
    }
}
