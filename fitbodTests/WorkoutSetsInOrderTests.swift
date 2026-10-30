//
//  WorkoutSetsInOrderTests.swift
//  fitbodTests
//
//  An exercise's history row and the plateau check's top set read a
//  workout's sets in order: its logs of the exercise in log order, then
//  each log's sets in set order, whatever order SwiftData returns them
//  in. A history row reads every log of the exercise in its workout, and
//  on a tie for the top set the earlier set wins.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WorkoutSetsInOrder", .serialized)
struct WorkoutSetsInOrderTests {

    // MARK: - History row

    @Test("a workout that logs the exercise twice gives one history row across both logs, in log order", arguments: [false, true])
    func historyRowReadsEveryLog(readInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, logs: [[(100, 5, nil)], [(110, 5, nil)]], in: ctx)

        let rows = try historyRows(bench, readInReverse: readInReverse, in: ctx)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.topSetLabel == "110×5")
        #expect(row.e1RMLabel == "135.7")
        #expect(row.setCount == 2)
        #expect(row.setChips == ["100×5", "110×5"])
    }

    @Test("on a tie for the history row's top set, the earlier log's set wins", arguments: [false, true])
    func historyTopSetTieGoesToEarlierLog(readInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try finishedWorkout(bench, logs: [[(100, 5, 8)], [(100, 5, 9)]], in: ctx)

        let row = try #require(try historyRows(bench, readInReverse: readInReverse, in: ctx).first)
        #expect(row.topSetLabel == "100×5 @8")
        #expect(row.setChips == ["100×5 @8", "100×5 @9"])
    }

    // MARK: - Plateau top set

    @Test("on a tie in e1RM inside one log, the plateau check's top set is the earlier set", arguments: [true, false])
    func plateauTopSetTieGoesToEarlierSet(insertedInReverse: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        // Set 1 at 100 x 5 @ 8 and set 2 at 100 x 5 @ 9 share an e1RM.
        // Inserted in reverse, set 2 goes into the store first.
        let workout = try finishedWorkout(
            bench, logs: [[(100, 5, 8), (100, 5, 9)]],
            insertedInReverse: insertedInReverse, in: ctx
        )

        let top = try #require(PlateauDetector.topSet(in: workout.exercises ?? []))
        #expect(top.rpe == 8)
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    /// The exercise's history rows, built the way `ExerciseHistoryView`
    /// builds them: its fetch, its completed working sets with no intent
    /// filter, then its grouping. `readInReverse` hands the sets over in
    /// the reverse of the fetch's order, as SwiftData may return them.
    private func historyRows(_ exercise: Exercise, readInReverse: Bool, in ctx: ModelContext) throws -> [HistoryEntry] {
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
        return ExerciseHistoryView.groupedByDate(from: readInReverse ? Array(sets.reversed()) : sets)
            .flatMap(\.entries)
    }

    /// A finished strength workout started two days ago that logs
    /// `exercise` once per entry of `logs`, in that workout order, every
    /// set a completed working set. Each log and each set is saved on its
    /// own; `insertedInReverse` inserts the last log first and each log's
    /// last set first, so the store's order differs from the workout's.
    @discardableResult
    private func finishedWorkout(
        _ exercise: Exercise,
        logs: [[LoggedSet]],
        insertedInReverse: Bool = false,
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = Date.now.addingTimeInterval(-2 * 86_400)
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
