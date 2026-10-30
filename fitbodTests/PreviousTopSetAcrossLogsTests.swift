//
//  PreviousTopSetAcrossLogsTests.swift
//  fitbodTests
//
//  The previous top set seeds a new workout's weights, fills the logger's
//  PREVIOUS column and feeds Why this weight. A finished workout that
//  logged the exercise more than once counts once: its top set is the
//  heaviest working set across all of its logs, the earlier log's set on
//  a tie in weight, and the walk back reads at most five workouts.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PreviousTopSetAcrossLogs", .serialized)
struct PreviousTopSetAcrossLogsTests {

    @Test("a workout that logs the exercise twice gives the heaviest working set of both logs", arguments: [false, true])
    func heaviestSetAcrossLogs(heavyLogSecond: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let heavy: [LoggedSet] = [(100, 5, true)]
        let light: [LoggedSet] = [(80, 8, true)]
        let workout = try finishedWorkout(
            bench, daysAgo: 2, logs: heavyLogSecond ? [light, heavy] : [heavy, light], in: ctx
        )

        let hit = previousTopSet(bench, in: ctx)
        #expect(hit?.weight == 100)
        #expect(hit?.reps == 5)
        #expect(hit?.sessionStartedAt == workout.startedAt)
    }

    @Test("on a tie in weight, the earlier log's set wins", arguments: [false, true])
    func tieGoesToEarlierLog(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(
            bench, daysAgo: 2, logs: [[(100, 5, true)], [(100, 3, true)]],
            insertedInReverse: insertedInReverse, in: ctx
        )

        let hit = previousTopSet(bench, in: ctx)
        #expect(hit?.weight == 100)
        #expect(hit?.reps == 5)
    }

    @Test("the walk back counts workouts, not logs")
    func walkBackCountsWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, daysAgo: 10, logs: [[(90, 5, true)]], in: ctx)
        // Four newer workouts, five logs: the fifth workout back is the 90 x 5.
        try workoutsWithoutWorkingSets(4, of: bench, in: ctx)

        #expect(previousTopSet(bench, in: ctx)?.weight == 90)
    }

    @Test("the walk back stops after five workouts")
    func walkBackStopsAfterFiveWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, daysAgo: 10, logs: [[(90, 5, true)]], in: ctx)
        // Five newer workouts: the 90 x 5 is the sixth workout back.
        try workoutsWithoutWorkingSets(5, of: bench, in: ctx)

        #expect(previousTopSet(bench, in: ctx) == nil)
    }

    // MARK: - Helpers

    /// One set as `LoggerFixtures.session` takes it. An incomplete set is a
    /// planned set the user never logged.
    private typealias LoggedSet = (weight: Double, reps: Int, complete: Bool)

    private func previousTopSet(_ exercise: Exercise, in ctx: ModelContext) -> PreviousMatchingIntentHit? {
        PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
    }

    /// A finished strength workout started `daysAgo` days ago that logs
    /// `exercise` once per entry of `logs`, in that workout order. Each log
    /// is saved on its own; `insertedInReverse` inserts the last log first,
    /// so the store's order differs from the workout's.
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

        var ordered = Array(logs.enumerated())
        if insertedInReverse { ordered.reverse() }
        for (orderIndex, sets) in ordered {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = exercise
            se.exerciseNameSnapshot = exercise.name
            se.orderIndex = orderIndex
            for (i, s) in sets.enumerated() {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = se
                entry.orderIndex = i
                entry.weight = s.weight
                entry.reps = s.reps
                entry.isComplete = s.complete
                entry.completedAt = session.startedAt
            }
            try ctx.save()
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
