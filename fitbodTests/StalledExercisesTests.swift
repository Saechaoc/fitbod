//
//  StalledExercisesTests.swift
//  fitbodTests
//
//  RM-019: the Stalled list on Progress shows each stall the workout's
//  exercise card would show, from finished workouts only: its intent, how
//  many workouts are flat, the newest workout's top set and the card's
//  suggestion. Each intent and each machine is a stream of its own.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Stalled exercises", .serialized)
struct StalledExercisesTests {

    private let day: TimeInterval = 24 * 3600
    private var weeksAgo: Date { Date.now.addingTimeInterval(-21 * day) }

    @Test("a stall lists its intent, flat workouts, newest top set and the card's suggestion")
    func rowShowsTheCardsRead() throws {
        let (ctx, settings) = try context()
        let bench = exercise("Barbell Bench Press", in: ctx)
        // Flat at 100 x 5 while RPE climbs 7, 8, 8.5, 9: creep 1.25 suggests dropping intensity.
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5],
            rpe: [7, 8, 8.5, 9], weekStart: weeksAgo, in: ctx
        )

        let stall = try #require(StalledExercises.find(in: ctx, settings: settings).only)
        #expect(stall.exercise.id == bench.id)
        #expect(stall.intent == .strength)
        #expect(stall.machine == nil)
        #expect(stall.workouts.count == 4)
        #expect(stall.workouts.first?.rpe == 9, "the newest workout's top set comes first")
        #expect(stall.action == .dropIntensity)
        #expect(stall.action == PlateauDetector.suggestedAction(exerciseID: bench.id, intent: .strength, in: ctx, settings: settings))
        #expect(stall.summary(unit: .lb) == "flat 4 workouts · top 100 lb × 5 @ 9")
        #expect(stall.summary(unit: .kg) == "flat 4 workouts · top 100 kg × 5 @ 9", "a unit relabels, never converts")
    }

    @Test("progressing and short streams are not listed, and each intent is its own stream")
    func onlyStalledStreams() throws {
        let (ctx, settings) = try context()
        let bench = exercise("Barbell Bench Press", in: ctx)
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5], weekStart: weeksAgo, in: ctx
        )
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [60, 62.5, 65, 67.5], reps: [10, 10, 10, 10],
            intent: .hypertrophy, weekStart: weeksAgo.addingTimeInterval(4 * day), in: ctx
        )
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [80, 80, 80], reps: [3, 3, 3],
            intent: .power, weekStart: weeksAgo.addingTimeInterval(8 * day), in: ctx
        )

        let stalls = StalledExercises.find(in: ctx, settings: settings)
        #expect(stalls.map(\.intent) == [.strength], "hypertrophy progresses and power has three workouts")
        #expect(stalls.first?.summary(unit: .lb) == "flat 4 workouts · top 100 lb × 5")
    }

    @Test("a workout in progress neither adds a stall nor changes one")
    func workoutInProgressDoesNotCount() throws {
        let (ctx, settings) = try context()
        let bench = exercise("Barbell Bench Press", in: ctx)
        let curl = exercise("Barbell Curl", in: ctx)
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5], weekStart: weeksAgo, in: ctx
        )
        // Today's unfinished workout: a heavier bench set, and the only curls ever logged.
        let today = Session()
        ctx.insert(today)
        today.startedAt = .now
        today.intentRaw = Intent.strength.rawValue
        for (index, (exercise, weight)) in [(bench, 120.0), (curl, 40.0)].enumerated() {
            let log = SessionExercise()
            ctx.insert(log)
            log.session = today
            log.exercise = exercise
            log.orderIndex = index
            let set = SetEntry()
            ctx.insert(set)
            set.sessionExercise = log
            set.weight = weight
            set.reps = 5
            set.setTypeRaw = SetType.working.rawValue
            set.isComplete = true
            set.completedAt = .now
        }
        try ctx.save()

        let stall = try #require(StalledExercises.find(in: ctx, settings: settings).only)
        #expect(stall.exercise.id == bench.id)
        #expect(stall.workouts.first?.weight == 100, "the finished workouts' top set, not today's 120")
    }

    @Test("each machine is its own stream, and the row names it")
    func machinesAreSeparateStreams() throws {
        let (ctx, settings) = try context()
        let hack = exercise("Hack Squat (Machine)", in: ctx)
        let arsenal = MachineProfile()
        ctx.insert(arsenal)
        arsenal.manufacturer = "Arsenal Strength"
        arsenal.model = "Reloaded Linear Hack Squat"
        let flat = try FatigueTestFixtures.weeklySessions(
            forExercise: hack, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5], weekStart: weeksAgo, in: ctx
        )
        for session in flat { session.exercises?.first?.machine = arsenal }
        // Four rising workouts with no machine: their own group, which progresses.
        try FatigueTestFixtures.weeklySessions(
            forExercise: hack, weights: [100, 110, 120, 130], reps: [5, 5, 5, 5],
            weekStart: weeksAgo.addingTimeInterval(4 * day), in: ctx
        )
        try ctx.save()

        let stall = try #require(StalledExercises.find(in: ctx, settings: settings).only)
        #expect(stall.machine?.id == arsenal.id)
        #expect(stall.summary(unit: .lb) == "Arsenal Strength Reloaded Linear Hack Squat · flat 4 workouts · top 100 lb × 5")
    }

    @Test("the exercise's own plateau window sets how many workouts are flat")
    func windowOverrideSetsTheCount() throws {
        let (ctx, settings) = try context()
        let squat = exercise("Barbell Squat", in: ctx)
        squat.plateauWindowOverride = 5
        try FatigueTestFixtures.weeklySessions(
            forExercise: squat, weights: [140, 140, 140, 140, 140, 140], reps: [3, 3, 3, 3, 3, 3],
            weekStart: weeksAgo, in: ctx
        )

        let stall = try #require(StalledExercises.find(in: ctx, settings: settings).only)
        #expect(stall.workouts.count == 5)
        #expect(stall.summary(unit: .lb).hasPrefix("flat 5 workouts"))
    }

    @Test("an exercise's chart reads only its own stalls")
    func oneExercisesStalls() throws {
        let (ctx, settings) = try context()
        let bench = exercise("Barbell Bench Press", in: ctx)
        let squat = exercise("Barbell Squat", in: ctx)
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5], weekStart: weeksAgo, in: ctx
        )
        try FatigueTestFixtures.weeklySessions(
            forExercise: squat, weights: [140, 140, 140, 140], reps: [3, 3, 3, 3], weekStart: weeksAgo, in: ctx
        )

        #expect(StalledExercises.find(in: ctx, settings: settings).count == 2)
        #expect(StalledExercises.find(in: ctx, settings: settings, exerciseID: squat.id).map(\.exercise.id) == [squat.id])
    }

    @Test("the list runs newest stall first, in sections by intent in the legend's order")
    func orderAndSections() throws {
        let (ctx, settings) = try context()
        let bench = exercise("Barbell Bench Press", in: ctx)
        let squat = exercise("Barbell Squat", in: ctx)
        let curl = exercise("Barbell Curl", in: ctx)
        // Strength: the bench stalled longest ago, the squat most recently.
        try FatigueTestFixtures.weeklySessions(
            forExercise: bench, weights: [100, 100, 100, 100], reps: [5, 5, 5, 5],
            weekStart: weeksAgo.addingTimeInterval(-14 * day), in: ctx
        )
        try FatigueTestFixtures.weeklySessions(
            forExercise: squat, weights: [140, 140, 140, 140], reps: [3, 3, 3, 3], weekStart: weeksAgo, in: ctx
        )
        try FatigueTestFixtures.weeklySessions(
            forExercise: curl, weights: [30, 30, 30, 30], reps: [8, 8, 8, 8],
            intent: .hypertrophy, weekStart: weeksAgo.addingTimeInterval(-7 * day), in: ctx
        )

        let stalls = StalledExercises.find(in: ctx, settings: settings)
        #expect(stalls.map(\.exercise.name) == ["Barbell Squat", "Barbell Curl", "Barbell Bench Press"])
        let sections = StalledExercises.sections(stalls)
        #expect(sections.map(\.intent) == [.hypertrophy, .strength])
        #expect(sections.last?.stalls.map(\.exercise.name) == ["Barbell Squat", "Barbell Bench Press"])
    }

    // MARK: - Helpers

    private func context() throws -> (ModelContext, UserSettings) {
        let ctx = try FatigueTestFixtures.makeContext()
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()
        return (ctx, settings)
    }

    /// An exercise with no muscles, so no volume target fires ADD VOLUME.
    private func exercise(_ name: String, in ctx: ModelContext) -> Exercise {
        let exercise = Exercise()
        exercise.name = name
        exercise.canonicalName = name.lowercased()
        ctx.insert(exercise)
        return exercise
    }
}

private extension Array {
    /// The one element, or nil when there are none or several.
    var only: Element? { count == 1 ? first : nil }
}
