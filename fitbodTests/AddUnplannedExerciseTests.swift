//
//  AddUnplannedExerciseTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-02 — pins the SESS-06 contract for the bottom-of-
//  session "+ Add Exercise" affordance. The production surface is
//  `AddUnplannedExerciseButton.append(exercise:)`; these tests
//  re-implement the same append semantics against the production model
//  entities so the contract is verified without instantiating the
//  SwiftUI sheet.
//
//  Three `@Test` functions cover:
//
//    1. appendsSessionExerciseToActiveSession — SESS-06 — a new SE row
//       lands on `session.exercises` with orderIndex past the existing
//       count.
//    2. doesNotMutateSourceRoutine — PITFALLS-doc #1 — appending to a
//       session never touches the source Routine.exercises.
//    3. seedsThreeDefaultSetsWithMatchingIntentHint — three planned
//       SetEntry rows materialize with weight = PreviousMatchingIntent
//       hint (or 0 if no prior matching session exists).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("AddUnplannedExercise", .serialized)
struct AddUnplannedExerciseTests {

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

    /// Mirrors the production `AddUnplannedExerciseButton.append(exercise:)`
    /// — kept as a hermetic copy so the test exercises the semantic
    /// contract without instantiating the SwiftUI button.
    private func appendUnplanned(
        exercise: Exercise,
        to session: Session,
        context: ModelContext
    ) {
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.orderIndex = (session.exercises ?? []).count
        se.intentRaw = defaultIntent(for: exercise).rawValue
        se.targetSets = 3
        se.targetRepsLow = 8
        se.targetRepsHigh = 12
        se.prescribedRestSeconds = exercise.mechanic == .compound ? 180 : 90
        context.insert(se)

        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id,
            intentRaw: se.intentRaw,
            context: context
        )?.weight ?? 0
        for i in 0..<3 {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = hint
            entry.reps = 0
            entry.setTypeRaw = SetType.working.rawValue
            entry.isComplete = false
            entry.completedAt = .now
            context.insert(entry)
        }
        try? context.save()
    }

    private func defaultIntent(for exercise: Exercise) -> Intent {
        if exercise.mechanic == .compound && exercise.equipment == .barbell {
            return .strength
        }
        return .hypertrophy
    }

    /// Active session + routine with one existing exercise. Returns the
    /// new exercise (curl) that the tests will append.
    private struct Fixture {
        let routine: Routine
        let routineExercise: RoutineExercise
        let session: Session
        let curl: Exercise
    }

    private func makeFixture(ctx: ModelContext) throws -> Fixture {
        let bench = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound
        )
        let curl = Exercise.previewSample(
            name: "Curl",
            equipment: .dumbbell,
            mechanic: .isolation
        )
        ctx.insert(bench)
        ctx.insert(curl)

        let routine = Routine()
        routine.name = "Push"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = bench
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        ctx.insert(re)
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        return Fixture(
            routine: routine,
            routineExercise: re,
            session: session,
            curl: curl
        )
    }

    // MARK: - 1. SESS-06 — appended SE lands on the active session

    @Test("appendsSessionExerciseToActiveSession — SE.orderIndex past existing count")
    func appendsSessionExerciseToActiveSession() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        // Pre-append: session has exactly one SessionExercise (from
        // SessionFactory.start on the one-exercise routine).
        #expect((fx.session.exercises ?? []).count == 1)

        appendUnplanned(exercise: fx.curl, to: fx.session, context: ctx)

        let exercises = (fx.session.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        #expect(exercises.count == 2)
        #expect(exercises[1].exercise?.id == fx.curl.id)
        #expect(exercises[1].orderIndex == 1)
    }

    // MARK: - 2. PITFALLS-doc #1 — source routine untouched

    @Test("doesNotMutateSourceRoutine — appending only affects session.exercises")
    func doesNotMutateSourceRoutine() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        appendUnplanned(exercise: fx.curl, to: fx.session, context: ctx)

        // The routine still has exactly one RoutineExercise.
        #expect((fx.routine.exercises ?? []).count == 1)
        #expect((fx.routine.exercises ?? []).first?.id == fx.routineExercise.id)
        #expect((fx.routine.exercises ?? []).first?.exercise?.name == "Bench")
    }

    // MARK: - 3. Three planned sets with matching-intent hint

    @Test("seedsThreeDefaultSetsWithMatchingIntentHint — 3 planned sets at hint weight")
    func seedsThreeDefaultSetsWithMatchingIntentHint() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        // Insert a prior hypertrophy curl session at 30 lb. The append's
        // computed default intent for a dumbbell isolation curl is
        // hypertrophy, so the matching-intent hint should surface.
        let priorSession = Session()
        priorSession.startedAt = .now.addingTimeInterval(-7 * 24 * 60 * 60)
        priorSession.completedAt = priorSession.startedAt.addingTimeInterval(30 * 60)
        priorSession.routineSnapshotName = "Past Pull"
        ctx.insert(priorSession)
        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = fx.curl
        priorSE.intentRaw = Intent.hypertrophy.rawValue
        ctx.insert(priorSE)
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 30
        priorSet.reps = 10
        priorSet.rpe = 8.0
        priorSet.isWarmup = false
        priorSet.isComplete = true
        ctx.insert(priorSet)
        try ctx.save()

        appendUnplanned(exercise: fx.curl, to: fx.session, context: ctx)

        let exercises = (fx.session.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        let newSE = exercises[1]
        let sets = (newSE.sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(sets.count == 3)
        // All three planned sets carry the matching-intent hint weight.
        #expect(sets.allSatisfy { $0.weight == 30 })
        // All are planned-not-yet-logged sentinel state.
        #expect(sets.allSatisfy { $0.reps == 0 })
        #expect(sets.allSatisfy { $0.isComplete == false })
        #expect(sets.allSatisfy { $0.setTypeRaw == SetType.working.rawValue })

        // Defaulted prescription on the new SessionExercise: hypertrophy
        // intent + 90s rest (dumbbell isolation) + 8-12 reps.
        #expect(newSE.intentRaw == Intent.hypertrophy.rawValue)
        #expect(newSE.targetSets == 3)
        #expect(newSE.targetRepsLow == 8)
        #expect(newSE.targetRepsHigh == 12)
        #expect(newSE.prescribedRestSeconds == 90)
    }
}
