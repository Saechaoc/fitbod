//
//  WhyUsesFinishedWorkoutsTests.swift
//  fitbodTests
//
//  The WHY explanation reads its history from finished workouts only.
//  Logging a set in the workout in progress must not change the
//  last-session reps, the e1RM history, or the bump decision behind the
//  suggested weight.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WhyUsesFinishedWorkouts", .serialized)
struct WhyUsesFinishedWorkoutsTests {

    private let day: TimeInterval = 24 * 3600

    @Test("last-session reps come from the finished workout, not the one in progress")
    func lastSessionRepsSkipInProgress() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let lastWeek = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                   sets: [(100, 12, true), (100, 12, true), (100, 12, true)], in: ctx)
        try LoggerFixtures.session(exercise: ex, startedAt: .now, completedAt: nil,
                                   sets: [(100, 8, true), (100, 0, false), (100, 0, false)], in: ctx)

        let reps = SessionFactory.lastSessionWorkingReps(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(reps == [12, 12, 12])
    }

    @Test("e1RM history leaves out sets logged in the workout in progress")
    func historyPointsSkipInProgress() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let lastWeek = Date.now.addingTimeInterval(-7 * day)
        let finished = try LoggerFixtures.session(exercise: ex, startedAt: lastWeek,
                                                  completedAt: lastWeek.addingTimeInterval(3600),
                                                  sets: [(100, 5, true), (100, 5, true), (100, 5, true)], in: ctx)
        let current = try LoggerFixtures.session(exercise: ex, startedAt: .now, completedAt: nil,
                                                 sets: [(110, 5, true)], in: ctx)
        try logRPE(8, on: [finished, current], in: ctx)

        let points = SessionFactory.fetchHistoryPoints(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(points.count == 3)
        #expect(points.allSatisfy { $0.date == lastWeek })
    }

    @Test("e1RM history is the 50 newest sets, newest first")
    func historyPointsAreNewestFifty() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let starts = [21.0, 14.0, 7.0].map { Date.now.addingTimeInterval(-$0 * day) }
        var sessions: [Session] = []
        for start in starts {
            sessions.append(try LoggerFixtures.session(
                exercise: ex, startedAt: start, completedAt: start.addingTimeInterval(3600),
                sets: Array(repeating: (weight: 100.0, reps: 5, complete: true), count: 20), in: ctx
            ))
        }
        try logRPE(8, on: sessions, in: ctx)

        let points = SessionFactory.fetchHistoryPoints(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        let expectedDates = Array(repeating: starts[2], count: 20)
            + Array(repeating: starts[1], count: 20)
            + Array(repeating: starts[0], count: 10)
        #expect(points.map(\.date) == expectedDates)
    }

    @Test("a set logged mid-workout keeps the bump the workout was built with")
    func bumpHoldsMidWorkout() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        ex.smallestIncrement = 2.5
        let template = try LoggerFixtures.template("Push A", exercises: [ex], repsLow: 8, repsHigh: 12, in: ctx)
        let lastWeek = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                   sets: [(100, 12, true), (100, 12, true), (100, 12, true)], in: ctx)

        // Every set hit the top of 8-12, so the new workout bumps 100 to 102.5.
        let workout = try SessionFactory.start(template: template, context: ctx)
        let se = try #require(workout.exercises?.first)
        #expect(se.prescribedWeight == 102.5)
        #expect(explanation(for: se, in: ctx).bumpOccurred)

        // The first working set misses the top of the range.
        let firstSet = try #require((se.sets ?? []).filter { !$0.isWarmup }.min { $0.orderIndex < $1.orderIndex })
        firstSet.weight = 102.5
        firstSet.reps = 8
        firstSet.isComplete = true
        try ctx.save()

        let midWorkout = explanation(for: se, in: ctx)
        #expect(midWorkout.bumpOccurred)
        #expect(midWorkout.roundedWeight == 102.5)
    }

    // MARK: - Helpers

    private func logRPE(_ rpe: Double, on sessions: [Session], in ctx: ModelContext) throws {
        for session in sessions {
            for se in session.exercises ?? [] {
                for entry in se.sets ?? [] { entry.rpe = rpe }
            }
        }
        try ctx.save()
    }

    /// Double progression fed the explanation's three history inputs, read
    /// the way the exercise card reads them during a workout.
    private func explanation(for se: SessionExercise, in ctx: ModelContext) -> PrescriptionExplanation {
        let exerciseID = se.exercise?.id
        let intentRaw = se.session?.intentRaw ?? Intent.strength.rawValue
        let inventory = SessionFactory.plateInventory(for: .barbell, context: ctx)
        let lastReps = SessionFactory.lastSessionWorkingReps(
            exerciseID: exerciseID, intentRaw: intentRaw, context: ctx
        )
        let lastHint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exerciseID, intentRaw: intentRaw, context: ctx,
            excludingSessionID: se.session?.id
        )
        let (_, explanation) = DoubleProgressionStrategy().prescribe(
            history: SessionFactory.fetchHistoryPoints(exerciseID: exerciseID, intentRaw: intentRaw, context: ctx),
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            lastSessionRepsArray: lastReps.isEmpty ? nil : lastReps,
            smallestIncrement: 2.5,
            plates: inventory.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) },
            barWeight: inventory.barWeight,
            unit: .default,
            minCalibrationSets: 10,
            lastSessionWeight: lastHint?.weight,
            lastSessionReps: lastHint?.reps,
            lastSessionRPE: lastHint?.rpe,
            lastSessionDate: lastHint?.sessionStartedAt
        )
        return explanation
    }
}
