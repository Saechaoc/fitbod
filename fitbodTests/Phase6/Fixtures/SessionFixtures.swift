//
//  SessionFixtures.swift
//  fitbodTests
//
//  Wave-2 plan 06-02 — shared Phase 6 test seed builder hoisted from
//  PreviousMatchingIntentTests.makeCompletedSession (Phase 2 pattern).
//  Reused by PRDetectorTests, WeeklyTonnageAggregatorTests (where
//  helpful), ExportEncoderTests, and any downstream Phase 6 test
//  that needs a deterministic `Session + SessionExercise + [SetEntry]`
//  triad.
//
//  Phase 3.1 (PIVOT-02): intent lives on Session, not SessionExercise.
//  Fixture writes `session.intentRaw = intentRaw` accordingly.
//
//  Tuple shape `(weight, reps, rpe, isWarmup, isComplete)` matches
//  the existing PreviousMatchingIntentTests verbatim so re-using
//  test bodies is mechanical.
//

import Foundation
import SwiftData
@testable import fitbod

@MainActor
enum SessionFixtures {

    /// Insert and save a completed Session with one SessionExercise
    /// and the provided sets. Returns the Session so callers can
    /// hold a reference for assertions.
    @discardableResult
    static func makeCompletedSession(
        ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        intentRaw: String,
        sets: [(weight: Double, reps: Int, rpe: Double?, isWarmup: Bool, isComplete: Bool)]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(60 * 45)
        session.routineSnapshotName = "Fixture"
        session.intentRaw = intentRaw
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.targetSets = sets.count
        ctx.insert(se)

        for (i, tup) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = tup.weight
            entry.reps = tup.reps
            entry.rpe = tup.rpe
            entry.isWarmup = tup.isWarmup
            entry.isComplete = tup.isComplete
            entry.completedAt = startedAt
            ctx.insert(entry)
        }
        try ctx.save()
        return session
    }
}
