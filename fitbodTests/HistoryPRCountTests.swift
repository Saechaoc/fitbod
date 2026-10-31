//
//  HistoryPRCountTests.swift
//  fitbodTests
//
//  Ticket T96, finding F129. An exercise's history shows "PRs · 30d": the
//  working sets from the last 30 days that set a personal record, by the
//  in-workout PR banner's check. The sets the history shows are replayed
//  oldest first through `PRDetector.check(set:against:)` from an empty
//  table, whatever order the fetch returns them in. The count was a
//  placeholder that always read 0.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("HistoryPRCount", .serialized)
struct HistoryPRCountTests {

    /// 100 x 5 forty days ago sets the first record, outside the window.
    /// 105 x 5 ten days ago beats it, and 100 x 5 five days ago only ties
    /// the first, so one set from the last 30 days set a PR.
    @Test("PRs · 30d counts the sets from the last 30 days that set a record", arguments: [false, true])
    func countsTheLast30DaysPRs(readInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, daysAgo: 40, weight: 100, reps: 5, in: ctx)
        try finishedWorkout(bench, daysAgo: 10, weight: 105, reps: 5, in: ctx)
        try finishedWorkout(bench, daysAgo: 5, weight: 100, reps: 5, in: ctx)

        let sets = try historySets(bench, in: ctx)
        #expect(ExerciseHistoryView.prs30d(from: readInReverse ? Array(sets.reversed()) : sets) == 1)
    }

    // MARK: - Helpers

    /// The completed working sets the exercise's history shows with no
    /// intent filter, read the way `ExerciseHistoryView` reads them: newest
    /// workout first.
    private func historySets(
        _ exercise: Exercise,
        in ctx: ModelContext
    ) throws -> [(setEntry: SetEntry, sessionExercise: SessionExercise)] {
        let targetID = exercise.id
        let logs = try ctx.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        ))
        return logs.flatMap { se in
            (se.sets ?? [])
                .filter { $0.isComplete && !$0.isWarmup }
                .map { (setEntry: $0, sessionExercise: se) }
        }
    }

    /// A finished strength workout `days` days ago with one completed
    /// working set of `exercise`.
    private func finishedWorkout(
        _ exercise: Exercise,
        daysAgo days: Int,
        weight: Double,
        reps: Int,
        in ctx: ModelContext
    ) throws {
        let startedAt = Date.now.addingTimeInterval(-Double(days) * 86_400)
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(45 * 60)
        session.intentRaw = Intent.strength.rawValue

        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = exercise
        se.exerciseNameSnapshot = exercise.name

        let entry = SetEntry()
        ctx.insert(entry)
        entry.sessionExercise = se
        entry.weight = weight
        entry.reps = reps
        entry.setTypeRaw = SetType.working.rawValue
        entry.isWarmup = false
        entry.isComplete = true
        entry.completedAt = startedAt
        try ctx.save()
    }
}
