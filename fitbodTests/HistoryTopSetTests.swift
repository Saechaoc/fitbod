//
//  HistoryTopSetTests.swift
//  fitbodTests
//
//  Ticket T116, findings F-ext-3 (F252) and F278. An exercise's history
//  row names its top set on the TOP line: the set its e1RM comes from,
//  the set with the highest e1RM as the row computes it, the earlier set
//  on a tie. When no set has an e1RM, the TOP line keeps the set with the
//  most volume. The TOP line named the set with the most volume, weight
//  times reps, every time, so it could name another set than the e1RM's.
//
//  The count line and "Workouts · 30d" count the workouts the list shows,
//  under the intent filter. They counted every workout that held the
//  exercise, one in progress or an empty one too, and ignored the filter.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// ExerciseHistoryView is a View, so its static builders are main-actor isolated.
@MainActor
@Suite("HistoryTopSet")
struct HistoryTopSetTests {

    // MARK: - TOP line

    /// 85×8 @8 has the highest e1RM, 113.3, and 75×12 @9 the most
    /// volume, 900.
    @Test("the TOP line names the set the row's e1RM comes from")
    func topLineNamesTheE1RMSet() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try workout(bench, startedAt: twoDaysAgo, sets: [(85, 8, 8), (80, 10, 9), (75, 12, 9)], in: ctx)

        let row = try #require(try historyRows(bench, in: ctx).first)
        #expect(row.topSetLabel == "85×8 @8")
        #expect(row.e1RMLabel == "113.3")
    }

    /// 100×5 @8 and 100×6 @9 share an e1RM of 123.3; the second has more
    /// volume.
    @Test("on a tie in e1RM, the TOP line names the earlier set", arguments: [false, true])
    func e1RMTieGoesToEarlierSet(readInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try workout(bench, startedAt: twoDaysAgo, sets: [(100, 5, 8), (100, 6, 9)], in: ctx)

        let row = try #require(try historyRows(bench, readInReverse: readInReverse, in: ctx).first)
        #expect(row.topSetLabel == "100×5 @8")
        #expect(row.e1RMLabel == "123.3")
    }

    /// Bodyweight sets with no added load: every e1RM and every volume is
    /// 0, so the first set has the most volume.
    @Test("when no set has an e1RM, the TOP line names the set with the most volume")
    func noE1RMKeepsTheMostVolumeSet() throws {
        let ctx = try LoggerFixtures.makeContext()
        let pullUp = LoggerFixtures.exercise("Pull-up", in: ctx)
        try workout(pullUp, startedAt: twoDaysAgo, sets: [(0, 12, nil), (0, 15, nil), (0, 10, nil)], in: ctx)

        let row = try #require(try historyRows(pullUp, in: ctx).first)
        #expect(row.e1RMLabel == "—")
        #expect(row.topSetLabel == "0×12")
    }

    // MARK: - Workouts the list shows

    /// Four workouts hold the bench press. A finished strength workout 40
    /// days ago and a finished hypertrophy workout 10 days ago each have a
    /// completed working set. A strength workout in progress has one, and
    /// one set still to do. A finished strength workout 5 days ago is
    /// empty: a completed warm-up and a set never done. The count line
    /// reads the rows' count.
    @Test("the count line and Workouts · 30d count the workouts the list shows, under the intent filter")
    func countsAreTheShownWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let now = Date(timeIntervalSinceReferenceDate: 815_000_000)
        let day: TimeInterval = 86_400
        let old = try workout(bench, startedAt: now - 40 * day, sets: [(100, 5, 8)], in: ctx)
        let recent = try workout(bench, startedAt: now - 10 * day, intent: .hypertrophy, sets: [(80, 10, 8)], in: ctx)
        let inProgress = try workout(bench, startedAt: now - 3_600, inProgress: true, sets: [(100, 5, 8)], toDo: 1, in: ctx)
        try workout(bench, startedAt: now - 5 * day, sets: [], warmups: 1, toDo: 1, in: ctx)

        let all = try shownSets(bench, intent: nil, in: ctx)
        #expect(rows(from: all).map(\.id) == [inProgress.id, recent.id, old.id])
        #expect(ExerciseHistoryView.workouts30d(from: all, now: now) == 2)

        let strength = try shownSets(bench, intent: .strength, in: ctx)
        #expect(rows(from: strength).map(\.id) == [inProgress.id, old.id])
        #expect(ExerciseHistoryView.workouts30d(from: strength, now: now) == 1)
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    private var twoDaysAgo: Date { Date.now.addingTimeInterval(-2 * 86_400) }

    /// The sets the exercise's history shows under `intent`, read the way
    /// `ExerciseHistoryView` reads them: its fetch, then its filter.
    /// `readInReverse` hands them over in the reverse of the fetch's
    /// order, as SwiftData may return them.
    private func shownSets(
        _ exercise: Exercise,
        intent: Intent?,
        readInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> [(setEntry: SetEntry, sessionExercise: SessionExercise)] {
        let targetID = exercise.id
        let logs = try ctx.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        ))
        let sets = ExerciseHistoryView.completedSets(from: logs, intent: intent)
        return readInReverse ? Array(sets.reversed()) : sets
    }

    /// The history's rows for `sets`, with the PR replay run once.
    private func rows(from sets: [(setEntry: SetEntry, sessionExercise: SessionExercise)]) -> [HistoryEntry] {
        ExerciseHistoryView.rows(from: sets, prSetIDs: ExerciseHistoryView.prSets(from: sets))
    }

    /// The exercise's history rows with no intent filter.
    private func historyRows(
        _ exercise: Exercise,
        readInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> [HistoryEntry] {
        rows(from: try shownSets(exercise, intent: nil, readInReverse: readInReverse, in: ctx))
    }

    /// A workout of `intent` started at `startedAt`, finished 45 minutes
    /// later unless `inProgress`, that logs `exercise` once: `warmups`
    /// completed warm-ups, then `sets` as completed working sets, then
    /// `toDo` working sets not yet done, in that set order.
    @discardableResult
    private func workout(
        _ exercise: Exercise,
        startedAt: Date,
        intent: Intent = .strength,
        inProgress: Bool = false,
        sets: [LoggedSet],
        warmups: Int = 0,
        toDo: Int = 0,
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = inProgress ? nil : startedAt.addingTimeInterval(45 * 60)
        session.intentRaw = intent.rawValue

        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = exercise
        se.exerciseNameSnapshot = exercise.name

        let warmupSets = Array(repeating: (weight: 60.0, reps: 5, rpe: Double?.none), count: warmups)
        let toDoSets = Array(repeating: (weight: 100.0, reps: 5, rpe: Double?.none), count: toDo)
        for (index, logged) in (warmupSets + sets + toDoSets).enumerated() {
            let entry = SetEntry()
            ctx.insert(entry)
            entry.sessionExercise = se
            entry.orderIndex = index
            entry.weight = logged.weight
            entry.reps = logged.reps
            entry.rpe = logged.rpe
            entry.isWarmup = index < warmups
            entry.setTypeRaw = (entry.isWarmup ? SetType.warmup : SetType.working).rawValue
            entry.isComplete = index < warmups + sets.count
            entry.completedAt = startedAt
        }
        try ctx.save()
        return session
    }
}
