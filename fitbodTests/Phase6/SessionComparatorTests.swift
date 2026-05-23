//
//  SessionComparatorTests.swift
//  fitbodTests
//
//  Wave-3 plan 06-04 — SessionComparator boundary coverage.
//  REQUIREMENTS PROG-07 + CONTEXT D-05/D-22/D-23 + Phase 3.1 PIVOT-02
//  (intent is session-level, not per-SessionExercise).
//
//  Eight @Test functions:
//    1. perExerciseMatchByTriple — same routine + same exercise +
//       same intent within 14 days matches
//    2. intentSplitNeverCrosses — strength current never matches
//       hypertrophy prior
//    3. sourceRoutineIDMatchRequired — different routine UUIDs don't
//       cross
//    4. fourteenDayWindowStrict — 13 days back matches; 15 days does not
//    5. topSetByE1RMNotWeight — D-05 picks higher e1RM over heavier set
//    6. noPriorMatchEmitsNilRow — current exercise with no comparable
//       prior emits row with nil lastWeekTopSet + nil deltas
//    7. freestandingSessionNullRoutineID — nil sourceRoutineID → all
//       priors nil
//    8. orderIndexPreserved — output sort matches current.exercises
//       orderIndex asc
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionComparator (PROG-07 + CONTEXT D-22 corrected + D-05)", .serialized)
struct SessionComparatorTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    private func seedBench(in ctx: ModelContext) -> Exercise {
        let bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        return bench
    }

    private func seedSquat(in ctx: ModelContext) -> Exercise {
        let squat = Exercise(
            name: "Back Squat",
            canonicalName: "back squat",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(squat)
        return squat
    }

    /// Build a Session with a given sourceRoutineID, intent, and
    /// one or more (exercise, sets) tuples in orderIndex order.
    @discardableResult
    private func seedSession(
        in ctx: ModelContext,
        startedAt: Date,
        sourceRoutineID: UUID?,
        intentRaw: String,
        exercisesAndSets: [(exercise: Exercise, sets: [(weight: Double, reps: Int)])]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(3600)
        session.routineSnapshotName = "Test"
        session.sourceRoutineID = sourceRoutineID
        session.intentRaw = intentRaw
        ctx.insert(session)

        for (idx, pair) in exercisesAndSets.enumerated() {
            let se = SessionExercise()
            se.session = session
            se.exercise = pair.exercise
            se.orderIndex = idx
            se.targetSets = pair.sets.count
            ctx.insert(se)

            for (setIdx, tup) in pair.sets.enumerated() {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = setIdx
                entry.weight = tup.weight
                entry.reps = tup.reps
                entry.isComplete = true
                entry.completedAt = startedAt.addingTimeInterval(Double(setIdx) * 60)
                entry.setTypeRaw = SetType.working.rawValue
                ctx.insert(entry)
            }
        }
        try ctx.save()
        return session
    }

    // MARK: - 1. per-exercise match by triple

    @Test("perExerciseMatchByTriple — same routine+exercise+intent within 14 days matches")
    func perExerciseMatchByTriple() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineID = UUID()

        let priorStart = Date(timeIntervalSince1970: 1_700_000_000)
        try seedSession(
            in: ctx, startedAt: priorStart, sourceRoutineID: routineID,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )
        let currentStart = priorStart.addingTimeInterval(7 * 86_400)
        let current = try seedSession(
            in: ctx, startedAt: currentStart, sourceRoutineID: routineID,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 105, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        let thisTop = try #require(row.thisWeekTopSet)
        let lastTop = try #require(row.lastWeekTopSet)
        #expect(thisTop.weight == 105)
        #expect(lastTop.weight == 100)
        #expect(row.deltaWeight == 5)
        #expect(row.deltaReps == 0)
    }

    // MARK: - 2. intent split

    @Test("intentSplitNeverCrosses — strength current does not match hypertrophy prior")
    func intentSplitNeverCrosses() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineID = UUID()
        let priorStart = Date(timeIntervalSince1970: 1_700_000_000)
        try seedSession(
            in: ctx, startedAt: priorStart, sourceRoutineID: routineID,
            intentRaw: Intent.hypertrophy.rawValue,
            exercisesAndSets: [(bench, [(weight: 80, reps: 10)])]
        )
        let current = try seedSession(
            in: ctx, startedAt: priorStart.addingTimeInterval(7 * 86_400),
            sourceRoutineID: routineID,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        let row = try #require(rows.first)
        #expect(row.lastWeekTopSet == nil)
        #expect(row.deltaWeight == nil)
    }

    // MARK: - 3. sourceRoutineID gate

    @Test("sourceRoutineIDMatchRequired — different routines don't cross")
    func sourceRoutineIDMatchRequired() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineA = UUID()
        let routineB = UUID()
        let priorStart = Date(timeIntervalSince1970: 1_700_000_000)
        try seedSession(
            in: ctx, startedAt: priorStart, sourceRoutineID: routineA,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )
        let current = try seedSession(
            in: ctx, startedAt: priorStart.addingTimeInterval(7 * 86_400),
            sourceRoutineID: routineB,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 105, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        let row = try #require(rows.first)
        #expect(row.lastWeekTopSet == nil)
    }

    // MARK: - 4. 14-day window strict

    @Test("fourteenDayWindowStrict — 13 days back matches; 15 days does not")
    func fourteenDayWindowStrict() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try seedSession(
            in: ctx, startedAt: now.addingTimeInterval(-13 * 86_400),
            sourceRoutineID: routineID, intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 95, reps: 5)])]
        )
        try seedSession(
            in: ctx, startedAt: now.addingTimeInterval(-15 * 86_400),
            sourceRoutineID: routineID, intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 90, reps: 5)])]
        )
        let current = try seedSession(
            in: ctx, startedAt: now, sourceRoutineID: routineID,
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        let row = try #require(rows.first)
        let lastTop = try #require(row.lastWeekTopSet)
        // Should match the 13-day-back session (95), NOT the 15-day-back one (90).
        #expect(lastTop.weight == 95)
    }

    // MARK: - 5. top-set selection by e1RM

    @Test("topSetByE1RMNotWeight — D-05 picks higher e1RM over heavier weight")
    func topSetByE1RMNotWeight() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineID = UUID()
        // Two working sets in the current session:
        //   100 × 5  → Brzycki 100 * 36/32 = 112.5
        //   110 × 2  → Brzycki 110 * 36/35 = 113.14
        // Wait — 113.14 > 112.5, so heavier wins by e1RM here. Re-design:
        //   100 × 5  → e1RM 112.5
        //    95 × 6  → Brzycki 95 * 36/31 ≈ 110.32
        //   105 × 1  → Brzycki 105 * 36/36 = 105.0
        // 100×5 has highest e1RM → should be the top set.
        // Under wrong implementation (highest weight first), 105×1 would win.
        let current = try seedSession(
            in: ctx, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineID: routineID, intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [
                (weight: 100, reps: 5),
                (weight: 95,  reps: 6),
                (weight: 105, reps: 1),
            ])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        let row = try #require(rows.first)
        let topSet = try #require(row.thisWeekTopSet)
        // e1RM-first ordering: 100×5 wins (112.5 > 110.32 > 105.0).
        #expect(topSet.weight == 100)
        #expect(topSet.reps == 5)
    }

    // MARK: - 6. no prior match emits nil row

    @Test("noPriorMatchEmitsNilRow — unique exercise emits nil lastWeekTopSet + nil deltas")
    func noPriorMatchEmitsNilRow() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let routineID = UUID()
        let current = try seedSession(
            in: ctx, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineID: routineID, intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.thisWeekTopSet != nil)
        #expect(row.lastWeekTopSet == nil)
        #expect(row.deltaWeight == nil)
        #expect(row.deltaReps == nil)
        #expect(row.deltaE1RM == nil)
    }

    // MARK: - 7. freestanding session

    @Test("freestandingSessionNullRoutineID — nil sourceRoutineID → all priors nil")
    func freestandingSessionNullRoutineID() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        // Prior session with a real routineID — should be ignored.
        try seedSession(
            in: ctx, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineID: UUID(), intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 100, reps: 5)])]
        )
        let current = try seedSession(
            in: ctx, startedAt: Date(timeIntervalSince1970: 1_700_604_800),
            sourceRoutineID: nil, // freestanding!
            intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [(bench, [(weight: 105, reps: 5)])]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        let row = try #require(rows.first)
        #expect(row.lastWeekTopSet == nil)
    }

    // MARK: - 8. orderIndex preserved

    @Test("orderIndexPreserved — output sort matches current.exercises orderIndex asc")
    func orderIndexPreserved() throws {
        let ctx = try makeContext()
        let bench = seedBench(in: ctx)
        let squat = seedSquat(in: ctx)
        let routineID = UUID()
        let current = try seedSession(
            in: ctx, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRoutineID: routineID, intentRaw: Intent.strength.rawValue,
            exercisesAndSets: [
                (bench, [(weight: 100, reps: 5)]),
                (squat, [(weight: 140, reps: 5)]),
            ]
        )

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.count == 2)
        #expect(rows[0].exerciseID == bench.id)
        #expect(rows[1].exerciseID == squat.id)
    }
}
