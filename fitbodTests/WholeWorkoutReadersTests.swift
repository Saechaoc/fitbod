//
//  WholeWorkoutReadersTests.swift
//  fitbodTests
//
//  The deload advisor's RPE-creep signal (Sig-2) and the session
//  comparison read a workout's sets in order: its logs of an exercise in
//  log order, then each log's sets in set order, whatever order SwiftData
//  returns them in. On a tie in e1RM the earlier set wins. The comparison
//  gives one row per exercise, read across every log of it in the
//  workout, and compares it with every log of it in the prior workout.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WholeWorkoutReaders", .serialized)
struct WholeWorkoutReadersTests {

    private let today = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Deload advisor Sig-2

    @Test("on a tie in e1RM, the deload advisor's RPE creep reads the earlier set", arguments: [true, false])
    func deloadRPECreepTieGoesToEarlierSet(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let settings = UserSettings.default()
        ctx.insert(settings)
        // Three workouts at 100 x 5 whose top-set RPEs are 7, 7.5 and a tie
        // in the newest: set 1 at RPE 7.5 and set 2 at RPE 8.5. Set 1's 7.5
        // is a creep of 0.5; set 2's 8.5 would be 1.5, enough to fire.
        // Inserted in reverse, set 2 goes into the store first.
        try workout(daysAgo: 9, logs: [(bench, [(100, 5, 7)])], in: ctx)
        try workout(daysAgo: 5, logs: [(bench, [(100, 5, 7.5)])], in: ctx)
        try workout(
            daysAgo: 2, logs: [(bench, [(100, 5, 7.5), (100, 5, 8.5)])],
            insertedInReverse: insertedInReverse, in: ctx
        )

        let report = DeloadAdvisor.signalReport(weekStart: today, in: ctx, settings: settings)
        #expect(report.sig2_rpeCreep == nil)
        let hasSig2 = report.firedSignals.contains { signal in
            if case .rpeCreep = signal { return true } else { return false }
        }
        #expect(!hasSig2)
    }

    // MARK: - Session comparison

    @Test("a workout that logs the exercise twice gives one comparison row, read across every log on each side", arguments: [false, true])
    func comparisonRowReadsEveryLog(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let routineID = UUID()
        try workout(
            daysAgo: 7, routineID: routineID,
            logs: [(bench, [(105, 5, nil)]), (bench, [(95, 5, nil)])],
            insertedInReverse: insertedInReverse, in: ctx
        )
        let current = try workout(
            daysAgo: 0, routineID: routineID,
            logs: [(bench, [(100, 5, nil)]), (bench, [(110, 5, nil)])],
            insertedInReverse: insertedInReverse, in: ctx
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.exerciseID == bench.id)
        let thisWeek = try #require(row.thisWeekTopSet)
        #expect(thisWeek.weight == 110)
        #expect(thisWeek.reps == 5)
        let lastWeek = try #require(row.lastWeekTopSet)
        #expect(lastWeek.weight == 105)
        #expect(lastWeek.reps == 5)
        #expect(row.deltaWeight == 5)
        #expect(row.deltaReps == 0)
    }

    @Test("comparison rows follow the order of each exercise's first log")
    func comparisonRowsFollowFirstLog() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let squat = LoggerFixtures.exercise("Squat", in: ctx)
        // The workout logs the bench, then the squat, then the bench again.
        let current = try workout(
            daysAgo: 0, routineID: UUID(),
            logs: [(bench, [(100, 5, nil)]), (squat, [(140, 5, nil)]), (bench, [(110, 5, nil)])],
            in: ctx
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.map(\.exerciseID) == [bench.id, squat.id])
        #expect(rows.first?.thisWeekTopSet?.weight == 110)
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    /// A finished strength workout of `routineID` started `daysAgo` days
    /// before `today` that holds one log per entry of `logs`, in that
    /// workout order, every set a completed working set. Each log and each
    /// set is saved on its own; `insertedInReverse` inserts the last log
    /// first and each log's last set first, so the store's order differs
    /// from the workout's.
    @discardableResult
    private func workout(
        daysAgo: Int,
        routineID: UUID? = nil,
        logs: [(exercise: Exercise, sets: [LoggedSet])],
        insertedInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = today.addingTimeInterval(-Double(daysAgo) * 86_400)
        session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
        session.sourceRoutineID = routineID
        session.intentRaw = Intent.strength.rawValue
        try ctx.save()

        var orderedLogs = Array(logs.enumerated())
        if insertedInReverse { orderedLogs.reverse() }
        for (logIndex, log) in orderedLogs {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = log.exercise
            se.exerciseNameSnapshot = log.exercise.name
            se.orderIndex = logIndex
            try ctx.save()

            var orderedSets = Array(log.sets.enumerated())
            if insertedInReverse { orderedSets.reverse() }
            for (setIndex, s) in orderedSets {
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
                entry.completedAt = session.startedAt
                try ctx.save()
            }
        }
        return session
    }
}
