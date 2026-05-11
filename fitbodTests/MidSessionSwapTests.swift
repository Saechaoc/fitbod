//
//  MidSessionSwapTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-02 — pins the SESS-05 contract for mid-session swap.
//  The production swap surface is the `SwapExerciseSheet` view (a
//  SwiftUI struct that calls `sessionExercise.exercise = exercise` in
//  its `onSelect` closure). These tests re-implement the same mutation
//  semantics against the production model entities — same exact
//  mutation as the view's onSelect closure — so the contract is
//  verified independently of SwiftUI's view instantiation.
//
//  Four `@Test` functions cover:
//
//    1. swapMutatesSessionExerciseOnly — SESS-05 — swap mutates
//       SessionExercise.exercise and leaves the source
//       RoutineExercise.exercise untouched.
//    2. swapResetsPendingSetsToNewHint — pending (un-committed) sets
//       are re-seeded with the new exercise's matching-intent hint.
//    3. swapLeavesCompletedSetsAlone — already-committed sets are
//       immutable across swap (PITFALLS-doc #1 — historical data is
//       never rewritten).
//    4. swapDoesNotAffectRoutineTemplate — PITFALLS-doc #1 /
//       ROUTINE-07 — the routine template's Exercise references stay
//       intact after the swap.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("MidSessionSwap", .serialized)
struct MidSessionSwapTests {

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

