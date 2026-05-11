//
//  PreviousMatchingIntentTests.swift
//  fitbodTests
//
//  Six `@Test` functions covering the shared previous-matching-intent
//  query (`PreviousMatchingIntent.fetchTopWorkingSet`). The helper is
//  used by both SessionFactory (seed-weight hint) and the future
//  PreviousColumn view (plan 04-01), so it needs an independent test
//  matrix:
//
//    1. returnsNilWhenNoPriorSession — empty DB → nil
//    2. findsTopWorkingSetExcludesWarmupsAndZeroReps — filters to the
//       non-warmup, reps > 0, isComplete == true rows
//    3. intentSplitRespectsIntentFilter — strength session is ignored
//       when querying for hypertrophy (ROUTINE-08 data plumbing)
//    4. mostRecentSessionByStartedAtWins — sorted by
//       Session.startedAt desc
//    5. nilExerciseIDReturnsNil — defensive nil-guard
//    6. ignoresIncompleteSets — sentinel filter; planned-but-not-logged
//       rows skipped
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PreviousMatchingIntent", .serialized)
struct PreviousMatchingIntentTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Creates a completed `Session` with a single `SessionExercise`
    /// (intent = `intentRaw`, exercise = `exercise`) containing the
    /// provided set tuples: `(weight, reps, rpe, isWarmup, isComplete)`.
    @discardableResult
    private func makeCompletedSession(
        ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        intentRaw: String,
        sets: [(Double, Int, Double?, Bool, Bool)]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(60 * 45)
        session.routineSnapshotName = "Test"
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.intentRaw = intentRaw
        se.targetSets = sets.count
        ctx.insert(se)

        for (i, tup) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = tup.0
            entry.reps = tup.1
            entry.rpe = tup.2
            entry.isWarmup = tup.3
            entry.isComplete = tup.4
            entry.completedAt = startedAt
            ctx.insert(entry)
        }
        try ctx.save()
        return session
    }

    // MARK: - 1. empty DB → nil

    @Test("returnsNilWhenNoPriorSession — empty DB yields no hit")
    func returnsNilWhenNoPriorSession() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)
        try ctx.save()

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hit == nil)
    }

    // MARK: - 2. top-working-set filter (warmups + zero-reps excluded)

    @Test("findsTopWorkingSetExcludesWarmupsAndZeroReps — filters to committed working sets")
    func findsTopWorkingSetExcludesWarmupsAndZeroReps() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)

        _ = try makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_000),
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            sets: [
                (95,  5, 6.0,  true,  true),    // warmup — ignored
                (175, 0, nil,  false, false),   // zero reps — ignored
                (185, 5, 8.0,  false, true),    // working — top weight
                (180, 5, 8.5,  false, true),    // working — lower weight
            ]
        )

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hit?.weight == 185)
        #expect(hit?.reps == 5)
        #expect(hit?.rpe == 8.0)
    }

    // MARK: - 3. intent split (ROUTINE-08 data plumbing)

    @Test("intentSplitRespectsIntentFilter — strength session ignored when querying hypertrophy")
    func intentSplitRespectsIntentFilter() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)

        _ = try makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 2_000),
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            sets: [(185, 5, 8.0, false, true)]
        )

        // Querying for hypertrophy should NOT see the strength session.
        let hyperHit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.hypertrophy.rawValue,
            context: ctx
        )
        #expect(hyperHit == nil)

        // Sanity: querying for strength DOES see it.
        let strengthHit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(strengthHit?.weight == 185)
    }

    // MARK: - 4. most-recent-wins by Session.startedAt

    @Test("mostRecentSessionByStartedAtWins — sorted by Session.startedAt desc")
    func mostRecentSessionByStartedAtWins() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)

        _ = try makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_000),
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            sets: [(135, 5, 7.0, false, true)]
        )
        _ = try makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 2_000),
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            sets: [(185, 5, 8.5, false, true)]
        )

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        // The more recent (startedAt = 2_000) session's top working set wins.
        #expect(hit?.weight == 185)
    }

    // MARK: - 5. nil exerciseID guard

    @Test("nilExerciseIDReturnsNil — defensive guard")
    func nilExerciseIDReturnsNil() throws {
        let ctx = try makeContext()
        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: nil,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hit == nil)
    }

    // MARK: - 6. isComplete sentinel filter

    @Test("ignoresIncompleteSets — planned-but-not-logged rows skipped")
    func ignoresIncompleteSets() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)

        _ = try makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 3_000),
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            sets: [
                (185, 5, 8.0, false, false),  // not committed (isComplete == false) — ignored
                (155, 5, 7.5, false, true),   // committed — wins
            ]
        )

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hit?.weight == 155)
    }
}
