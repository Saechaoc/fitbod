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

    @Test("variation Undo restores the pending inputs it replaced")
    func variationUndoRestoresPendingInputs() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let session = try SessionFactory.start(template: fx.benchTemplate, on: today, context: ctx)
        let exercise = try #require(session.exercises?.first)
        let set = try #require(SessionSetActions.ordered(exercise).first(where: { !$0.isWarmup }))
        set.weight = 112.5
        set.reps = 7
        set.rpe = 8.5
        set.wasManualOverride = true
        try ctx.save()

        let original = VariationUndoSnapshot(exercise)
        SwapExerciseSheet.swap(exercise, to: fx.press, context: ctx)
        try original.restore(to: exercise, context: ctx)

        #expect(exercise.exercise?.id == fx.bench.id)
        #expect(set.weight == 112.5)
        #expect(set.reps == 7)
        #expect(set.rpe == 8.5)
        #expect(set.wasManualOverride)
    }

    @Test("Undo restores full pending metadata, frozen prescription and exact warm-up topology",
          arguments: ["pending", "skipped", "absent", "removed"])
    func variationUndoRestoresCapturedState(warmupMode: String) throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let session = try SessionFactory.start(template: fx.benchTemplate, on: today, context: ctx)
        let exercise = try #require(session.exercises?.first)
        for warmup in (exercise.sets ?? []) where warmup.isWarmup { ctx.delete(warmup) }
        try ctx.save()
        let working = SessionSetActions.ordered(exercise)
        if warmupMode != "absent" {
            for index in 0..<2 {
                let warmup = SetEntry()
                ctx.insert(warmup)
                warmup.sessionExercise = exercise
                warmup.orderIndex = index
                warmup.isWarmup = true
                warmup.setTypeRaw = "warmup"
                warmup.isComplete = warmupMode == "skipped"
            }
        }
        for (index, set) in working.enumerated() {
            set.orderIndex = index + (warmupMode == "absent" ? 0 : 2)
        }
        for (index, set) in SessionSetActions.ordered(exercise).enumerated() {
            set.weight = 112.5
            set.reps = 7
            set.rpe = 8.5
            set.rir = 1
            set.restAfterSeconds = 91 + index
            set.tempoActual = "3-1-1-0"
            set.notes = "Captured row \(index)"
            set.completedAt = today.addingTimeInterval(Double(index) * 30)
            set.partialReps = 2
            set.clusterSubRepsJoined = "3,2,2"
            set.wasManualOverride = true
            if !set.isWarmup { set.setTypeRaw = "rest_pause" }
        }
        exercise.exerciseNameSnapshot = "Frozen bench name"
        exercise.targetSets = 4
        exercise.targetRepsLow = 5
        exercise.targetRepsHigh = 9
        exercise.targetRPE = 9
        exercise.targetRIR = 2
        exercise.prescribedRestSeconds = 149
        exercise.tempo = "4-0-1-0"
        exercise.tracksTempo = true
        exercise.tracksPartialReps = true
        exercise.prescribedWeight = 107.5
        exercise.pinnedNote = "Frozen cue"
        try ctx.save()
        let expectedRows = SessionSetActions.ordered(exercise).map(setValues)
        let expectedPrescription = prescriptionValues(exercise)
        let original = VariationUndoSnapshot(exercise)
        let replacement: Exercise
        if warmupMode == "removed" {
            replacement = Exercise.previewSample(name: "Pushups", equipment: .bodyweight, mechanic: .compound)
            ctx.insert(replacement)
        } else {
            replacement = fx.press
        }
        SwapExerciseSheet.swap(exercise, to: replacement, context: ctx)
        // A second swap would now read different history and settings.
        fx.bench.name = "Renamed catalog bench"
        fx.bench.smallestIncrement = 25
        try LoggerFixtures.session(
            exercise: fx.bench,
            startedAt: today.addingTimeInterval(-86_400),
            completedAt: today.addingTimeInterval(-80_000),
            sets: [(200, 8, true)], in: ctx
        )
        exercise.targetSets = 8
        exercise.targetRPE = 6
        exercise.pinnedNote = "Changed after capture"
        try ctx.save()

        try original.restore(to: exercise, context: ctx)

        #expect(exercise.exercise?.id == fx.bench.id)
        #expect(original.displayName == "Frozen bench name")
        #expect(prescriptionValues(exercise) == expectedPrescription)
        #expect(SessionSetActions.ordered(exercise).map(setValues) == expectedRows)
        #expect(working[0].weight == 112.5 && working[0].reps == 7 && working[0].rpe == 8.5)
        #expect(working[0].wasManualOverride)
        #expect((exercise.sets ?? []).filter(\.isWarmup).allSatisfy { $0.isComplete == (warmupMode == "skipped") })
    }

    @Test("Undo never assigns captured values to an already completed working row")
    func variationUndoLeavesCompletedRowsUntouched() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let workout = try startBenchWorkout(fx, in: ctx)
        let original = VariationUndoSnapshot(workout.sessionExercise)
        SwapExerciseSheet.swap(workout.sessionExercise, to: fx.press, context: ctx)
        workout.logged.notes = "Keep this later note"
        workout.logged.completedAt = workout.loggedAt.addingTimeInterval(30)
        try ctx.save()
        let loggedValues = setValues(workout.logged)

        try original.restore(to: workout.sessionExercise, context: ctx)

        #expect(setValues(workout.logged) == loggedValues)
        #expect(workout.typed.weight == 110 && workout.typed.wasManualOverride)
    }

    @Test("Undo refuses to replace an exercise once a new working set is logged")
    func variationUndoRefusesNewCompletedWorkingRows() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let session = try SessionFactory.start(template: fx.benchTemplate, on: today, context: ctx)
        let exercise = try #require(session.exercises?.first)
        let original = VariationUndoSnapshot(exercise)
        SwapExerciseSheet.swap(exercise, to: fx.press, context: ctx)
        let set = try #require((exercise.sets ?? []).first(where: { !$0.isWarmup }))
        set.reps = 7
        try #require(SessionSetActions.complete(set, at: today, context: ctx))
        let loggedValues = setValues(set)

        #expect(throws: VariationUndoSnapshot.RestoreError.noLongerApplicable) {
            try original.restore(to: exercise, context: ctx)
        }
        #expect(exercise.exercise?.id == fx.press.id)
        #expect(setValues(set) == loggedValues)
    }

    @Test("a failed restoration rolls back the swap state and the same Undo can be retried")
    func variationUndoFailureRollsBackAndCanRetry() throws {
        enum SaveFailure: Error, Equatable { case expected }
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let session = try SessionFactory.start(template: fx.benchTemplate, on: today, context: ctx)
        let exercise = try #require(session.exercises?.first)
        let expected = SessionSetActions.ordered(exercise).map(setValues)
        let original = VariationUndoSnapshot(exercise)
        SwapExerciseSheet.swap(exercise, to: fx.press, context: ctx)
        let swapped = SessionSetActions.ordered(exercise).map(setValues)
        let swappedPrescription = prescriptionValues(exercise)

        #expect(throws: SaveFailure.expected) {
            try original.restore(to: exercise, context: ctx, save: { _ in throw SaveFailure.expected })
        }
        #expect(exercise.exercise?.id == fx.press.id)
        #expect(SessionSetActions.ordered(exercise).map(setValues) == swapped)
        #expect(prescriptionValues(exercise) == swappedPrescription)
        #expect(!ctx.hasChanges)

        try original.restore(to: exercise, context: ctx)
        #expect(exercise.exercise?.id == fx.bench.id)
        #expect(SessionSetActions.ordered(exercise).map(setValues) == expected)
    }

    // MARK: - Helpers

    private func setValues(_ set: SetEntry) -> [AnyHashable] {
        [
            AnyHashable(set.id), AnyHashable(set.orderIndex), AnyHashable(set.weight),
            AnyHashable(set.reps), AnyHashable(set.rpe), AnyHashable(set.rir),
            AnyHashable(set.restAfterSeconds), AnyHashable(set.tempoActual), AnyHashable(set.notes),
            AnyHashable(set.isWarmup), AnyHashable(set.setTypeRaw), AnyHashable(set.completedAt),
            AnyHashable(set.partialReps), AnyHashable(set.clusterSubRepsJoined),
            AnyHashable(set.isComplete), AnyHashable(set.wasManualOverride)
        ]
    }

    private func prescriptionValues(_ exercise: SessionExercise) -> [AnyHashable] {
        [
            AnyHashable(exercise.id), AnyHashable(exercise.orderIndex), AnyHashable(exercise.exerciseNameSnapshot),
            AnyHashable(exercise.targetSets), AnyHashable(exercise.targetRepsLow), AnyHashable(exercise.targetRepsHigh),
            AnyHashable(exercise.targetRPE), AnyHashable(exercise.targetRIR), AnyHashable(exercise.prescribedRestSeconds),
            AnyHashable(exercise.tempo), AnyHashable(exercise.tracksTempo), AnyHashable(exercise.tracksPartialReps),
            AnyHashable(exercise.prescribedWeight), AnyHashable(exercise.pinnedNote)
        ]
    }

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
