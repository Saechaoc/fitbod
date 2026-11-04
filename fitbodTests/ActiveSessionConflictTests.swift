//
//  ActiveSessionConflictTests.swift
//  fitbodTests
//
//  Pins the RESEARCH §6 Pitfall 7 "one active session at a time"
//  invariant at the `SessionFactory.start(...)` contract that
//  `WorkoutStarter.start` delegates to.
//
//  Four test functions:
//
//    1. firstStartSucceeds — no prior active session → start succeeds
//       and returns a Session with `completedAt == nil`.
//    2. secondStartThrowsActiveSessionAlreadyExists — calling start
//       twice without finishing the first throws the typed error that
//       `WorkoutStarter.start` turns into `.alreadyInProgress`.
//    3. startAfterFinishingPriorSessionSucceeds — finishing the prior
//       session (setting `completedAt`) un-blocks the next start.
//    4. startAfterDiscardingPriorSessionSucceeds — discarding the prior
//       session (deleting it) un-blocks the next start, as discarding
//       an in-progress workout does.
//
//  Mirrors the test fixture shape used by `SessionFactoryTests`:
//  per-test in-memory `ModelContainer` built against FitbodModelContainer.make(inMemory: true)
//  + `FitbodModelContainer.make` so the production wiring is exercised
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
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// Builds a one-exercise SessionTemplate — the minimum shape SessionFactory
    /// will accept (it throws `routineHasNoExercises` for empty templates).
    @discardableResult
    private func makeRoutine(ctx: ModelContext, name: String = "Test") throws -> SessionTemplate {
        let routine = SessionTemplate()
        routine.name = name
        // Phase 3.1 (PIVOT-01): intent + progression live on SessionTemplate.
        routine.intentRaw = Intent.strength.rawValue
        ctx.insert(routine)

        let ex = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(ex)

        let re = SessionExerciseTemplate()
        re.sessionTemplate = routine
        re.exercise = ex
        re.orderIndex = 0
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        ctx.insert(re)

        try ctx.save()
        return routine
    }

    // MARK: - 1. first start succeeds (no prior active session)

    @Test("firstStartSucceeds — no active session exists → start returns a Session with completedAt == nil")
    func firstStartSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)

        let session = try SessionFactory.start(template: routine, on: .now, context: ctx)
        #expect(session.completedAt == nil)
        #expect(SessionFactory.active(in: ctx)?.id == session.id)
    }

    // MARK: - 2. second start throws while first is still active

    @Test("secondStartThrowsActiveSessionAlreadyExists — RESEARCH §6 Pitfall 7")
    func secondStartThrowsActiveSessionAlreadyExists() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        _ = try SessionFactory.start(template: routine, on: .now, context: ctx)

        do {
            _ = try SessionFactory.start(template: routine, on: .now, context: ctx)
            Issue.record("Expected activeSessionAlreadyExists, but start returned a Session")
        } catch SessionFactoryError.activeSessionAlreadyExists {
            // expected — `WorkoutStarter.start` turns this into
            // `.alreadyInProgress`.
        } catch {
            Issue.record("Expected activeSessionAlreadyExists; got \(error)")
        }
    }

    // MARK: - 3. finishing prior unblocks next start

    @Test("startAfterFinishingPriorSessionSucceeds — finished sessions don't count as active")
    func startAfterFinishingPriorSessionSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        let first = try SessionFactory.start(template: routine, on: .now, context: ctx)
        first.completedAt = .now
        try ctx.save()

        let second = try SessionFactory.start(template: routine, on: .now, context: ctx)
        #expect(second.id != first.id)
        #expect(second.completedAt == nil)
    }

    // MARK: - 4. discarding prior unblocks next start (the "Discard" branch)

    @Test("startAfterDiscardingPriorSessionSucceeds — discard branch of the conflict alert")
    func startAfterDiscardingPriorSessionSucceeds() throws {
        let ctx = try makeContext()
        let routine = try makeRoutine(ctx: ctx)
        let first = try SessionFactory.start(template: routine, on: .now, context: ctx)

        // Discard the in-progress workout; the next start succeeds.
        ctx.delete(first)
        try ctx.save()
        #expect(SessionFactory.active(in: ctx) == nil)

        let second = try SessionFactory.start(template: routine, on: .now, context: ctx)
        #expect(second.completedAt == nil)
    }
}
