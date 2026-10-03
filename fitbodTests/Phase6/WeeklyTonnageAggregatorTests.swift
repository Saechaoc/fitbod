//
//  WeeklyTonnageAggregatorTests.swift
//  fitbodTests
//
//  Wave-1 plan 06-03 — pure-function tests for WeeklyTonnageAggregator
//  (CONTEXT D-18..D-21, REQUIREMENTS PROG-04).
//
//  Six @Test functions:
//    1. workingSetTonnageOnly — warmup + drop + incomplete + zero-weight
//       sets are filtered out of the tonnage sum
//    2. mondayWeekStart — Sunday + Monday in the same ISO week
//       (firstWeekday = 2) bucket together; with firstWeekday = 1 the
//       split is allowed
//    3. emptySelectedMuscles — every bar emits muscleBreakdown == nil
//    4. selectedMusclesFiltered — stub provider drives MuscleSlice
//       outputs deterministically, filtered to selected IDs only
//    5. sortedByWeekStartAscending — output order is asc regardless
//       of input order
//    6. unweightedProviderUsesPrimaryMusclesOnly — UnweightedMuscleVolumeProvider
//       attributes full tonnage to primary-role stimuli only
//
//  Hermetic: each test gets a fresh in-memory ModelContainer via
//  InMemoryContainer.makeCurrent() (baseline schema). `@MainActor` because we
//  touch a ModelContext to materialize Exercise + Session + SessionExercise
//  + SetEntry fixtures (SwiftData @Model classes are @MainActor-bound
//  in this codebase per FOUND-09).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WeeklyTonnageAggregator (PROG-04 + CONTEXT D-18..D-21)", .serialized)
struct WeeklyTonnageAggregatorTests {

    // MARK: - Helpers

    /// Build a fresh in-memory context for the test.
    private func makeContext() throws -> ModelContext {
        let container = try InMemoryContainer.makeCurrent()
        return ModelContext(container)
    }

