//
//  SuggestedActionTests.swift
//  fitbodTests
//
//  Pins PlateauDetector.suggestedAction's D-13 4-branch decision tree
//  + the no-stall short-circuit + branch priority.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SuggestedAction", .serialized)
struct SuggestedActionTests {

    // MARK: - Fixtures

    private func makeMuscles(_ ctx: ModelContext) throws -> (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup) {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        let triceps = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
        ctx.insert(chest); ctx.insert(shoulders); ctx.insert(triceps)
        try ctx.save()
        return (chest, shoulders, triceps)
    }

    private func makeBench(_ ctx: ModelContext, muscles: (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup)) throws -> Exercise {
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ctx.insert(ex)
        for (m, role, w): (MuscleGroup, String, Double) in [
            (muscles.chest, "primary", 1.0),
            (muscles.shoulders, "secondary", 0.5),
            (muscles.triceps, "secondary", 0.5),
        ] {
            let s = ExerciseMuscleStimulus()
            s.role = role; s.weight = w; s.muscle = m; s.exercise = ex
            ctx.insert(s)
        }
        try ctx.save()
        return ex
    }

    /// Insert a chest MuscleVolumeTarget with the given MAV.
    @discardableResult
    private func insertChestTarget(_ ctx: ModelContext, muscle: MuscleGroup, mav: Int = 16) throws -> MuscleVolumeTarget {
        let t = MuscleVolumeTarget()
        t.muscle = muscle
        t.mev = 8
        t.mav = mav
        t.mrv = 22
        t.mv = 6
        ctx.insert(t)
        try ctx.save()
        return t
    }

    /// Helper to put 4 stalled bench-press sessions WITHIN the current
    /// week so weeklyVolume on chest sees them.
    private func insertStalledSessionsThisWeek(
        _ ctx: ModelContext,
        ex: Exercise,
        rpes: [Double?] = [nil, nil, nil, nil],
        sessionsCount: Int = 4,
        weight: Double = 100,
        reps: Int = 5
    ) throws {
        // Anchor all sessions to today (current week — Monday midnight).
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let monday = cal.date(from: comps) ?? .now
        for i in 0..<sessionsCount {
            let session = Session()
            session.startedAt = monday.addingTimeInterval(Double(i) * 3600)  // staggered hours apart
            session.completedAt = session.startedAt.addingTimeInterval(60 * 45)
            session.routineSnapshotName = "Test"
            session.intentRaw = Intent.strength.rawValue
            ctx.insert(session)

            let se = SessionExercise()
            se.session = session
            se.exercise = ex
            se.orderIndex = 0
            ctx.insert(se)

            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = 0
            entry.weight = weight
            entry.reps = reps
            entry.rpe = rpes[i]
            entry.isWarmup = false
            entry.isComplete = true
            entry.setTypeRaw = "working"
            entry.completedAt = session.startedAt
            ctx.insert(entry)
        }
        try ctx.save()
    }

    private func defaultSettings(_ ctx: ModelContext) -> UserSettings {
        let s = UserSettings.default()
        ctx.insert(s)
        try? ctx.save()
        return s
    }

    // MARK: - 1. notEnoughData → nil

