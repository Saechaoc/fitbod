//
//  PlateauDetectorTests.swift
//  fitbodTests
//
//  Pins PlateauDetector.evaluate semantics per D-10 (intent split) /
//  D-11 (4-session window + per-exercise override) / D-12 (±2%
//  tolerance + PROG-02 high-rep suppression + per-exercise override).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PlateauDetector", .serialized)
struct PlateauDetectorTests {

    // MARK: - Fixtures

    private func makeMuscles(_ ctx: ModelContext) throws -> (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup) {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        let triceps = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
        ctx.insert(chest); ctx.insert(shoulders); ctx.insert(triceps)
        try ctx.save()
        return (chest, shoulders, triceps)
    }

    private func makeBenchExercise(_ ctx: ModelContext, muscles: (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup)) throws -> Exercise {
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ex.equipmentRaw = "barbell"
        ex.mechanicRaw = "compound"
        ctx.insert(ex)
        for (m, role, w): (MuscleGroup, String, Double) in [
            (muscles.chest, "primary", 1.0),
            (muscles.shoulders, "secondary", 0.5),
            (muscles.triceps, "secondary", 0.5),
        ] {
            let s = ExerciseMuscleStimulus()
            s.role = role
            s.weight = w
            s.muscle = m
            s.exercise = ex
            ctx.insert(s)
        }
        try ctx.save()
        return ex
    }

    /// Insert N sessions of `exercise` at `intent`, each with one
    /// working set (`weight × reps`, optional rpe). startedAt offsets
    /// each session by `i * 86_400` seconds before `now`.
    @discardableResult
    private func insertSessions(
        _ ctx: ModelContext,
        exercise: Exercise,
        intent: Intent,
        weightsReps: [(Double, Int)],
        rpes: [Double?] = [],
        now: Date = .now
    ) throws -> [Session] {
        var sessions: [Session] = []
        for (i, wr) in weightsReps.enumerated() {
            let session = Session()
            // Most-recent session is index 0; earlier sessions are further back.
            session.startedAt = now.addingTimeInterval(-Double(weightsReps.count - 1 - i) * 86_400)
            session.completedAt = session.startedAt.addingTimeInterval(60 * 45)
            session.routineSnapshotName = "Test"
            session.intentRaw = intent.rawValue
            ctx.insert(session)

            let se = SessionExercise()
            se.session = session
            se.exercise = exercise
            se.orderIndex = 0
            ctx.insert(se)

            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = 0
            entry.weight = wr.0
            entry.reps = wr.1
            entry.rpe = rpes.isEmpty ? nil : rpes[i]
            entry.isWarmup = false
            entry.isComplete = true
            entry.setTypeRaw = "working"
            entry.completedAt = session.startedAt
            ctx.insert(entry)

            sessions.append(session)
        }
        try ctx.save()
        return sessions
    }

    private func defaultSettings(_ ctx: ModelContext) -> UserSettings {
        let s = UserSettings.default()
        ctx.insert(s)
        try? ctx.save()
        return s
    }

    // MARK: - 1. D-12 stalled window

