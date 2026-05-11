//
//  ActiveSessionConflictTests.swift
//  fitbodTests
//
//  Pins the RESEARCH §6 Pitfall 7 "one active session at a time"
//  invariant from the perspective of `RoutinesListView.handleStartTap`.
//  The view itself is a SwiftUI body and exercising its tap handler
//  inside a hermetic test harness is brittle; instead these tests pin
//  the `SessionFactory.start(...)` contract that `handleStartTap`
//  delegates to. The view code path that surfaces the UI-SPEC alert is
//  source-pinned via `RoutinesListCopyTests`.
//
//  Four test functions:
//
//    1. firstStartSucceeds — no prior active session → start succeeds
//       and returns a Session with `completedAt == nil`.
//    2. secondStartThrowsActiveSessionAlreadyExists — calling start
//       twice without finishing the first throws the typed error that
//       `RoutinesListView` translates into the "Workout in Progress"
//       alert.
//    3. startAfterFinishingPriorSessionSucceeds — finishing the prior
//       session (setting `completedAt`) un-blocks the next start.
//    4. startAfterDiscardingPriorSessionSucceeds — discarding the prior
//       session (deleting it) un-blocks the next start. This is the
//       "Discard" button code path in the conflict alert.
//
//  Mirrors the test fixture shape used by `SessionFactoryTests`:
//  per-test in-memory `ModelContainer` built against `Schema(SchemaV2.models)`
//  + `FitbodSchemaMigrationPlan` so the production wiring is exercised
//  literally.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ActiveSessionConflict", .serialized)
struct ActiveSessionConflictTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Builds a one-exercise Routine — the minimum shape SessionFactory
    /// will accept (it throws `routineHasNoExercises` for empty routines).
    @discardableResult
    private func makeRoutine(ctx: ModelContext, name: String = "Test") throws -> Routine {
        let routine = Routine()
        routine.name = name
        ctx.insert(routine)

        let ex = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(ex)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = ex
        re.orderIndex = 0
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.intentRaw = Intent.strength.rawValue
        ctx.insert(re)

        try ctx.save()
        return routine
    }

    // MARK: - 1. first start succeeds (no prior active session)

    @Test("firstStartSucceeds — no active session exists → start returns a Session with completedAt == nil")
    func firstStartSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        #expect(session.completedAt == nil)
        #expect(SessionFactory.active(in: ctx)?.id == session.id)
    }

    // MARK: - 2. second start throws while first is still active

    @Test("secondStartThrowsActiveSessionAlreadyExists — RESEARCH §6 Pitfall 7")
    func secondStartThrowsActiveSessionAlreadyExists() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        _ = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        do {
            _ = try SessionFactory.start(routine: routine, on: .now, context: ctx)
            Issue.record("Expected activeSessionAlreadyExists, but start returned a Session")
        } catch SessionFactoryError.activeSessionAlreadyExists {
            // expected — this is the error code that RoutinesListView's
            // `handleStartTap` catches and translates into the
            // "Workout in Progress" alert.
        } catch {
            Issue.record("Expected activeSessionAlreadyExists; got \(error)")
        }
    }

    // MARK: - 3. finishing prior unblocks next start

    @Test("startAfterFinishingPriorSessionSucceeds — finished sessions don't count as active")
    func startAfterFinishingPriorSessionSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        let first = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        first.completedAt = .now
        try ctx.save()

        let second = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        #expect(second.id != first.id)
        #expect(second.completedAt == nil)
    }

    // MARK: - 4. discarding prior unblocks next start (the "Discard" branch)

    @Test("startAfterDiscardingPriorSessionSucceeds — discard branch of the conflict alert")
    func startAfterDiscardingPriorSessionSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        let first = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        // Simulate the "Discard" button in the "Workout in Progress"
        // alert — `RoutinesListView` invokes `ctx.delete(active)` +
        // `ctx.save()` and then re-tap on Start Workout should succeed.
        ctx.delete(first)
        try ctx.save()
        #expect(SessionFactory.active(in: ctx) == nil)

        let second = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        #expect(second.completedAt == nil)
    }
}
