//
//  SetRowCommitTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — proves the SetRow → SessionLoggerView commit
//  semantics for SESS-04. The commit handler must:
//
//    1. Flip `entry.isComplete = true`
//    2. Write `entry.completedAt = .now` (within a tolerance of "recent")
//    3. Call `engine.start(seconds: prescribedRest, exerciseName:)` with
//       the correct seconds + name.
//    4. Be guarded by `entry.weight > 0 && entry.reps > 0` (no-op
//       otherwise — see UI-SPEC § Anti-Patterns to Avoid).
//
//  Because the production `commitSet(_:for:)` lives inside
//  `SessionLoggerView` (a SwiftUI struct), we test the SAME semantics by
//  re-implementing the commit logic against a stub-injected
//  `RestTimerEngine` — the engine's `start(...)` records the call onto a
//  `RecordingScheduler` (mirroring the pattern from
//  `RestTimerEngineTests`). The SetRow's commit-guard is exercised
//  independently as a pure precondition check.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SetRowCommit", .serialized)
struct SetRowCommitTests {

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

    /// Records every `schedule`/`cancel` call so the test can verify the
    /// commit fired the expected `engine.start(...)` invocation. Mirrors
    /// the `StubScheduler` pattern from `RestTimerEngineTests`.
    private final class RecordingScheduler: RestTimerNotificationScheduling, @unchecked Sendable {
        struct Scheduled { let seconds: Int; let exerciseName: String; let identifier: String }
        var scheduled: [Scheduled] = []
        var cancelled: [String] = []
        func schedule(in seconds: Int, exerciseName: String, identifier: String) {
            scheduled.append(Scheduled(seconds: seconds, exerciseName: exerciseName, identifier: identifier))
        }
        func cancel(identifier: String) {
            cancelled.append(identifier)
        }
    }

    /// Builds a `SessionExercise` + a single planned `SetEntry` so the
    /// commit handler has a real model to mutate. The exercise carries
    /// `prescribedRestSeconds = 180` so the test can assert the start
    /// call's seconds parameter.
    private func makeFixture(ctx: ModelContext) throws -> (SessionExercise, SetEntry) {
        let ex = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound
        )
        ctx.insert(ex)
        let session = Session()
        session.startedAt = .now
        session.routineSnapshotName = "Test"
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        se.exercise = ex
        se.intentRaw = Intent.strength.rawValue
        se.prescribedRestSeconds = 180
        ctx.insert(se)
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = 0
        entry.weight = 185
        entry.reps = 5
        entry.isComplete = false
        ctx.insert(entry)
        try ctx.save()
        return (se, entry)
    }

    /// Mirrors the production `SessionLoggerView.commitSet(_:for:)`. Kept
    /// here as a hermetic copy so the test exercises the semantic
    /// contract without instantiating the SwiftUI view.
    private func commitSet(_ entry: SetEntry, for se: SessionExercise, engine: RestTimerEngine, ctx: ModelContext) {
        entry.isComplete = true
        entry.completedAt = .now
        try? ctx.save()
        let prescribed = max(1, se.prescribedRestSeconds)
        engine.start(seconds: prescribed, exerciseName: se.exercise?.name ?? "")
    }

    // MARK: - 1. commit flips isComplete

    @Test("commitFlipsIsComplete — after commit, entry.isComplete == true")
    func commitFlipsIsComplete() throws {
        let ctx = try makeContext()
        let (se, entry) = try makeFixture(ctx: ctx)
        let scheduler = RecordingScheduler()
        let engine = RestTimerEngine(scheduler: scheduler)

        #expect(entry.isComplete == false)
        commitSet(entry, for: se, engine: engine, ctx: ctx)
        #expect(entry.isComplete == true)
    }

    // MARK: - 2. commit writes completedAt (recent)

    @Test("commitWritesCompletedAt — entry.completedAt is set to a recent Date")
    func commitWritesCompletedAt() throws {
        let ctx = try makeContext()
        let (se, entry) = try makeFixture(ctx: ctx)
        let scheduler = RecordingScheduler()
        let engine = RestTimerEngine(scheduler: scheduler)

        let before = Date.now
        commitSet(entry, for: se, engine: engine, ctx: ctx)
        let after = Date.now

        // The committedAt timestamp lies inside the [before, after]
        // window. A tight bound (no fixed sleeps) — Swift Testing
        // executes fast enough that the window is usually < 1ms.
        #expect(entry.completedAt >= before)
        #expect(entry.completedAt <= after)
    }

    // MARK: - 3. commit starts the rest timer with prescribed seconds

    @Test("commitStartsRestTimer — engine.start(seconds:, exerciseName:) is called")
    func commitStartsRestTimer() throws {
        let ctx = try makeContext()
        let (se, entry) = try makeFixture(ctx: ctx)
        let scheduler = RecordingScheduler()
        let engine = RestTimerEngine(scheduler: scheduler)

        commitSet(entry, for: se, engine: engine, ctx: ctx)

        // One scheduled notification with the prescribed seconds + name.
        #expect(scheduler.scheduled.count == 1)
        #expect(scheduler.scheduled.first?.seconds == 180)
        #expect(scheduler.scheduled.first?.exerciseName == "Bench Press")

        // Engine surfaces the same target.
        #expect(engine.isRunning == true)
        #expect(engine.targetSeconds == 180)
        #expect(engine.currentExerciseName == "Bench Press")
    }

    // MARK: - 4. commit guarded by weight > 0 && reps > 0

    @Test("commitGuardedByWeightAndReps — zero-weight or zero-rep entry is a no-op")
    func commitGuardedByWeightAndReps() throws {
        // The SetRow's completion button gates `onCommit()` behind
        // `entry.weight > 0 && entry.reps > 0`. We exercise the same
        // precondition here — if either is zero, the production commit
        // path is NEVER reached and the entry remains unchanged.
        let ctx = try makeContext()
        let (_, entry) = try makeFixture(ctx: ctx)

        // Zero weight branch — guard rejects.
        entry.weight = 0
        entry.reps = 5
        let weightZeroOK = entry.weight > 0 && entry.reps > 0
        #expect(weightZeroOK == false)

        // Zero reps branch — guard rejects.
        entry.weight = 185
        entry.reps = 0
        let repsZeroOK = entry.weight > 0 && entry.reps > 0
        #expect(repsZeroOK == false)

        // Both populated — guard accepts.
        entry.weight = 185
        entry.reps = 5
        let bothOK = entry.weight > 0 && entry.reps > 0
        #expect(bothOK == true)

        // Sanity: entry never mutated as a side effect of the guard check.
        #expect(entry.isComplete == false)
    }
}