    @Test(".notEnoughData yields nil suggested action")
    func notEnoughDataReturnsNilAction() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        try insertStalledSessionsThisWeek(ctx, ex: ex, sessionsCount: 3)  // <N=4
        let settings = defaultSettings(ctx)
        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == nil)
    }

    // MARK: - 2. progressing → nil

    @Test(".progressing yields nil suggested action")
    func progressingReturnsNilAction() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        // Big weight jumps → .progressing.
        var cal = Calendar.current
        cal.firstWeekday = 2
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now
        for (i, weight) in [100.0, 105.0, 110.0, 115.0].enumerated() {
            let session = Session()
            session.startedAt = monday.addingTimeInterval(Double(i) * 3600)
            session.completedAt = session.startedAt.addingTimeInterval(60 * 45)
            session.routineSnapshotName = "Test"
            session.intentRaw = Intent.strength.rawValue
            ctx.insert(session)
            let se = SessionExercise()
            se.session = session; se.exercise = ex; se.orderIndex = 0
            ctx.insert(se)
            let entry = SetEntry()
            entry.sessionExercise = se; entry.orderIndex = 0
            entry.weight = weight; entry.reps = 5
            entry.isWarmup = false; entry.isComplete = true
            entry.setTypeRaw = "working"; entry.completedAt = session.startedAt
            ctx.insert(entry)
        }
        try ctx.save()
        let settings = defaultSettings(ctx)
        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == nil)
    }

    // MARK: - 3. Branch 1 — addVolume

    @Test("Branch 1: stall + chest volume < MAV → .addVolume")
    func branch1AddVolumeWhenBelowMAV() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        // 4 stalled sessions THIS week — contributes 4 chest direct sets.
        try insertStalledSessionsThisWeek(ctx, ex: ex)
        // Chest MAV = 16 → 4 < 16 → Branch 1 fires.
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 16)
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .addVolume)
    }

    // MARK: - 4. Branch 2 — dropIntensity on RPE creep

    @Test("Branch 2: stall + RPE creep ≥1.0 at matched load → .dropIntensity")
    func branch2DropIntensityOnRPECreep() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        // 4 stalled sessions all 100×5 with RPE creeping {7, 8, 8.5, 9}
        // (avg-last-2 8.75 vs avg-first-2 7.5 → creep = 1.25 ≥ 1.0).
        try insertStalledSessionsThisWeek(ctx, ex: ex, rpes: [7.0, 8.0, 8.5, 9.0])
        // Chest MAV = 2 → 4 ≥ 2 → Branch 1 skipped.
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 2)
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .dropIntensity)
    }

    // MARK: - 5. Branch 3 — deload on active block week ≥3

    @Test("Branch 3: stall + active block week ≥3 + deload ≤14d → .deload")
    func branch3DeloadOnActiveBlockWeek3() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        // Stall with no RPE creep + chest volume ≥ MAV (skip Branches 1+2).
        try insertStalledSessionsThisWeek(ctx, ex: ex, rpes: [8.0, 8.0, 8.0, 8.0])
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 2)

        // Block: accumulation phase started 14 calendar days ago (now is in
        // week 3, weekIndex=2); deload phase begins on day 28 (i.e., 14 days
        // from now). Calendar days, as the engine counts them: near midnight
        // in a daylight-saving week, 14 × 86,400 s back lands on another day.
        let now = Date.now
        let block = Block()
        block.name = "Test Block"
        block.startDate = try #require(Calendar.current.date(byAdding: .day, value: -14, to: now))
        block.isActive = true
        ctx.insert(block)

        let accum = BlockPhase()
        accum.block = block
        accum.orderIndex = 0
        accum.nameRaw = "accumulation"
        accum.weeks = 4    // weeks 0..3
        ctx.insert(accum)

        let deload = BlockPhase()
        deload.block = block
        deload.orderIndex = 1
        deload.nameRaw = "deload"
        deload.weeks = 1
        ctx.insert(deload)

        try ctx.save()
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .deload)
    }

    // MARK: - 6. Branch 4 — tryVariation fallback

    @Test("Branch 4: stall + no other branch fires → .tryVariation")
    func branch4TryVariationFallback() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        try insertStalledSessionsThisWeek(ctx, ex: ex, rpes: [8.0, 8.0, 8.0, 8.0])
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 2)
        // No active block → Branch 3 cannot fire.
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .tryVariation)
    }

    // MARK: - 7. No active block → Branch 3 skipped

    @Test("With no Block.isActive row, Branch 3 cannot fire — falls through to tryVariation")
    func noActiveBlockSkipsBranch3() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        try insertStalledSessionsThisWeek(ctx, ex: ex, rpes: [8.0, 8.0, 8.0, 8.0])
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 2)
        // Insert a Block, but isActive = false.
        let block = Block()
        block.name = "Inactive"
        block.isActive = false
        ctx.insert(block)
        try ctx.save()
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .tryVariation)
    }

    // MARK: - 8. Branch priority — Branch 1 wins over Branch 2

    @Test("Branch 1 wins over Branch 2 when both could fire")
    func branch1WinsOverBranch2WhenBothFire() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try makeMuscles(ctx)
        let ex = try makeBench(ctx, muscles: muscles)
        // Stall with RPE creep (Branch 2 would fire) AND chest volume < MAV (Branch 1 fires).
        try insertStalledSessionsThisWeek(ctx, ex: ex, rpes: [7.0, 8.0, 8.5, 9.0])
        try insertChestTarget(ctx, muscle: muscles.chest, mav: 16)  // 4 < 16 → Branch 1
        let settings = defaultSettings(ctx)

        let action = PlateauDetector.suggestedAction(exerciseID: ex.id, intent: .strength, in: ctx, settings: settings)
        #expect(action == .addVolume)
    }
}
