//
//  ProgressChartSelectionTests.swift
//  fitbodTests
//
//  RM-023: the progress chart compares like with like. Every chip reads the
//  finished workouts of one intent that started in the chosen period, the
//  newest workout's intent unless one is picked, and the chart says why
//  when they draw no line: nothing finished, nothing in the period, one
//  workout, or workouts without an e1RM or an RPE.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Progress chart selection (RM-023)", .serialized)
struct ProgressChartSelectionTests {
    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000)
    private let day: TimeInterval = 24 * 3600

    @Test("The chart reads the finished workouts of one intent, the newest workout's unless one is picked")
    func readsFinishedWorkoutsOfOneIntent() throws {
        let (ctx, bench) = try makeBench()
        let logs = [
            log(bench, daysAgo: 20, .hypertrophy, in: ctx),
            log(bench, daysAgo: 13, .strength, in: ctx),
            log(bench, daysAgo: 6, .hypertrophy, in: ctx),
            // Open, so it neither plots nor makes strength the newest intent.
            log(bench, daysAgo: 0, .strength, finished: false, in: ctx),
        ]

        let newest = ProgressChartSelection(logs: logs, intent: nil, since: nil)
        #expect(newest.intents == [.strength, .hypertrophy])
        #expect(newest.intent == .hypertrophy)
        #expect(newest.logs.map(\.id) == [logs[0].id, logs[2].id])
        #expect(newest.workouts == 2)

        let picked = ProgressChartSelection(logs: logs, intent: .strength, since: nil)
        #expect(picked.intent == .strength)
        #expect(picked.logs.map(\.id) == [logs[1].id])

        // An intent the exercise has no workouts at falls back to the newest workout's.
        #expect(ProgressChartSelection(logs: logs, intent: .power, since: nil).intent == .hypertrophy)
    }

    @Test("A period keeps the workouts started since its start; the PR rule still reads the intent's whole history")
    func periodKeepsWorkoutsStartedSinceItsStart() throws {
        let (ctx, bench) = try makeBench()
        let logs = [
            log(bench, daysAgo: 70, .strength, sets: [(140, 3, 9)], in: ctx),
            log(bench, daysAgo: 6, .strength, sets: [(120, 3, 9)], in: ctx),
        ]

        let selection = ProgressChartSelection(logs: logs, intent: nil, since: now.addingTimeInterval(-56 * day))
        #expect(selection.logs.map(\.id) == [logs[1].id])
        #expect(selection.workouts == 1)
        #expect(selection.bestE1RM == OneRepMaxEstimator.estimate(weight: 140, reps: 3))
    }

    @Test("A period starts at its lower bound: a workout started then counts, one a second earlier does not")
    func periodStartsAtItsLowerBound() throws {
        let (ctx, bench) = try makeBench()
        // Worked out as the view does: whole weeks, starting on Monday.
        let since = try #require(TimeRangeChoice.last8wk.lowerBound(now: now, calendar: WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: true)))
        let atStart = log(bench, daysAgo: 0, .strength, in: ctx)
        atStart.session?.startedAt = since
        let before = log(bench, daysAgo: 0, .strength, in: ctx)
        before.session?.startedAt = since.addingTimeInterval(-1)

        let selection = ProgressChartSelection(logs: [before, atStart], intent: nil, since: since)
        #expect(selection.logs.map(\.id) == [atStart.id])
    }

    @Test("A picked intent with no workouts in the period says so")
    func notesForAPickedIntentOutsideThePeriod() throws {
        let (ctx, bench) = try makeBench()
        let logs = [log(bench, daysAgo: 70, .strength, in: ctx), log(bench, daysAgo: 3, .hypertrophy, in: ctx)]
        let picked = ProgressChartSelection(logs: logs, intent: .strength, since: now.addingTimeInterval(-56 * day))
        #expect(picked.gapNote(metric: .e1RM, plotted: 0, period: .last8wk) == (
            "No strength workouts in the last 8 weeks", "Pick All time to see older workouts."
        ))
    }

    @Test("With nothing finished, or nothing in the period, the chart says so and what to do")
    func notesForNoWorkouts() throws {
        let (ctx, bench) = try makeBench()
        let open = log(bench, daysAgo: 0, .strength, finished: false, in: ctx)
        let none = ProgressChartSelection(logs: [open], intent: nil, since: nil)
        #expect(none.intents.isEmpty)
        #expect(none.gapNote(metric: .e1RM, plotted: 0, period: .allTime) == (
            "No finished workouts yet", "Finish a workout with this exercise to see its trend."
        ))

        let old = log(bench, daysAgo: 70, .strength, in: ctx)
        let outside = ProgressChartSelection(logs: [open, old], intent: nil, since: now.addingTimeInterval(-56 * day))
        #expect(outside.gapNote(metric: .e1RM, plotted: 0, period: .last8wk) == (
            "No strength workouts in the last 8 weeks", "Pick All time to see older workouts."
        ))
    }

    @Test("One workout asks for another; workouts without a value say which one is missing")
    func notesForSparseWorkouts() throws {
        let (ctx, bench) = try makeBench()
        let one = ProgressChartSelection(logs: [log(bench, daysAgo: 3, .hypertrophy, in: ctx)], intent: nil, since: nil)
        #expect(one.gapNote(metric: .volume, plotted: 1, period: .allTime) == ("1 hypertrophy workout", "Log another to see a trend."))

        // Twelve reps have no e1RM, and neither workout logged an RPE.
        let logs = [
            log(bench, daysAgo: 10, .hypertrophy, sets: [(60, 12, nil)], in: ctx),
            log(bench, daysAgo: 3, .hypertrophy, sets: [(80, 8, nil)], in: ctx),
        ]
        let two = ProgressChartSelection(logs: logs, intent: nil, since: now.addingTimeInterval(-56 * day))
        let e1RMWorkouts = Set(SeriesBuilder.buildPoints(from: two.logs).map(\.date)).count
        #expect(two.gapNote(metric: .e1RM, plotted: e1RMWorkouts, period: .last8wk) == (
            "2 hypertrophy workouts in the last 8 weeks",
            "Only one has an e1RM, which needs a set with weight and 10 reps or fewer."
        ))
        let rpeWorkouts = SeriesBuilder.averageRPEPoints(from: two.logs).count
        #expect(two.gapNote(metric: .averageRPE, plotted: rpeWorkouts, period: .last8wk) == (
            "2 hypertrophy workouts in the last 8 weeks", "None has an RPE logged."
        ))
    }

    // MARK: - Fixtures

    private func makeBench() throws -> (ModelContext, Exercise) {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let bench = Exercise(name: "Bench Press", canonicalName: "bench press", equipmentRaw: "barbell", mechanicRaw: "compound")
        ctx.insert(bench)
        return (ctx, bench)
    }

    /// One workout of `exercise` at `intent`, started `daysAgo` days before
    /// `now`, with completed work sets of (weight, reps, RPE).
    private func log(
        _ exercise: Exercise,
        daysAgo: Double,
        _ intent: Intent,
        finished: Bool = true,
        sets: [(Double, Int, Double?)] = [(100, 5, 8)],
        in ctx: ModelContext
    ) -> SessionExercise {
        let start = now.addingTimeInterval(-daysAgo * day)
        let workout = Session()
        ctx.insert(workout)
        workout.startedAt = start
        workout.completedAt = finished ? start.addingTimeInterval(3600) : nil
        workout.intentRaw = intent.rawValue
        let entry = SessionExercise()
        ctx.insert(entry)
        entry.session = workout
        entry.exercise = exercise
        for (index, (weight, reps, rpe)) in sets.enumerated() {
            let set = SetEntry()
            ctx.insert(set)
            set.sessionExercise = entry
            set.orderIndex = index
            set.weight = weight
            set.reps = reps
            set.rpe = rpe
            set.isComplete = true
            set.completedAt = start.addingTimeInterval(Double(index) * 180)
        }
        return entry
    }
}