    /// Construct a minimal `(exercise, session, sessionExercise)` triad
    /// that downstream tests append `SetEntry`s into. Returns the
    /// SessionExercise so callers can wire `setEntries`.
    @discardableResult
    private func seedExerciseAndSession(
        in ctx: ModelContext,
        exerciseName: String = "Test Lift",
        sessionStart: Date = Date()
    ) -> (Exercise, Session, SessionExercise) {
        let exercise = Exercise(
            name: exerciseName,
            canonicalName: exerciseName.lowercased(),
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        let session = Session()
        session.startedAt = sessionStart
        session.completedAt = sessionStart.addingTimeInterval(3600)
        let sessionExercise = SessionExercise()
        sessionExercise.exercise = exercise
        sessionExercise.session = session
        ctx.insert(exercise)
        ctx.insert(session)
        ctx.insert(sessionExercise)
        return (exercise, session, sessionExercise)
    }

    /// Append a `SetEntry` to a SessionExercise's setEntries.
    @discardableResult
    private func appendSet(
        in ctx: ModelContext,
        on se: SessionExercise,
        weight: Double,
        reps: Int,
        completedAt: Date,
        setTypeRaw: String = "working",
        isWarmup: Bool = false,
        isComplete: Bool = true
    ) -> SetEntry {
        let entry = SetEntry()
        entry.weight = weight
        entry.reps = reps
        entry.completedAt = completedAt
        entry.setTypeRaw = setTypeRaw
        entry.isWarmup = isWarmup
        entry.isComplete = isComplete
        entry.sessionExercise = se
        ctx.insert(entry)
        return entry
    }

    /// Fixed reference Monday 2026-05-04 00:00:00 UTC for deterministic tests.
    private static let mondayMay4: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 4
        comps.hour = 9; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .iso8601).date(from: comps)!
    }()

    // MARK: - 1. workingSetTonnageOnly

    @Test("workingSetTonnageOnly — warmup/drop/incomplete/zero-weight sets excluded")
    func workingSetTonnageOnly() throws {
        let ctx = try makeContext()
        let (_, _, se) = seedExerciseAndSession(in: ctx, sessionStart: Self.mondayMay4)

        // Working: 100 × 5 = 500
        let workingSet = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4)
        // Warmup: should be excluded
        _ = appendSet(in: ctx, on: se, weight: 60, reps: 5, completedAt: Self.mondayMay4,
                      setTypeRaw: "warmup", isWarmup: true)
        // Drop set: setType != .working — excluded
        _ = appendSet(in: ctx, on: se, weight: 80, reps: 8, completedAt: Self.mondayMay4,
                      setTypeRaw: "drop")
        // Working but incomplete — excluded
        _ = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4,
                      isComplete: false)
        // Working but zero weight — excluded
        _ = appendSet(in: ctx, on: se, weight: 0, reps: 5, completedAt: Self.mondayMay4)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: se.sets ?? [workingSet],
            weekStartsMonday: true,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )

        #expect(bars.count == 1)
        let bar = try #require(bars.first)
        #expect(bar.totalTonnage == 500.0)
        #expect(bar.muscleBreakdown == nil)
    }

    // MARK: - 2. mondayWeekStart

    @Test("mondayWeekStart — Sun + Mon bucket together when weekStartsMonday=true")
    func mondayWeekStart() throws {
        // Per ISO-8601, Sunday and Monday are in DIFFERENT weeks when
        // firstWeekday = 2 (Monday-start). Sunday belongs to the prior
        // week. Pick two dates that span this boundary to verify:
        let ctx = try makeContext()
        let (_, _, se) = seedExerciseAndSession(in: ctx, sessionStart: Self.mondayMay4)
        let isoCal: Calendar = {
            var c = Calendar(identifier: .iso8601); c.firstWeekday = 2; return c
        }()
        // Sunday May 3 2026 09:00 UTC
        let sunday = isoCal.date(byAdding: .day, value: -1, to: Self.mondayMay4)!
        // Monday May 4 2026 09:00 UTC (Self.mondayMay4 is exactly this)
        let monday = Self.mondayMay4

        let sundaySet = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: sunday)
        let mondaySet = appendSet(in: ctx, on: se, weight: 80, reps: 8, completedAt: monday)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: [sundaySet, mondaySet],
            weekStartsMonday: true,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )

        // ISO Monday-start: Sunday May 3 is in the PRIOR week, so two bars expected.
        #expect(bars.count == 2)
        let total = bars.map(\.totalTonnage).reduce(0, +)
        #expect(total == 500.0 + 640.0)
        // Sunday's bar (the earlier week) sorts first.
        #expect(bars[0].weekStart < bars[1].weekStart)
    }

    // MARK: - 3. emptySelectedMuscles

    @Test("emptySelectedMuscles — every bar emits muscleBreakdown == nil")
    func emptySelectedMuscles() throws {
        let ctx = try makeContext()
        let (_, _, se) = seedExerciseAndSession(in: ctx, sessionStart: Self.mondayMay4)
        let s1 = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: [s1],
            weekStartsMonday: true,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )

        #expect(bars.count == 1)
        #expect(bars[0].muscleBreakdown == nil)
    }

    // MARK: - 4. selectedMusclesFiltered

    /// Stub provider returning canned contributions per set — isolates
    /// aggregator math from the Unweighted default's stimulus-walking.
    private struct StubProvider: MuscleVolumeProvider {
        let muscleA: UUID
        let muscleB: UUID
        func contributions(
            for set: SetEntry,
            exercise: Exercise
        ) -> [(muscleID: UUID, muscleName: String, tonnage: Double)] {
            // Each set contributes 10 to muscleA and 5 to muscleB.
            [
                (muscleID: muscleA, muscleName: "A", tonnage: 10),
                (muscleID: muscleB, muscleName: "B", tonnage: 5),
            ]
        }
    }

    @Test("selectedMusclesFiltered — only ticked muscles appear in slices")
    func selectedMusclesFiltered() throws {
        let ctx = try makeContext()
        let (_, _, se) = seedExerciseAndSession(in: ctx, sessionStart: Self.mondayMay4)
        let s1 = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4)
        let s2 = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4)

        let muscleA = UUID()
        let muscleB = UUID()
        let stub = StubProvider(muscleA: muscleA, muscleB: muscleB)

        // Tick only muscleA — slices should contain only A.
        let bars = WeeklyTonnageAggregator.aggregate(
            sets: [s1, s2],
            weekStartsMonday: true,
            selectedMuscleIDs: [muscleA],
            provider: stub
        )

        #expect(bars.count == 1)
        let breakdown = try #require(bars[0].muscleBreakdown)
        #expect(breakdown.count == 1)
        #expect(breakdown[0].muscleID == muscleA)
        // 2 sets × 10 contribution each = 20
        #expect(breakdown[0].tonnage == 20.0)
    }

    // MARK: - 5. sortedByWeekStartAscending

    @Test("sortedByWeekStartAscending — output sorted by weekStart asc")
    func sortedByWeekStartAscending() throws {
        let ctx = try makeContext()
        let (_, _, se) = seedExerciseAndSession(in: ctx, sessionStart: Self.mondayMay4)
        let isoCal: Calendar = {
            var c = Calendar(identifier: .iso8601); c.firstWeekday = 2; return c
        }()
        let weekA = Self.mondayMay4
        let weekB = isoCal.date(byAdding: .weekOfYear, value: 1, to: weekA)!
        let weekC = isoCal.date(byAdding: .weekOfYear, value: -2, to: weekA)!

        // Insert in reverse chronological order to verify sort.
        let sB = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: weekB)
        let sA = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: weekA)
        let sC = appendSet(in: ctx, on: se, weight: 100, reps: 5, completedAt: weekC)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: [sB, sA, sC],
            weekStartsMonday: true,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )

        #expect(bars.count == 3)
        // Verify ascending order strictly.
        for i in 1 ..< bars.count {
            #expect(bars[i - 1].weekStart < bars[i].weekStart)
        }
    }

    // MARK: - 6. unweightedProviderUsesPrimaryMusclesOnly

    @Test("unweightedProviderUsesPrimaryMusclesOnly — only role==primary contributes")
    func unweightedProviderUsesPrimaryMusclesOnly() throws {
        let ctx = try makeContext()
        // Build a fixture exercise with one primary + one secondary stimulus.
        let chest = MuscleGroup()
        chest.slug = "chest"
        chest.displayName = "Chest"
        chest.regionRaw = "upper"
        let triceps = MuscleGroup()
        triceps.slug = "triceps"
        triceps.displayName = "Triceps"
        triceps.regionRaw = "upper"
        ctx.insert(chest)
        ctx.insert(triceps)

        let bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        let primaryStim = ExerciseMuscleStimulus(
            exercise: bench, muscle: chest, role: "primary", weight: 1.0
        )
        let secondaryStim = ExerciseMuscleStimulus(
            exercise: bench, muscle: triceps, role: "secondary", weight: 0.5
        )
        ctx.insert(primaryStim)
        ctx.insert(secondaryStim)
        // Wire the relationship explicitly because the @Model inverse may
        // need the forward writes too in some SwiftData versions.
        bench.muscleStimuli = [primaryStim, secondaryStim]

        let session = Session()
        session.startedAt = Self.mondayMay4
        let se = SessionExercise()
        se.exercise = bench
        se.session = session
        ctx.insert(session); ctx.insert(se)

        let workingSet = appendSet(
            in: ctx, on: se, weight: 100, reps: 5, completedAt: Self.mondayMay4
        )

        let provider = UnweightedMuscleVolumeProvider()
        let contributions = provider.contributions(for: workingSet, exercise: bench)

        // Only the primary-role (chest) stimulus should contribute.
        #expect(contributions.count == 1)
        let only = try #require(contributions.first)
        #expect(only.muscleID == chest.id)
        #expect(only.tonnage == 500.0)
    }
}