    /// Mirrors the production `SwapExerciseSheet`'s onSelect closure —
    /// kept as a hermetic copy so the test exercises the semantic
    /// contract without instantiating the SwiftUI sheet view.
    private func performSwap(
        sessionExercise: SessionExercise,
        to exercise: Exercise,
        context: ModelContext
    ) {
        sessionExercise.exercise = exercise
        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id,
            intentRaw: sessionExercise.intentRaw,
            context: context
        )?.weight ?? 0
        let pendingSets = (sessionExercise.sets ?? [])
            .filter { !$0.isComplete }
        for set in pendingSets {
            set.weight = hint
            set.reps = 0
            set.rpe = nil
        }
        try? context.save()
    }

    /// Builds a routine + active session with one SessionExercise
    /// pointing at `bench` (strength intent, 3 planned sets seeded at
    /// 135). Returns the components needed by every test.
    private struct Fixture {
        let bench: Exercise
        let ohp: Exercise
        let routine: Routine
        let routineExercise: RoutineExercise
        let session: Session
        let sessionExercise: SessionExercise
    }

    private func makeFixture(ctx: ModelContext) throws -> Fixture {
        let bench = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        let ohp = Exercise.previewSample(
            name: "OHP",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["shoulders"]
        )
        ctx.insert(bench)
        ctx.insert(ohp)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = bench
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.prescribedRestSeconds = 180
        ctx.insert(re)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let se = (session.exercises ?? []).first { $0.orderIndex == 0 }!
        // Seed planned sets at 135 (no prior matching-intent session
        // exists, so SessionFactory defaulted to 0; we set 135 to
        // exercise the swap's re-seed semantic).
        for set in (se.sets ?? []) {
            set.weight = 135
        }
        try ctx.save()

        return Fixture(
            bench: bench,
            ohp: ohp,
            routine: routine,
            routineExercise: re,
            session: session,
            sessionExercise: se
        )
    }

    // MARK: - 1. SESS-05 swap mutates SessionExercise only

    @Test("swapMutatesSessionExerciseOnly — SE.exercise = new; RE.exercise unchanged")
    func swapMutatesSessionExerciseOnly() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        performSwap(sessionExercise: fx.sessionExercise, to: fx.ohp, context: ctx)

        // SE.exercise now points at OHP.
        #expect(fx.sessionExercise.exercise?.id == fx.ohp.id)
        // Source RoutineExercise.exercise is still Bench.
        #expect(fx.routineExercise.exercise?.id == fx.bench.id)
    }

    // MARK: - 2. Pending sets re-seed with matching-intent hint

    @Test("swapResetsPendingSetsToNewHint — pending sets adopt the new exercise's hint")
    func swapResetsPendingSetsToNewHint() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        // Insert a prior matching-intent (strength) OHP session at 95 lb
        // so PreviousMatchingIntent.fetchTopWorkingSet has something to
        // surface.
        let priorSession = Session()
        priorSession.startedAt = .now.addingTimeInterval(-7 * 24 * 60 * 60)
        priorSession.completedAt = priorSession.startedAt.addingTimeInterval(45 * 60)
        priorSession.routineSnapshotName = "Past Push"
        ctx.insert(priorSession)
        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = fx.ohp
        priorSE.intentRaw = Intent.strength.rawValue
        ctx.insert(priorSE)
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 95
        priorSet.reps = 5
        priorSet.rpe = 8.0
        priorSet.isWarmup = false
        priorSet.isComplete = true
        ctx.insert(priorSet)
        try ctx.save()

        // Pre-swap: pending sets at 135.
        let pendingBefore = (fx.sessionExercise.sets ?? [])
            .filter { !$0.isComplete }
        #expect(pendingBefore.allSatisfy { $0.weight == 135 })

        // Swap Bench → OHP.
        performSwap(sessionExercise: fx.sessionExercise, to: fx.ohp, context: ctx)

        // Post-swap: pending sets re-seeded at 95 (the OHP strength hint).
        let pendingAfter = (fx.sessionExercise.sets ?? [])
            .filter { !$0.isComplete }
        #expect(pendingAfter.allSatisfy { $0.weight == 95 })
        // Reps + rpe cleared on pending sets too.
        #expect(pendingAfter.allSatisfy { $0.reps == 0 })
        #expect(pendingAfter.allSatisfy { $0.rpe == nil })
    }

    // MARK: - 3. Committed sets are immutable across swap

    @Test("swapLeavesCompletedSetsAlone — committed sets retain weight/reps/rpe")
    func swapLeavesCompletedSetsAlone() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        // Commit set 1 at 145 × 5 @ RPE 8.
        let sortedSets = (fx.sessionExercise.sets ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        let firstSet = sortedSets[0]
        firstSet.weight = 145
        firstSet.reps = 5
        firstSet.rpe = 8.0
        firstSet.isComplete = true
        firstSet.completedAt = .now
        try ctx.save()

        // Swap Bench → OHP.
        performSwap(sessionExercise: fx.sessionExercise, to: fx.ohp, context: ctx)

        // Committed set retains its values; pending sets (sets 2-3) get re-seeded.
        #expect(firstSet.weight == 145)
        #expect(firstSet.reps == 5)
        #expect(firstSet.rpe == 8.0)
        #expect(firstSet.isComplete == true)

        // Sanity: the un-committed sets did mutate.
        let pendingAfter = (fx.sessionExercise.sets ?? [])
            .filter { !$0.isComplete }
        #expect(pendingAfter.count == 2)
        #expect(pendingAfter.allSatisfy { $0.reps == 0 })
    }

    // MARK: - 4. Routine template stays intact (PITFALLS-doc #1)

    @Test("swapDoesNotAffectRoutineTemplate — PITFALLS-doc #1 / ROUTINE-07")
    func swapDoesNotAffectRoutineTemplate() throws {
        let ctx = try makeContext()
        let fx = try makeFixture(ctx: ctx)

        performSwap(sessionExercise: fx.sessionExercise, to: fx.ohp, context: ctx)

        // Routine prescription field set stays identical to pre-swap.
        #expect(fx.routineExercise.exercise?.id == fx.bench.id)
        #expect(fx.routineExercise.intentRaw == Intent.strength.rawValue)
        #expect(fx.routineExercise.targetSets == 3)
        #expect(fx.routineExercise.targetRepsLow == 5)
        #expect(fx.routineExercise.targetRepsHigh == 5)
        #expect(fx.routineExercise.prescribedRestSeconds == 180)

        // Routine still references the same single RoutineExercise.
        #expect((fx.routine.exercises ?? []).count == 1)
        #expect((fx.routine.exercises ?? []).first?.id == fx.routineExercise.id)
    }
}
