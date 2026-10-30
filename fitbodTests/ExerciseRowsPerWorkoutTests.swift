//
//  ExerciseRowsPerWorkoutTests.swift
//  fitbodTests
//
//  An exercise's history list and its detail screen's "Recent
//  performance" show one row per workout. A history row's id is its
//  workout, so two workouts on one day are two rows, newest first. A
//  "Recent performance" entry reads the working sets of every log of the
//  exercise in its workout, in log order and then set order, and the
//  list keeps the newest five workouts.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ExerciseRowsPerWorkout", .serialized)
struct ExerciseRowsPerWorkoutTests {

    // MARK: - History list

    @Test("two finished workouts of the exercise on one day get their own history rows, newest first")
    func sameDayWorkoutsGetTheirOwnRows() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let day = Calendar.current.startOfDay(for: daysAgo(2))
        let morning = try finishedWorkout(bench, startedAt: day.addingTimeInterval(8 * 3_600), logs: [[(100, 5, nil)]], in: ctx)
        let evening = try finishedWorkout(bench, startedAt: day.addingTimeInterval(18 * 3_600), logs: [[(105, 5, nil)]], in: ctx)

        let rows = try historyRows(bench, in: ctx)
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.id)).count == 2, "Both workouts got the history row id \(rows.map(\.id))")
        #expect(rows.map { $0.entries.first?.id } == [evening.id, morning.id])
    }

    // MARK: - Recent performance

    @Test("a workout that logs the exercise twice is one Recent performance entry, read across both logs")
    func workoutLoggedTwiceIsOneEntry() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, startedAt: daysAgo(2), logs: [[(100, 5, nil)], [(110, 5, nil)]], in: ctx)

        let entries = try recentPerformance(bench, in: ctx)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.best.weight == 110)
        #expect(entry.best.reps == 5)
        #expect(entry.workingSets == 2)
    }

    @Test("on a tie for a workout's best set, the earlier log's set wins", arguments: [false, true])
    func bestSetTieGoesToEarlierLog(readInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, startedAt: daysAgo(2), logs: [[(100, 5, 8)], [(100, 5, 9)]], in: ctx)

        let entries = try recentPerformance(bench, readInReverse: readInReverse, in: ctx)
        #expect(entries.count == 1)
        #expect(entries.first?.best.rpe == 8)
    }

    @Test("Recent performance keeps the newest five workouts, and a workout logged twice counts once")
    func keepsNewestFiveWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        // Six finished workouts, newest first; the newest logs the exercise twice.
        var workouts: [Session] = []
        for day in 1...6 {
            let logs: [[LoggedSet]] = day == 1 ? [[(100, 5, nil)], [(110, 5, nil)]] : [[(100, 5, nil)]]
            workouts.append(try finishedWorkout(bench, startedAt: daysAgo(day), logs: logs, in: ctx))
        }

        let entries = try recentPerformance(bench, in: ctx)
        #expect(entries.map(\.date) == workouts.prefix(5).map(\.startedAt))
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    private func daysAgo(_ days: Int) -> Date {
        Date.now.addingTimeInterval(-Double(days) * 86_400)
    }

    /// The exercise's history rows, built the way `ExerciseHistoryView`
    /// builds them: its fetch, its completed working sets with no intent
    /// filter, then its grouping.
    private func historyRows(_ exercise: Exercise, in ctx: ModelContext) throws -> [ExerciseHistoryView.DateGroup] {
        let targetID = exercise.id
        let logs = try ctx.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        ))
        let sets = logs.flatMap { se in
            (se.sets ?? [])
                .filter { $0.isComplete && !$0.isWarmup }
                .map { (setEntry: $0, sessionExercise: se) }
        }
        return ExerciseHistoryView.groupedByDate(from: sets)
    }

    /// The exercise's "Recent performance" entries, built the way
    /// `RecentPerformanceList` builds them from its fetch. `readInReverse`
    /// hands the logs over in the reverse of the fetch's order, as
    /// SwiftData may return them.
    private func recentPerformance(
        _ exercise: Exercise,
        readInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> [RecentPerformanceList.Entry] {
        let targetID: UUID? = exercise.id
        let logs = try ctx.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID }
        ))
        return RecentPerformanceList.entries(from: readInReverse ? Array(logs.reversed()) : logs)
    }

    /// A finished strength workout started at `startedAt` that logs
    /// `exercise` once per entry of `logs`, in that workout order, every
    /// set a completed working set.
    @discardableResult
    private func finishedWorkout(
        _ exercise: Exercise,
        startedAt: Date,
        logs: [[LoggedSet]],
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(45 * 60)
        session.intentRaw = Intent.strength.rawValue

        for (logIndex, sets) in logs.enumerated() {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = exercise
            se.exerciseNameSnapshot = exercise.name
            se.orderIndex = logIndex

            for (setIndex, s) in sets.enumerated() {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = se
                entry.orderIndex = setIndex
                entry.weight = s.weight
                entry.reps = s.reps
                entry.rpe = s.rpe
                entry.setTypeRaw = SetType.working.rawValue
                entry.isWarmup = false
                entry.isComplete = true
                entry.completedAt = startedAt
            }
        }
        try ctx.save()
        return session
    }
}