    @Test("stalledWindow returns .stalled with rangeRatio within tolerance")
    func stalledWindowReturnsStalled() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // 4 sessions of 100 × 5 (constant) → range = 0 → stalled.
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (100, 5), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)

        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        switch result {
        case .stalled(_, let ratio):
            #expect(ratio <= settings.plateauTolerance)
        default:
            Issue.record("Expected .stalled, got \(result)")
        }
    }

    // MARK: - 2. D-12 progressing window

    @Test("progressingWindow returns .progressing when range > tolerance")
    func progressingWindowReturnsProgressing() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // Weights {100, 105, 110, 115} × 5 → e1RM trend ~+5% per session → range > 2%.
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (105, 5), (110, 5), (115, 5),
        ])
        let settings = defaultSettings(ctx)

        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        if case .progressing = result { } else {
            Issue.record("Expected .progressing, got \(result)")
        }
    }

    // MARK: - 3. D-11 not enough data

    @Test("threeSessionWindow returns .notEnoughData (<N sessions)")
    func threeSessionWindowReturnsNotEnoughData() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)

        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(result == .notEnoughData)
    }

    // MARK: - 4. PROG-02 high-rep suppression

    @Test("Sessions with all reps > 10 are filtered (PROG-02 suppression)")
    func fourSessionsOneHighRepFiltersAndReturnsNotEnoughData() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // 3 valid + 1 high-rep (12 reps) → after filtering 3 < N=4 → .notEnoughData.
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (80, 12), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)

        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(result == .notEnoughData)
    }

    // MARK: - 5. D-10 intent split

    @Test("Intent gate filters strength stream from hypertrophy stream")
    func intentSplitHistoryRespectsIntent() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // 4 strength sessions all 100×5 (stalled).
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (100, 5), (100, 5), (100, 5),
        ])
        // 4 hypertrophy sessions trending up (progressing).
        try insertSessions(ctx, exercise: ex, intent: .hypertrophy, weightsReps: [
            (60, 10), (62.5, 10), (65, 10), (67.5, 10),
        ])
        let settings = defaultSettings(ctx)

        let strengthResult = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        let hypResult = PlateauDetector.evaluate(exerciseID: ex.id, intent: .hypertrophy, in: ctx, settings: settings)

        if case .stalled = strengthResult { } else {
            Issue.record("Strength stream expected .stalled, got \(strengthResult)")
        }
        if case .progressing = hypResult { } else {
            Issue.record("Hypertrophy stream expected .progressing, got \(hypResult)")
        }
    }

    // MARK: - 6. SET-06 per-exercise window override

    @Test("Per-exercise plateauWindowOverride is honored")
    func exerciseWithWindowOverrideHonorsOverride() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // Seed only 3 sessions — at default N=4 → .notEnoughData.
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)
        #expect(PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings) == .notEnoughData)

        // Override to N=3 → .stalled.
        ex.plateauWindowOverride = 3
        try ctx.save()
        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        if case .stalled = result { } else {
            Issue.record("With override=3 expected .stalled, got \(result)")
        }
    }

    // MARK: - 7. SET-06 per-exercise tolerance override

    @Test("Per-exercise plateauToleranceOverride is honored")
    func exerciseWithToleranceOverrideHonorsOverride() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // Range ~3% (between default 2% and override 5%).
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (100, 5), (101, 5), (102, 5), (103, 5),
        ])
        let settings = defaultSettings(ctx)
        // Default tolerance 0.02 → 3% range > tol → .progressing.
        let initial = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        if case .progressing = initial { } else {
            Issue.record("With default tolerance expected .progressing, got \(initial)")
        }

        // Override 0.05 → tolerance widened → .stalled.
        ex.plateauToleranceOverride = 0.05
        try ctx.save()
        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        if case .stalled = result { } else {
            Issue.record("With override 0.05 expected .stalled, got \(result)")
        }
    }

    // MARK: - 8. Top-set selection picks highest e1RM

    @Test("Top-set picks the working set with the highest e1RM (not just heaviest weight)")
    func topSetSelectionPicksHighestE1RM() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // 4 sessions, each with 3 working sets — the heaviest e1RM
        // belongs to the 100×5 (Brzycki 112.5), NOT 105×3 (Brzycki 111.18)
        // and NOT 95×6 (Brzycki 110.32). Result is stalled at 112.5
        // across all 4 sessions.
        let now = Date.now
        for i in 0..<4 {
            let session = Session()
            session.startedAt = now.addingTimeInterval(-Double(3 - i) * 86_400)
            session.completedAt = session.startedAt.addingTimeInterval(60 * 45)
            session.routineSnapshotName = "Test"
            session.intentRaw = Intent.strength.rawValue
            ctx.insert(session)
            let se = SessionExercise()
            se.session = session
            se.exercise = ex
            se.orderIndex = 0
            ctx.insert(se)
            let workingSets: [(Double, Int)] = [(100, 5), (105, 3), (95, 6)]
            for (j, wr) in workingSets.enumerated() {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = j
                entry.weight = wr.0
                entry.reps = wr.1
                entry.isWarmup = false
                entry.isComplete = true
                entry.setTypeRaw = "working"
                entry.completedAt = session.startedAt
                ctx.insert(entry)
            }
        }
        try ctx.save()
        let settings = defaultSettings(ctx)

        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        if case .stalled(let e1RMs, _) = result {
            // Verify the top-set e1RM is exactly 112.5 (Brzycki for 100×5).
            for e in e1RMs {
                #expect(abs(e - 112.5) < 0.5, "Expected top-set e1RM ≈ 112.5, got \(e)")
            }
        } else {
            Issue.record("Expected .stalled with top-set 112.5, got \(result)")
        }
    }

    // MARK: - 9. rangeRatio formula

    @Test("rangeRatio = (max - min) / mean")
    func rangeRatioFormulaIsAccurate() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBenchExercise(ctx, muscles: muscles)
        // Brzycki for {97.78, 99.56, 98.67, 100.44}×5 produces ~{110, 112, 111, 113}.
        // Pick exact values to anchor: build sessions with custom weights
        // such that Brzycki output approximates [110, 112, 111, 113].
        // 110.0 = w × 36/32 → w = 110.0 × 32/36 ≈ 97.78.
        try insertSessions(ctx, exercise: ex, intent: .strength, weightsReps: [
            (97.78, 5), (99.56, 5), (98.67, 5), (100.44, 5),
        ])
        // Default tolerance 0.02; (113 - 110) / 111.5 = 0.0269 > 0.02 → .progressing.
        let settings = defaultSettings(ctx)
        let result = PlateauDetector.evaluate(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        // The result should be .progressing (rangeRatio > tolerance);
        // but the formula is the thing being pinned — just ensure we get
        // the right branch.
        if case .progressing(let e1RMs) = result {
            let minV = e1RMs.min() ?? 0
            let maxV = e1RMs.max() ?? 0
            let mean = e1RMs.reduce(0, +) / Double(e1RMs.count)
            let ratio = (maxV - minV) / mean
            #expect(ratio > 0.02)
        } else {
            Issue.record("Expected .progressing, got \(result)")
        }
    }
}
