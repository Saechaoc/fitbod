//
//  PreviousColumnQueryTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — pins the data-path semantics consumed by the
//  `PreviousColumn` view. The view delegates to the shared
//  `PreviousMatchingIntent.fetchTopWorkingSet` helper (plan 01-01); these
//  tests verify the view-layer-visible behavior:
//
//    1. previousColumnReturnsHintWhenPriorExists — completed matching-
//       intent prior session yields a non-nil hint.
//    2. previousColumnReturnsNilWhenNoPrior — empty store yields nil.
//    3. previousColumnRespectsIntentSplit — ROUTINE-08 — a strength
//       session is invisible when the column queries for hypertrophy.
//
//  Note: the plan 01-01 `PreviousMatchingIntentTests` suite covers the
//  helper's internal semantics (warmup filter, isComplete filter, etc.).
//  This suite anchors the consumer surface — the data flowing into the
//  view's `@State private var hint` after `.task` fires.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PreviousColumnQuery", .serialized)
struct PreviousColumnQueryTests {

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

    /// Inserts a completed `Session` with a single `SessionExercise` that
    /// owns one committed working `SetEntry`. Mirrors the fixture in
    /// `PreviousMatchingIntentTests` so the two suites stay aligned on
    /// the canonical "prior session" shape.
    @discardableResult
    private func insertPriorSession(
        ctx: ModelContext,
        exercise: Exercise,
        intentRaw: String,
        weight: Double,
        reps: Int,
        rpe: Double?
    ) throws -> Session {
        let session = Session()
        session.startedAt = .now.addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
        session.routineSnapshotName = "Test"
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.intentRaw = intentRaw
        ctx.insert(se)
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = 0
        entry.weight = weight
        entry.reps = reps
        entry.rpe = rpe
        entry.isWarmup = false
        entry.isComplete = true
        entry.completedAt = session.startedAt
        ctx.insert(entry)
        try ctx.save()
        return session
    }

    // MARK: - 1. prior matching session → non-nil hit

    @Test("previousColumnReturnsHintWhenPriorExists — matching-intent prior yields hit")
    func previousColumnReturnsHintWhenPriorExists() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)
        _ = try insertPriorSession(
            ctx: ctx,
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            weight: 185,
            reps: 5,
            rpe: 8.0
        )

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hit != nil)
        #expect(hit?.weight == 185)
        #expect(hit?.reps == 5)
        #expect(hit?.rpe == 8.0)
    }

    // MARK: - 2. no prior → nil

    @Test("previousColumnReturnsNilWhenNoPrior — empty store yields nil")
    func previousColumnReturnsNilWhenNoPrior() throws {
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

    // MARK: - 3. ROUTINE-08 intent split

    @Test("previousColumnRespectsIntentSplit — strength ignored when querying hypertrophy")
    func previousColumnRespectsIntentSplit() throws {
        let ctx = try makeContext()
        let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)
        _ = try insertPriorSession(
            ctx: ctx,
            exercise: ex,
            intentRaw: Intent.strength.rawValue,
            weight: 185,
            reps: 5,
            rpe: 8.0
        )

        // The view queries with intentRaw = "hypertrophy" — strength
        // session must NOT surface. ROUTINE-08 data plumbing.
        let hyperHit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.hypertrophy.rawValue,
            context: ctx
        )
        #expect(hyperHit == nil)

        // Sanity: the strength query DOES see it.
        let strengthHit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(strengthHit?.weight == 185)
    }
}
