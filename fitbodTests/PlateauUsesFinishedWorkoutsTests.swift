//
//  PlateauUsesFinishedWorkoutsTests.swift
//  fitbodTests
//
//  The plateau check reads finished workouts only. Starting a workout or
//  logging a set in it must not change the stall signal or the suggested
//  action the exercise card shows during that workout.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PlateauUsesFinishedWorkouts", .serialized)
struct PlateauUsesFinishedWorkoutsTests {

    private let lastWeek = Date.now.addingTimeInterval(-7 * 24 * 3600)

    @Test("a light first set in the workout in progress does not complete a stall")
    func lightSetInProgressDoesNotStall() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // 95 then 100 x 5 three times: across the 4-workout window, still progress.
        try FatigueTestFixtures.weeklySessions(
            forExercise: ex, weights: [95, 100, 100, 100], reps: [5, 5, 5, 5],
            weekStart: lastWeek, in: ctx
        )
        let se = try startWorkout(ex, in: ctx)
        let progress = PlateauSignal.progressing(e1RMs: [112.5, 112.5, 112.5, 106.875])
        #expect(PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings) == progress)

        // Today's first working set repeats 100 x 5, no heavier than the last three.
        try logFirstSet(of: se, reps: 5, in: ctx)
        #expect(PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings) == progress)
    }

    @Test("a hard first set in the workout in progress does not count as RPE creep")
    func hardSetInProgressIsNotCreep() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // Four stalled workouts at 100 x 5; RPE 7.5, 7.5, 8, 8 creeps by 0.5, under the 1.0 trigger.
        try FatigueTestFixtures.weeklySessions(
            forExercise: ex, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5],
            rpe: [7.5, 7.5, 8, 8], weekStart: lastWeek, in: ctx
        )
        let se = try startWorkout(ex, in: ctx)
        let atStart = cardRead(ex, settings: settings, in: ctx)
        #expect(atStart == CardRead(signal: .stalled(e1RMs: [112.5, 112.5, 112.5, 112.5], rangeRatio: 0),
                                    action: .tryVariation))

        // Today's first working set grinds out at RPE 10.
        try logFirstSet(of: se, reps: 5, rpe: 10, in: ctx)
        #expect(cardRead(ex, settings: settings, in: ctx) == atStart)
    }

    @Test("a workout in progress with nothing logged does not hide RPE creep")
    func emptyWorkoutInProgressKeepsCreep() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // Four stalled workouts at 100 x 5 while RPE climbs 7, 8, 8.5, 9: creep 1.25.
        try FatigueTestFixtures.weeklySessions(
            forExercise: ex, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5],
            rpe: [7, 8, 8.5, 9], weekStart: lastWeek, in: ctx
        )
        let finishedOnly = cardRead(ex, settings: settings, in: ctx)
        #expect(finishedOnly.action == .dropIntensity)

        try startWorkout(ex, in: ctx)
        #expect(cardRead(ex, settings: settings, in: ctx) == finishedOnly)
    }

    // MARK: - Helpers

    /// What the exercise card shows: the stall signal, and the suggested
    /// action only when stalled.
    private struct CardRead: Equatable {
        let signal: PlateauSignal
        let action: SuggestedAction?
    }

    /// An exercise with no muscle targets, so the volume branch never fires
    /// and the RPE-creep check alone decides between .dropIntensity and the
    /// .tryVariation default.
    private func benchWithSettings() throws -> (ModelContext, Exercise, UserSettings) {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ctx.insert(ex)
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()
        return (ctx, ex, settings)
    }

    /// A workout in progress started now, with three working sets pending
    /// the way SessionFactory.start seeds them.
    @discardableResult
    private func startWorkout(_ exercise: Exercise, weight: Double = 100, in ctx: ModelContext) throws -> SessionExercise {
        let session = Session()
        ctx.insert(session)
        session.startedAt = .now
        session.routineSnapshotName = "Test"
        session.intentRaw = Intent.strength.rawValue

        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = exercise
        se.targetSets = 3
        se.orderIndex = 0

        for index in 0..<3 {
            let entry = SetEntry()
            ctx.insert(entry)
            entry.sessionExercise = se
            entry.orderIndex = index
            entry.weight = weight
            entry.reps = 0
            entry.setTypeRaw = SetType.working.rawValue
            entry.isWarmup = false
            entry.isComplete = false
        }
        try ctx.save()
        return se
    }

    private func logFirstSet(of se: SessionExercise, reps: Int, rpe: Double? = nil, in ctx: ModelContext) throws {
        let first = try #require((se.sets ?? []).min { $0.orderIndex < $1.orderIndex })
        first.reps = reps
        first.rpe = rpe
        first.isComplete = true
        first.completedAt = .now
        try ctx.save()
    }

    /// Read the way SessionExerciseCard.evaluatePlateau() reads during a workout.
    private func cardRead(_ exercise: Exercise, settings: UserSettings, in ctx: ModelContext) -> CardRead {
        let signal = PlateauDetector.evaluate(exerciseID: exercise.id, intent: .strength, in: ctx, settings: settings)
        guard case .stalled = signal else { return CardRead(signal: signal, action: nil) }
        let action = PlateauDetector.suggestedAction(exerciseID: exercise.id, intent: .strength, in: ctx, settings: settings)
        return CardRead(signal: signal, action: action)
    }
}
