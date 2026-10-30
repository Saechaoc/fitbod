//
//  LastWorkoutRepsAcrossLogsTests.swift
//  fitbodTests
//
//  Double progression decides its weight bump from the last finished
//  workout's working reps. A workout that logged the exercise more than
//  once counts once: its reps are read across all of its logs, in workout
//  order and then set order, and the walk back reads at most five
//  workouts. The previous top set settles a tie in weight inside one log
//  the way it settles one across logs: the earlier set wins.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("LastWorkoutRepsAcrossLogs", .serialized)
struct LastWorkoutRepsAcrossLogsTests {

    @Test("a workout that logs the exercise twice gives the working reps of both logs, in workout order", arguments: [false, true])
    func repsAcrossLogs(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(
            bench, daysAgo: 2, logs: [[(100, 10, true), (100, 10, true)], [(100, 8, true)]],
            insertedInReverse: insertedInReverse, in: ctx
        )

        #expect(lastReps(bench, in: ctx) == [10, 10, 8])
    }

    @Test("on a tie in weight inside one log, the earlier set's reps win", arguments: [false, true])
    func tieInOneLogGoesToEarlierSet(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(
            bench, daysAgo: 2, logs: [[(100, 8, true), (100, 6, true)]],
            insertedInReverse: insertedInReverse, in: ctx
        )

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: bench.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(hit?.weight == 100)
        #expect(hit?.reps == 8)
    }

    @Test("the walk back counts workouts, not logs")
    func walkBackCountsWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, daysAgo: 10, logs: [[(90, 5, true)]], in: ctx)
        // Four newer workouts, five logs: the fifth workout back is the 90 x 5.
        try workoutsWithoutWorkingSets(4, of: bench, in: ctx)

        #expect(lastReps(bench, in: ctx) == [5])
    }

    @Test("the walk back stops after five workouts")
    func walkBackStopsAfterFiveWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, daysAgo: 10, logs: [[(90, 5, true)]], in: ctx)
        // Five newer workouts: the 90 x 5 is the sixth workout back.
        try workoutsWithoutWorkingSets(5, of: bench, in: ctx)

        #expect(lastReps(bench, in: ctx).isEmpty)
    }

    // MARK: - Helpers

    /// One set as the workout logs it. An incomplete set is a planned set
    /// the user never logged.
    private typealias LoggedSet = (weight: Double, reps: Int, complete: Bool)

    private func lastReps(_ exercise: Exercise, in ctx: ModelContext) -> [Int] {
        SessionFactory.lastSessionWorkingReps(
            exerciseID: exercise.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
    }

    /// A finished strength workout started `daysAgo` days ago that logs
    /// `exercise` once per entry of `logs`, in that workout order. Each log
    /// and each set is saved on its own, every set with the same completion
    /// time; `insertedInReverse` inserts the last log first and each log's
    /// last set first, so the store's order differs from the workout's.
    @discardableResult
    private func finishedWorkout(
        _ exercise: Exercise,
        daysAgo: Int,
        logs: [[LoggedSet]],
        insertedInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = Date.now.addingTimeInterval(-Double(daysAgo) * 86_400)
        session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
        session.intentRaw = Intent.strength.rawValue
        try ctx.save()

        var orderedLogs = Array(logs.enumerated())
        if insertedInReverse { orderedLogs.reverse() }
        for (logIndex, sets) in orderedLogs {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = exercise
            se.exerciseNameSnapshot = exercise.name
            se.orderIndex = logIndex
            try ctx.save()

            var orderedSets = Array(sets.enumerated())
            if insertedInReverse { orderedSets.reverse() }
            for (setIndex, s) in orderedSets {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = se
                entry.orderIndex = setIndex
                entry.weight = s.weight
                entry.reps = s.reps
                entry.isComplete = s.complete
                entry.completedAt = session.startedAt
                try ctx.save()
            }
        }
        return session
    }

    /// `count` finished workouts, one a day back from yesterday, that log
    /// `exercise` with only planned sets the user never logged. The newest
    /// logs it twice, so they hold one more log than workouts.
    private func workoutsWithoutWorkingSets(_ count: Int, of exercise: Exercise, in ctx: ModelContext) throws {
        let unlogged: [LoggedSet] = [(100, 0, false), (100, 0, false)]
        for day in 1...count {
            try finishedWorkout(exercise, daysAgo: day, logs: day == 1 ? [unlogged, unlogged] : [unlogged], in: ctx)
        }
    }
}
