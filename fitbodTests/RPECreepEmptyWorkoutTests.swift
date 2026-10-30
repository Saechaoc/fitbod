//
//  RPECreepEmptyWorkoutTests.swift
//  fitbodTests
//
//  The RPE-creep check reads the same finished workouts as the stall check.
//  A finished workout that holds the exercise but has no top set, because
//  no working set was logged or no logged set has an e1RM, must not take a
//  place in the creep window and hide real creep.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

/// Logged working sets the e1RM formula leaves out.
struct SetsWithoutE1RM: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let weight: Double
    let reps: Int

    static let all: [SetsWithoutE1RM] = [
        SetsWithoutE1RM(testDescription: "all over 10 reps", weight: 80, reps: 12),
        SetsWithoutE1RM(testDescription: "all at 0 kg", weight: 0, reps: 5),
    ]
}

@MainActor
@Suite("RPECreepEmptyWorkout", .serialized)
struct RPECreepEmptyWorkoutTests {

    private let lastWeek = Date.now.addingTimeInterval(-7 * 24 * 3600)

    @Test("a finished workout with no logged working set does not hide RPE creep")
    func workoutWithNoLoggedSetKeepsCreep() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        let nextStart = try insertCreepingStall(ex, in: ctx)
        let finishedOnly = cardRead(ex, settings: settings, in: ctx)
        #expect(finishedOnly.action == .dropIntensity)

        // The next workout holds the exercise, but its sets were never logged.
        try insertFinishedWorkout(ex, startedAt: nextStart, weight: 100, reps: 0, rpe: nil, logged: false, in: ctx)
        #expect(cardRead(ex, settings: settings, in: ctx) == finishedOnly)
    }

    @Test("a finished workout whose logged sets have no e1RM does not hide RPE creep", arguments: SetsWithoutE1RM.all)
    func workoutWithoutE1RMKeepsCreep(sets: SetsWithoutE1RM) throws {
        let (ctx, ex, settings) = try benchWithSettings()
        let nextStart = try insertCreepingStall(ex, in: ctx)
        let finishedOnly = cardRead(ex, settings: settings, in: ctx)
        #expect(finishedOnly.action == .dropIntensity)

        try insertFinishedWorkout(ex, startedAt: nextStart, weight: sets.weight, reps: sets.reps, rpe: 8, logged: true, in: ctx)
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

    /// Five finished workouts stalled at 100 x 5. The last four make the
    /// 4-workout window and climb RPE 7, 8, 8.5, 9: a creep of 1.25. The
    /// oldest, at RPE 9, sits just outside it; reading it would flatten
    /// the creep. Returns the start of the next workout.
    private func insertCreepingStall(_ exercise: Exercise, in ctx: ModelContext) throws -> Date {
        try FatigueTestFixtures.weeklySessions(
            forExercise: exercise, weights: [100, 100, 100, 100, 100], reps: [5, 5, 5, 5, 5],
            rpe: [9, 7, 8, 8.5, 9], weekStart: lastWeek, in: ctx
        )
        return lastWeek.addingTimeInterval(5 * 86_400)
    }

    /// A finished workout that holds the exercise with three working sets
    /// of `weight` x `reps`, either logged or left pending the way
    /// SessionFactory.start seeds them.
    private func insertFinishedWorkout(
        _ exercise: Exercise,
        startedAt: Date,
        weight: Double,
        reps: Int,
        rpe: Double?,
        logged: Bool,
        in ctx: ModelContext
    ) throws {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(45 * 60)
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
            entry.reps = reps
            entry.rpe = rpe
            entry.setTypeRaw = SetType.working.rawValue
            entry.isWarmup = false
            entry.isComplete = logged
            entry.completedAt = startedAt
        }
        try ctx.save()
    }

    /// Read the way SessionExerciseCard.evaluatePlateau() reads.
    private func cardRead(_ exercise: Exercise, settings: UserSettings, in ctx: ModelContext) -> CardRead {
        let signal = PlateauDetector.evaluate(exerciseID: exercise.id, intent: .strength, in: ctx, settings: settings)
        guard case .stalled = signal else { return CardRead(signal: signal, action: nil) }
        let action = PlateauDetector.suggestedAction(exerciseID: exercise.id, intent: .strength, in: ctx, settings: settings)
        return CardRead(signal: signal, action: action)
    }
}
