//
//  SwapWarmupTests.swift
//  fitbodTests
//
//  Ticket T75 (findings F64 and F66). Swapping an exercise mid-workout
//  replaces its pending warm-up ramp with the one a workout start would
//  build for the new exercise from its new prescribed weight, or removes
//  it when the new exercise would get none. A swap never adds a ramp to
//  an exercise that had none, and warm-ups already done stay as they were.
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

    @Test("a swap to push-ups removes the pending warm-up ramp")
    func swapToPushUpsRemovesRamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        try #require(pendingWarmups(of: bench).count == 4)

        SwapExerciseSheet.swap(bench, to: fx.pushUps, context: ctx)

        #expect(pendingWarmups(of: bench).isEmpty)
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

    @Test("skipped warm-ups stay as they were, and no ramp is added")
    func swapKeepsSkippedWarmups() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        // SKIP WARM-UPS marks every warm-up done.
        let skipped = warmups(of: bench)
        for warmup in skipped { warmup.isComplete = true }
        try ctx.save()
        let before = skipped.map(Row.init)

        SwapExerciseSheet.swap(bench, to: fx.squat, context: ctx)

        #expect(warmups(of: bench).map(Row.init) == before)
    }

    @Test("a warm-up already done stays as it was, ahead of the rebuilt ramp")
    func swapKeepsDoneWarmupAheadOfRebuiltRamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        let fx = try makeFixture(in: ctx)
        let bench = try startWorkout(fx, in: ctx).bench
        let done = try #require(warmups(of: bench).first)
        done.isComplete = true
        try ctx.save()
        let before = Row(done)

        SwapExerciseSheet.swap(bench, to: fx.squat, context: ctx)

        let top = try #require(bench.prescribedWeight)
        let ramp = WarmupRamp.generate(top: top, bar: bar, plates: plates, isUnilateral: false)
        #expect(warmups(of: bench).first.map(Row.init) == before)
        let rebuilt = pendingWarmups(of: bench)
        #expect(rebuilt.map(\.weight) == ramp.map(\.weight))
        #expect(rebuilt.map(\.reps) == ramp.map(\.reps))
        #expect(SessionSetActions.ordered(bench).map(\.orderIndex) == Array(0..<8))
    }

    // MARK: - Helpers

    private struct Fixture {
        let template: SessionTemplate
        let squat: Exercise
        let pushUps: Exercise
    }

    /// One set as stored, to show a warm-up stayed as it was.
    private struct Row: Equatable {
        let id: UUID
        let orderIndex: Int
        let weight: Double
        let reps: Int
        let isComplete: Bool

        init(_ entry: SetEntry) {
            id = entry.id
            orderIndex = entry.orderIndex
            weight = entry.weight
            reps = entry.reps
            isComplete = entry.isComplete
        }
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
}
