//
//  AddUnplannedExerciseTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-02 — pins the SESS-06 contract for the bottom-of-
//  session "+ Add Exercise" affordance. Each test calls the production
//  `AddUnplannedExerciseButton.append(exercise:to:context:)` against an
//  in-memory store, so the contract is verified without instantiating
//  the SwiftUI sheet.
//
//  Four `@Test` functions cover:
//
//    1. appendsSessionExerciseToActiveSession — SESS-06 — a new SE row
//       lands on `session.exercises` with orderIndex past the existing
//       count.
//    2. doesNotMutateSourceRoutine — PITFALLS-doc #1 — appending to a
//       session never touches the source Routine.exercises.
//    3. seedsThreeDefaultSetsWithMatchingIntentHint — three planned
//       SetEntry rows materialize with weight = PreviousMatchingIntent
//       hint (or 0 if no prior matching session exists).
//    4. addedExercisePrescribesLikeAFreshStart — ticket T76 (finding
//       F65) — the added exercise gets the prescribed weight a fresh
//       workout start gives it.
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
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// Active session + routine with one existing exercise. Returns the
    /// new exercise (curl) that the tests will append.
    private struct Fixture {
        let routine: SessionTemplate
        let routineExercise: SessionExerciseTemplate
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

        let routine = SessionTemplate()
        routine.name = "Push"
        // Phase 3.1 (PIVOT-01): intent + progression live on SessionTemplate.
        // Snapshots onto Session at SessionFactory.start.
        routine.intentRaw = Intent.strength.rawValue
        routine.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(routine)

        let re = SessionExerciseTemplate()
        re.sessionTemplate = routine
        re.exercise = bench
        re.orderIndex = 0
        re.targetSets = 3
        ctx.insert(re)
        try ctx.save()

        let session = try SessionFactory.start(template: routine, on: .now, context: ctx)

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

        AddUnplannedExerciseButton.append(exercise: fx.curl, to: fx.session, context: ctx)

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

        AddUnplannedExerciseButton.append(exercise: fx.curl, to: fx.session, context: ctx)

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

        // Phase 3.1 (PIVOT-02): the active session inherits .strength
        // from the fixture's routine. The unplanned curl looks up its
        // hint via session.intentRaw (.strength) — so seed a prior
        // STRENGTH curl session for the hint to surface.
        let priorSession = Session()
        priorSession.startedAt = .now.addingTimeInterval(-7 * 24 * 60 * 60)
        priorSession.completedAt = priorSession.startedAt.addingTimeInterval(30 * 60)
        priorSession.routineSnapshotName = "Past Pull"
        priorSession.intentRaw = Intent.strength.rawValue
        ctx.insert(priorSession)
        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = fx.curl
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

        AddUnplannedExerciseButton.append(exercise: fx.curl, to: fx.session, context: ctx)

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

        // Defaulted prescription on the new SessionExercise: 90s rest
        // (dumbbell isolation) + 8-12 reps. Intent + progression are
        // session-level now (PIVOT-02) — assert via the parent Session.
        #expect(newSE.session?.intentRaw == Intent.strength.rawValue)
        #expect(newSE.targetSets == 3)
        #expect(newSE.targetRepsLow == 8)
        #expect(newSE.targetRepsHigh == 12)
        #expect(newSE.prescribedRestSeconds == 90)
    }

    // MARK: - 4. T76 — the added exercise gets its prescription

    @Test("addedExercisePrescribesLikeAFreshStart — prescribedWeight is what a fresh start prescribes")
    func addedExercisePrescribesLikeAFreshStart() throws {
        let ctx = try LoggerFixtures.makeContext()
        // Both workouts start on this day, so they prescribe for the same date.
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let press = LoggerFixtures.exercise("OHP", in: ctx)
        // The press's last workout hit 12 reps, the top of an added
        // exercise's 8-12, on every set, so double progression adds an
        // increment to its 60.
        let lastWeek = today.addingTimeInterval(-7 * 24 * 3600)
        try LoggerFixtures.session(exercise: press, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                   sets: [(60, 12, true), (60, 12, true), (60, 12, true)], in: ctx)

        // What a fresh start prescribes for the press at an added
        // exercise's targets. The probe workout is deleted again, so the
        // next one can start.
        let pressTemplate = try LoggerFixtures.template("Press Day", exercises: [press], repsLow: 8, repsHigh: 12, in: ctx)
        let probe = try SessionFactory.start(template: pressTemplate, on: today, context: ctx)
        let freshStart = try #require(probe.exercises?.first?.prescribedWeight)
        ctx.delete(probe)
        try ctx.save()
        try #require(freshStart > 60)

        let benchTemplate = try LoggerFixtures.template("Bench Day", exercises: [bench], in: ctx)
        let session = try SessionFactory.start(template: benchTemplate, on: today, context: ctx)

        AddUnplannedExerciseButton.append(exercise: press, to: session, context: ctx)

        let added = try #require(session.exercises?.first { $0.exercise?.id == press.id })
        #expect(added.prescribedWeight == freshStart)
        // The planned sets are still seeded from the last workout.
        let sets = added.sets ?? []
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.weight == 60 })
    }
}
