//
//  FrequencyHitsTests.swift
//  fitbodTests
//
//  Pins FatigueModel.frequencyHits per D-03: a session "counts as a
//  frequency hit" for a muscle when the stimulus-weighted set
//  contribution to that muscle is ≥ minContribution (default 2.0).
//  A single 0.5 indirect contribution does NOT count.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("FrequencyHits", .serialized)
struct FrequencyHitsTests {

    // MARK: - Helpers

    private func mondayOfThisWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return cal.date(from: comps) ?? .now
    }

    @discardableResult
    private func seedMuscles(_ ctx: ModelContext) throws -> (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup, biceps: MuscleGroup) {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        let triceps = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
        let biceps = MuscleGroup(slug: "biceps", displayName: "Biceps", region: .upper)
        for m in [chest, shoulders, triceps, biceps] { ctx.insert(m) }
        try ctx.save()
        return (chest, shoulders, triceps, biceps)
    }

    private func makeBenchPress(in ctx: ModelContext, muscles: (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup, biceps: MuscleGroup)) throws -> Exercise {
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ctx.insert(ex)
        // chest 1.0 primary, shoulders 0.5 secondary, triceps 0.5 secondary
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

    @discardableResult
    private func makeSession(
        in ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        sets: [(Double, Int, Bool, Bool, String)]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(60 * 45)
        session.routineSnapshotName = "Test"
        session.intentRaw = Intent.strength.rawValue
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.orderIndex = 0
        ctx.insert(se)

        for (i, tup) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = tup.0
            entry.reps = tup.1
            entry.isWarmup = tup.2
            entry.isComplete = tup.3
            entry.setTypeRaw = tup.4
            entry.completedAt = startedAt
            ctx.insert(entry)
        }
        try ctx.save()
        return session
    }

    // MARK: - 1. Two sessions, each with full chest volume → 2 hits

    @Test("Two sessions each with 3 chest sets count as 2 frequency hits on chest")
    func twoSessionsEachWithFullChestVolumeCountAsTwoHits() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedMuscles(ctx)
        let ex = try makeBenchPress(in: ctx, muscles: muscles)
        let monday = mondayOfThisWeek()
        // Two sessions on different days this week.
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])
        try makeSession(in: ctx, startedAt: monday.addingTimeInterval(3 * 86_400), exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        let hits = FatigueModel.frequencyHits(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(hits == 2)
    }

    // MARK: - 2. D-03 anchor — single indirect 0.5 contribution does NOT count

    @Test("A single 0.5 indirect contribution does NOT count as a frequency hit (D-03)")
    func singleIndirectContributionDoesNotCountAsHit() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedMuscles(ctx)
        let ex = try makeBenchPress(in: ctx, muscles: muscles)
        let monday = mondayOfThisWeek()
        // One session with a single set → 0.5 contribution to triceps
        // (single secondary, 0.5 weighted) — should NOT hit threshold 2.0.
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
        ])

        let hits = FatigueModel.frequencyHits(muscleSlug: "triceps", weekStart: monday, in: ctx)
        #expect(hits == 0)
    }

    // MARK: - 3. Multiple indirect 0.5 contributions ADD UP to a hit

    @Test("Four 0.5-weighted indirect sets in one session add to 2.0 and count as 1 hit")
    func multipleIndirectAddUpToHit() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedMuscles(ctx)
        let ex = try makeBenchPress(in: ctx, muscles: muscles)
        let monday = mondayOfThisWeek()
        // One session with 4 bench-press sets → 4 × 0.5 = 2.0 contribution
        // to triceps → meets threshold → 1 hit.
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        let hits = FatigueModel.frequencyHits(muscleSlug: "triceps", weekStart: monday, in: ctx)
        #expect(hits == 1)
    }

    // MARK: - 4. Custom minContribution threshold

    @Test("Custom minContribution threshold flexes the hit count")
    func customMinContributionThreshold() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedMuscles(ctx)
        let ex = try makeBenchPress(in: ctx, muscles: muscles)
        let monday = mondayOfThisWeek()
        // One session with 2 sets → 2.0 chest direct + 1.0 triceps indirect.
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        // At default 2.0: chest 2.0 ≥ 2.0 → 1 hit; triceps 1.0 < 2.0 → 0 hits.
        #expect(FatigueModel.frequencyHits(muscleSlug: "chest",   weekStart: monday, in: ctx) == 1)
        #expect(FatigueModel.frequencyHits(muscleSlug: "triceps", weekStart: monday, in: ctx) == 0)

        // At 0.5: triceps 1.0 ≥ 0.5 → 1 hit.
        #expect(FatigueModel.frequencyHits(muscleSlug: "triceps", weekStart: monday, minContribution: 0.5, in: ctx) == 1)
        // At 3.0: chest 2.0 < 3.0 → 0 hits.
        #expect(FatigueModel.frequencyHits(muscleSlug: "chest", weekStart: monday, minContribution: 3.0, in: ctx) == 0)
    }

    // MARK: - 5. Sessions in a different week do not count

    @Test("Sessions logged last week do NOT count for this week's frequency hits")
    func sessionsAcrossDifferentWeeksDoNotCount() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedMuscles(ctx)
        let ex = try makeBenchPress(in: ctx, muscles: muscles)
        let monday = mondayOfThisWeek()
        let priorMonday = monday.addingTimeInterval(-7 * 86_400)
        try makeSession(in: ctx, startedAt: priorMonday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        let hits = FatigueModel.frequencyHits(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(hits == 0)
    }
}
