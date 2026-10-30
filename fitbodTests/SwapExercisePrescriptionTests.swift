//
//  SwapExercisePrescriptionTests.swift
//  fitbodTests
//
//  Ticket T59 (finding F30). Swapping an exercise mid-workout gives the
//  session exercise the new exercise's prescribed weight, the one a fresh
//  workout start prescribes for it, and clears the "M" (changed from
//  prescription) on the pending sets. Logged sets stay as they were.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SwapExercisePrescription", .serialized)
struct SwapExercisePrescriptionTests {

    /// Every workout here starts on this day, so a swap and a fresh start
    /// prescribe for the same date.
    private let today = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("after a swap, the prescribed weight is what a fresh start prescribes for the new exercise")
    func swapPrescribesLikeAFreshStart() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let freshStart = try freshStartPrescription(of: fx.pressTemplate, in: ctx)
        let workout = try startBenchWorkout(fx, in: ctx)
        try #require(workout.sessionExercise.prescribedWeight != freshStart)

        SwapExerciseSheet.swap(workout.sessionExercise, to: fx.press, context: ctx)

        #expect(workout.sessionExercise.exercise?.id == fx.press.id)
        #expect(workout.sessionExercise.prescribedWeight == freshStart)
        // The swap stays in this workout: the template keeps the bench press.
        #expect(fx.benchTemplate.exercises?.first?.exercise?.id == fx.bench.id)
    }

    @Test("a swap clears the M on pending sets and leaves a logged set as it was")
    func swapClearsPendingMarksOnly() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let workout = try startBenchWorkout(fx, in: ctx)

        SwapExerciseSheet.swap(workout.sessionExercise, to: fx.press, context: ctx)

        // Re-seeded from the overhead press's last workout, and unmarked.
        #expect(workout.typed.weight == 60)
        #expect(workout.typed.wasManualOverride == false)
        let pending = (workout.sessionExercise.sets ?? []).filter { !$0.isComplete }
        #expect(pending.allSatisfy { !$0.wasManualOverride })

        let logged = workout.logged
        #expect(logged.isComplete)
        #expect(logged.weight == 105)
        #expect(logged.reps == 5)
        #expect(logged.rpe == 8)
        #expect(logged.wasManualOverride)
        #expect(logged.completedAt == workout.loggedAt)
    }

    // MARK: - Helpers

    private struct Fixture {
        let bench: Exercise
        let press: Exercise
        let benchTemplate: SessionTemplate
        let pressTemplate: SessionTemplate
    }

    /// The bench workout in progress: its first set logged at 105 x 5 @ 8,
    /// and 110 typed into its second set.
    private struct BenchWorkout {
        let sessionExercise: SessionExercise
        let logged: SetEntry
        let loggedAt: Date
        let typed: SetEntry
    }

    /// A bench press and an overhead press with different histories: one
    /// finished workout each, a week ago, at 100 and at 60. Each has a
    /// one-exercise template with the same targets.
    private func makeFixture(in ctx: ModelContext) throws -> Fixture {
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let press = LoggerFixtures.exercise("OHP", in: ctx)
        let lastWeek = today.addingTimeInterval(-7 * 24 * 3600)
        try LoggerFixtures.session(exercise: bench, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                   sets: [(100, 8, true), (100, 8, true), (100, 8, true)], in: ctx)
        try LoggerFixtures.session(exercise: press, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                   sets: [(60, 8, true), (60, 8, true), (60, 8, true)], in: ctx)
        return Fixture(
            bench: bench,
            press: press,
            benchTemplate: try LoggerFixtures.template("Bench Day", exercises: [bench], in: ctx),
            pressTemplate: try LoggerFixtures.template("Press Day", exercises: [press], in: ctx)
        )
    }

    /// What a fresh workout start prescribes for the template's exercise.
    /// The probe workout is deleted again, so the next one can start.
    private func freshStartPrescription(of template: SessionTemplate, in ctx: ModelContext) throws -> Double {
        let probe = try SessionFactory.start(template: template, on: today, context: ctx)
        let weight = try #require(probe.exercises?.first?.prescribedWeight)
        ctx.delete(probe)
        try ctx.save()
        return weight
    }

    /// Starts the bench workout, logs its first set and types a weight into
    /// its second, which marks that set as changed from the prescription.
    private func startBenchWorkout(_ fx: Fixture, in ctx: ModelContext) throws -> BenchWorkout {
        let session = try SessionFactory.start(template: fx.benchTemplate, on: today, context: ctx)
        let se = try #require(session.exercises?.first)
        let sets = (se.sets ?? []).filter { !$0.isWarmup }.sorted { $0.orderIndex < $1.orderIndex }
        try #require(sets.count == 3)

        let logged = sets[0]
        logged.weight = 105
        logged.reps = 5
        logged.rpe = 8
        logged.wasManualOverride = true
        let loggedAt = today.addingTimeInterval(600)
        try #require(SessionSetActions.complete(logged, at: loggedAt, context: ctx))

        let typed = sets[1]
        typed.weight = 110
        typed.wasManualOverride = true
        try ctx.save()
        return BenchWorkout(sessionExercise: se, logged: logged, loggedAt: loggedAt, typed: typed)
    }
}
