//
//  SwapWarmupTests.swift
//  fitbodTests
//
//  Ticket T75 (findings F64 and F66). Swapping an exercise mid-workout
//  replaces its warm-up ramp with the one a workout start would build for
//  the new exercise from its new prescribed weight, or removes it when the
//  new exercise would get none. A swap never adds a ramp to an exercise
//  that had none.
//
//  Ticket T88 (finding F99). SKIP WARM-UPS is the only way to complete a
//  warm-up, so a swap rebuilds skipped warm-ups as well as pending ones,
//  and the rebuilt ramp stays skipped: UNDO brings back the new
//  exercise's ramp, not the old one's.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SwapWarmup", .serialized)
struct SwapWarmupTests {

    /// Every workout here starts on this day.
    private let today = Date(timeIntervalSince1970: 1_800_000_000)

    /// The barbell inventory every workout loads: a 20 kg bar and the
    /// default kg plates.
    private let bar = 20.0
    private var plates: [(weight: Double, countPerSide: Int)] {
        PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)
            .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
    }

    @Test("a swap to push-ups removes the warm-up ramp, pending or skipped", arguments: [false, true])
    func swapToPushUpsRemovesRamp(skipped: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        try #require(pendingWarmups(of: bench).count == 4)
        if skipped {
            try markWarmups(of: bench, complete: true, in: ctx)
        }

        SwapExerciseSheet.swap(bench, to: fx.pushUps, context: ctx)

        #expect(warmups(of: bench).isEmpty)
        // The working sets move up to the top, numbered from 0.
        #expect(SessionSetActions.ordered(bench).map(\.orderIndex) == [0, 1, 2])
    }

    @Test("a swap to another barbell compound rebuilds the ramp from its new prescribed weight")
    func swapToBarbellCompoundRebuildsRamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench

        SwapExerciseSheet.swap(bench, to: fx.squat, context: ctx)

        let top = try #require(bench.prescribedWeight)
        let ramp = WarmupRamp.generate(top: top, bar: bar, plates: plates, isUnilateral: false)
        let rebuilt = pendingWarmups(of: bench)
        #expect(rebuilt.map(\.weight) == ramp.map(\.weight))
        #expect(rebuilt.map(\.reps) == ramp.map(\.reps))
        // The working sets follow the ramp, re-seeded from the squat's last workout.
        #expect(SessionSetActions.ordered(bench).map(\.orderIndex) == Array(0..<7))
        let working = (bench.sets ?? []).filter { !$0.isWarmup }
        #expect(working.allSatisfy { $0.weight == 140 && $0.reps == 0 })
    }

    @Test("a swap never adds a ramp to an exercise that had none")
    func swapNeverAddsARamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let row = try startWorkout(fx, in: ctx).row
        try #require((row.sets ?? []).allSatisfy { !$0.isWarmup })

        SwapExerciseSheet.swap(row, to: fx.squat, context: ctx)

        #expect((row.sets ?? []).allSatisfy { !$0.isWarmup })
    }

    @Test("skipped warm-ups are rebuilt for the new exercise and stay skipped, so UNDO brings back its ramp")
    func swapRebuildsSkippedWarmups() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        // SKIP WARM-UPS
        try markWarmups(of: bench, complete: true, in: ctx)

        SwapExerciseSheet.swap(bench, to: fx.squat, context: ctx)

        #expect(!warmups(of: bench).isEmpty)
        #expect(warmups(of: bench).allSatisfy { $0.isComplete })
        // UNDO
        try markWarmups(of: bench, complete: false, in: ctx)
        let top = try #require(bench.prescribedWeight)
        let ramp = WarmupRamp.generate(top: top, bar: bar, plates: plates, isUnilateral: false)
        let restored = pendingWarmups(of: bench)
        #expect(restored.map(\.weight) == ramp.map(\.weight))
        #expect(restored.map(\.reps) == ramp.map(\.reps))
        #expect(SessionSetActions.ordered(bench).map(\.orderIndex) == Array(0..<7))
    }

    @Test("a ramp only partly done is rebuilt in full, still to do")
    func swapRebuildsPartlyDoneRampToDo() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        let done = try #require(warmups(of: bench).first)
        done.isComplete = true
        try ctx.save()

        SwapExerciseSheet.swap(bench, to: fx.squat, context: ctx)

        let top = try #require(bench.prescribedWeight)
        let ramp = WarmupRamp.generate(top: top, bar: bar, plates: plates, isUnilateral: false)
        let rebuilt = warmups(of: bench)
        #expect(rebuilt.map(\.weight) == ramp.map(\.weight))
        #expect(rebuilt.map(\.reps) == ramp.map(\.reps))
        // Only a ramp skipped in full shows as skipped, so the card keeps a ramp to do.
        #expect(rebuilt.allSatisfy { !$0.isComplete })
        #expect(SessionSetActions.ordered(bench).map(\.orderIndex) == Array(0..<7))
    }

    // MARK: - Helpers

    private struct Fixture {
        let template: SessionTemplate
        let squat: Exercise
        let pushUps: Exercise
    }

    /// A template of a barbell bench press then a barbell row, each with a
    /// finished workout a week ago, so a start gives the bench press the
    /// workout's warm-up ramp and the row none. The swap targets are a
    /// barbell squat last done at 140 and push-ups never done.
    private func makeFixture(in ctx: ModelContext) throws -> Fixture {
        let inventory = PlateInventory()
        ctx.insert(inventory)
        inventory.equipmentKind = .barbell
        inventory.barWeight = bar
        inventory.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)

        let bench = LoggerFixtures.exercise("Barbell Bench Press", in: ctx)
        let row = LoggerFixtures.exercise("Barbell Row", in: ctx)
        let squat = LoggerFixtures.exercise("Barbell Squat", in: ctx)
        let pushUps = Exercise.previewSample(name: "Pushups", equipment: .bodyweight, mechanic: .compound)
        ctx.insert(pushUps)

        let lastWeek = today.addingTimeInterval(-7 * 24 * 3600)
        for (exercise, weight) in [(bench, 100.0), (row, 80.0), (squat, 140.0)] {
            try LoggerFixtures.session(exercise: exercise, startedAt: lastWeek, completedAt: lastWeek.addingTimeInterval(3600),
                                       sets: [(weight, 5, true), (weight, 5, true), (weight, 5, true)], in: ctx)
        }
        return Fixture(
            template: try LoggerFixtures.template("Press & Pull", exercises: [bench, row], in: ctx),
            squat: squat,
            pushUps: pushUps
        )
    }

    /// Starts the workout and returns its two exercises.
    private func startWorkout(
        _ fx: Fixture,
        in ctx: ModelContext
    ) throws -> (bench: SessionExercise, row: SessionExercise) {
        let session = try SessionFactory.start(template: fx.template, on: today, context: ctx)
        let exercises = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        try #require(exercises.count == 2)
        return (exercises[0], exercises[1])
    }

    private func warmups(of sessionExercise: SessionExercise) -> [SetEntry] {
        SessionSetActions.ordered(sessionExercise).filter(\.isWarmup)
    }

    private func pendingWarmups(of sessionExercise: SessionExercise) -> [SetEntry] {
        warmups(of: sessionExercise).filter { !$0.isComplete }
    }

    /// What SKIP WARM-UPS (`complete: true`) and UNDO (`complete: false`)
    /// do on the card: flip every warm-up at once.
    private func markWarmups(of sessionExercise: SessionExercise, complete: Bool, in ctx: ModelContext) throws {
        for warmup in warmups(of: sessionExercise) {
            warmup.isComplete = complete
        }
        try ctx.save()
    }
}
