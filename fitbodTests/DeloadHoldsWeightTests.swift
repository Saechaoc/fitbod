//
//  DeloadHoldsWeightTests.swift
//  fitbodTests
//
//  The deload week holds each lift at its last top set (docs/ROADMAP.md,
//  "Decided" 2026-11-05). Double progression adds an increment after a
//  session at the top of its rep range, which in a deload week put more
//  weight under a banner that says "recover, don't load".
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Deload holds weight", .serialized)
struct DeloadHoldsWeightTests {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try FitbodModelContainer.make(inMemory: true))
    }

    /// An active block: one week of accumulation, then one week of deload
    /// at half the volume.
    private func makeBlock(in context: ModelContext) -> Block {
        let block = Block()
        block.name = "Deload Block"
        block.startDate = start
        block.isActive = true
        context.insert(block)
        block.phases = [(BlockPhaseKind.accumulation, 1.0), (.deload, 0.5)].enumerated().map { index, spec in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = spec.0.rawValue
            phase.weeks = 1
            phase.volumeMultiplier = spec.1
            phase.intensityMultiplier = 0.75
            context.insert(phase)
            return phase
        }
        return block
    }

    /// A machine lift, so no plates round the weight: 3 × 5–8 by double
    /// progression.
    private func makeTemplate(in context: ModelContext) -> (SessionTemplate, Exercise) {
        let exercise = Exercise.previewSample(name: "Leg Press", equipment: .machine, mechanic: .compound)
        context.insert(exercise)
        let template = SessionTemplate()
        template.name = "Legs"
        template.intentRaw = Intent.strength.rawValue
        template.progressionKindRaw = ProgressionKind.double.rawValue
        context.insert(template)
        let item = SessionExerciseTemplate()
        item.sessionTemplate = template
        item.exercise = exercise
        item.orderIndex = 0
        item.targetSets = 3
        item.targetRepsLow = 5
        item.targetRepsHigh = 8
        context.insert(item)
        return (template, exercise)
    }

    /// A finished workout the day before `date`: three sets of 100 × 8,
    /// the top of the range, which earns double progression's increment.
    private func logTopOfRange(_ exercise: Exercise, before date: Date, in context: ModelContext) throws {
        let session = Session()
        session.startedAt = date.addingTimeInterval(-day)
        session.completedAt = session.startedAt.addingTimeInterval(3_600)
        session.intentRaw = Intent.strength.rawValue
        context.insert(session)
        let sessionExercise = SessionExercise()
        sessionExercise.session = session
        sessionExercise.exercise = exercise
        context.insert(sessionExercise)
        for index in 0..<3 {
            let set = SetEntry()
            set.sessionExercise = sessionExercise
            set.orderIndex = index
            set.weight = 100
            set.reps = 8
            set.rpe = 8
            set.isWarmup = false
            set.setTypeRaw = SetType.working.rawValue
            set.isComplete = true
            set.completedAt = session.startedAt.addingTimeInterval(Double(index + 1) * 180)
            context.insert(set)
        }
        try context.save()
    }

    private func prescribedWeight(of session: Session) -> Double? {
        session.exercises?.first?.prescribedWeight
    }

    @Test("In a deload week the prescription holds the last top set")
    func deloadWeekHoldsLastTopSet() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let (template, exercise) = makeTemplate(in: context)
        let deloadDay = start.addingTimeInterval(8 * day)
        try logTopOfRange(exercise, before: deloadDay, in: context)
        #expect(PeriodizationEngine.phase(for: block, on: deloadDay)?.kind == .deload)

        let session = try SessionFactory.start(template: template, activeBlock: block, on: deloadDay, context: context)

        #expect(prescribedWeight(of: session) == 100, "The deload holds 100, not 102.5")
        let why = SessionFactory.prescription(
            for: exercise, targetRepsLow: 5, targetRepsHigh: 8, targetRPE: nil,
            in: session, strategy: DoubleProgressionStrategy(), userSettings: nil, context: context
        )
        #expect(why.weight == 100, "WHY recomputes the same held weight")
        #expect(why.explanation.computedLine?.hasPrefix("Deload week") == true, "WHY says the deload held it")
        #expect(why.explanation.bumpOccurred == false)
    }

    @Test("Outside the deload, double progression still adds its increment")
    func accumulationWeekStillBumps() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let (template, exercise) = makeTemplate(in: context)
        let accumulationDay = start.addingTimeInterval(2 * day)
        try logTopOfRange(exercise, before: accumulationDay, in: context)

        let session = try SessionFactory.start(template: template, activeBlock: block, on: accumulationDay, context: context)

        #expect(prescribedWeight(of: session) == 102.5)
    }

    @Test("A deload with no earlier set prescribes nothing to hold")
    func deloadWithoutHistoryKeepsZero() throws {
        let context = try makeContext()
        let block = makeBlock(in: context)
        let (template, _) = makeTemplate(in: context)

        let session = try SessionFactory.start(
            template: template, activeBlock: block, on: start.addingTimeInterval(8 * day), context: context
        )

        #expect(prescribedWeight(of: session) == 0)
    }
}
