//
//  OneSamplePerWorkoutTests.swift
//  fitbodTests
//
//  The plateau check, its RPE-creep check and the deload advisor's
//  RPE-creep signal (Sig-2) take one sample per finished workout. A
//  workout that logs the exercise twice gives one top set, picked across
//  both logs, so it takes one place in a window.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("OneSamplePerWorkout", .serialized)
struct OneSamplePerWorkoutTests {

    /// The deload advisor's week; Sig-2 reads the three weeks before it.
    private let weekStart = Date.now

    // MARK: - Plateau check

    @Test("a workout that logs the exercise twice takes one place in the plateau window")
    func plateauWindowCountsWorkoutOnce() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        ex.plateauWindowOverride = 3
        try ctx.save()
        // Two finished workouts with flat 100 x 5 top sets; the newer logs the bench twice.
        try insertWorkout(ex, daysAgo: 4, logs: [(100, 5, nil)], in: ctx)
        try insertWorkout(ex, daysAgo: 2, logs: [(100, 5, nil), (100, 5, nil)], in: ctx)

        let signal = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(signal == .notEnoughData)
    }

    @Test("a workout that logs the exercise twice gives its top set across both logs")
    func plateauSampleIsTopSetAcrossLogs() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        ex.plateauWindowOverride = 3
        try ctx.save()
        // Three workouts at 100 x 5 (e1RM 112.5). The newest logs the bench
        // first at 95 x 5 (106.875), then at 100 x 5, so its sample is 112.5.
        try insertWorkout(ex, daysAgo: 6, logs: [(100, 5, nil)], in: ctx)
        try insertWorkout(ex, daysAgo: 4, logs: [(100, 5, nil)], in: ctx)
        try insertWorkout(ex, daysAgo: 2, logs: [(95, 5, nil), (100, 5, nil)], in: ctx)

        let signal = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(signal == .stalled(e1RMs: [112.5, 112.5, 112.5], rangeRatio: 0))
    }

    @Test("the plateau RPE-creep check counts a workout that logs the exercise twice once")
    func plateauRPECreepCountsWorkoutOnce() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // Four workouts stalled at 100 x 5 with RPE 8, 7, 7, 8.5, oldest
        // first: a creep of 0.25. The newest logs the bench twice; counted
        // twice, it would push the oldest out and read 7, 7, 8.5, 8.5.
        try insertWorkout(ex, daysAgo: 8, logs: [(100, 5, 8)], in: ctx)
        try insertWorkout(ex, daysAgo: 6, logs: [(100, 5, 7)], in: ctx)
        try insertWorkout(ex, daysAgo: 4, logs: [(100, 5, 7)], in: ctx)
        try insertWorkout(ex, daysAgo: 2, logs: [(100, 5, 8.5), (100, 5, 8.5)], in: ctx)

        let signal = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(signal == .stalled(e1RMs: [112.5, 112.5, 112.5, 112.5], rangeRatio: 0))
        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .tryVariation)
    }

    // MARK: - Deload advisor Sig-2

    @Test("the deload advisor's RPE creep counts a workout that logs the exercise twice once")
    func deloadRPECreepCountsWorkoutOnce() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // Two workouts in the last three weeks at 100 x 5 while RPE rises
        // from 7 to 8.5; the newer logs the bench twice. Two workouts are
        // fewer than the three sessions Sig-2 compares.
        try insertWorkout(ex, daysAgo: 9, logs: [(100, 5, 7)], in: ctx)
        try insertWorkout(ex, daysAgo: 2, logs: [(100, 5, 8.5), (100, 5, 8.5)], in: ctx)

        let report = DeloadAdvisor.signalReport(weekStart: weekStart, in: ctx, settings: settings)
        #expect(report.sig2_rpeCreep == nil)
        let hasSig2 = report.firedSignals.contains { signal in
            if case .rpeCreep = signal { return true } else { return false }
        }
        #expect(!hasSig2)
    }

    @Test("the deload advisor's RPE creep reads a workout's top set across every log")
    func deloadRPECreepUsesTopSetAcrossLogs() throws {
        let (ctx, ex, settings) = try benchWithSettings()
        // Three workouts at 100 x 5 while RPE climbs 7, 8, 9: a creep of 2.
        // The newest logs a lighter 90 x 5 at RPE 7 first; its top set is
        // still the 100 x 5 at RPE 9.
        try insertWorkout(ex, daysAgo: 9, logs: [(100, 5, 7)], in: ctx)
        try insertWorkout(ex, daysAgo: 5, logs: [(100, 5, 8)], in: ctx)
        try insertWorkout(ex, daysAgo: 2, logs: [(90, 5, 7), (100, 5, 9)], in: ctx)

        let report = DeloadAdvisor.signalReport(weekStart: weekStart, in: ctx, settings: settings)
        #expect(report.sig2_rpeCreep == 2)
        #expect(report.firedSignals.contains(.rpeCreep(amount: 2, exerciseName: "Barbell Bench Press", intent: .strength)))
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double?)

    /// A bench press with no muscle targets, so the plateau check's volume
    /// branch never fires and its RPE-creep check alone decides between
    /// .dropIntensity and the .tryVariation default.
    private func benchWithSettings() throws -> (ModelContext, Exercise, UserSettings) {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ctx.insert(ex)
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()
        return (ctx, ex, settings)
    }

    /// A finished strength workout started `daysAgo` days before
    /// `weekStart` that logs `exercise` once per entry of `logs`, in that
    /// order, each log holding one working set.
    private func insertWorkout(
        _ exercise: Exercise,
        daysAgo: Int,
        logs: [LoggedSet],
        in ctx: ModelContext
    ) throws {
        let session = Session()
        ctx.insert(session)
        session.startedAt = weekStart.addingTimeInterval(-Double(daysAgo) * 86_400)
        session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
        session.routineSnapshotName = "Test"
        session.intentRaw = Intent.strength.rawValue

        for (index, log) in logs.enumerated() {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = exercise
            se.targetSets = 1
            se.orderIndex = index

            let entry = SetEntry()
            ctx.insert(entry)
            entry.sessionExercise = se
            entry.orderIndex = 0
            entry.weight = log.weight
            entry.reps = log.reps
            entry.rpe = log.rpe
            entry.setTypeRaw = SetType.working.rawValue
            entry.isWarmup = false
            entry.isComplete = true
            entry.completedAt = session.startedAt
        }
        try ctx.save()
    }
}
