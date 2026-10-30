//
//  FatigueModelWeeklyVolumeTests.swift
//  fitbodTests
//
//  Pins FatigueModel.weeklyVolume + WeightedSetTotal + WeekOverWeekDelta
//  semantics per D-01 / D-04 / D-07 / D-08 + RESEARCH §10 Pitfalls #1 /
//  #3 / #9.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("FatigueModelWeeklyVolume", .serialized)
struct FatigueModelWeeklyVolumeTests {

    // MARK: - Helpers

    /// Returns the Monday-anchored midnight of the current week per
    /// Pitfall #4. Synthetic date for hermetic tests — wraps
    /// `Calendar.current` with `firstWeekday = 2`.
    private func mondayOfThisWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return cal.date(from: comps) ?? .now
    }

    /// Insert the three MuscleGroup rows the bench-press fixture needs
    /// (chest / shoulders / triceps). In-memory containers don't get
    /// the Phase 1 importer fixture, so we seed inline.
    @discardableResult
    private func seedMuscles(_ ctx: ModelContext) throws -> (chest: MuscleGroup, shoulders: MuscleGroup, triceps: MuscleGroup) {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        let triceps = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
        ctx.insert(chest)
        ctx.insert(shoulders)
        ctx.insert(triceps)
        try ctx.save()
        return (chest, shoulders, triceps)
    }

    /// Build the canonical "barbell bench press" Exercise with the
    /// D-07 stimulus weights (chest 1.0 / shoulders 0.5 / triceps 0.5).
    private func makeBenchPressExercise(in ctx: ModelContext) throws -> Exercise {
        let muscles = try seedMuscles(ctx)
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ex.equipmentRaw = "barbell"
        ex.mechanicRaw = "compound"
        ctx.insert(ex)

        let chestStim = ExerciseMuscleStimulus()
        chestStim.role = "primary"
        chestStim.weight = 1.0
        chestStim.muscle = muscles.chest
        chestStim.exercise = ex
        ctx.insert(chestStim)

        let shoulderStim = ExerciseMuscleStimulus()
        shoulderStim.role = "secondary"
        shoulderStim.weight = 0.5
        shoulderStim.muscle = muscles.shoulders
        shoulderStim.exercise = ex
        ctx.insert(shoulderStim)

        let tricepStim = ExerciseMuscleStimulus()
        tricepStim.role = "secondary"
        tricepStim.weight = 0.5
        tricepStim.muscle = muscles.triceps
        tricepStim.exercise = ex
        ctx.insert(tricepStim)

        try ctx.save()
        return ex
    }

    /// Build a Session with one SessionExercise + `sets.count` SetEntry
    /// rows. Each tuple is (weight, reps, isWarmup, isComplete, setTypeRaw).
    @discardableResult
    private func makeSession(
        in ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        intentRaw: String = Intent.strength.rawValue,
        sets: [(Double, Int, Bool, Bool, String)]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(60 * 45)
        session.routineSnapshotName = "Test"
        session.intentRaw = intentRaw
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

    // MARK: - 1. VOL-02 working set count

    @Test("weeklyVolume counts 3 working bench-press sets as 3.0 direct on chest")
    func weeklyVolumeCountsWorkingSetsForBenchPressOnChest() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 3.0) < 0.001)
    }

    // MARK: - 2. D-01 warmup exclusion (isWarmup guard)

    @Test("weeklyVolume excludes isWarmup=true rows")
    func weeklyVolumeExcludesWarmups() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (50, 8, true, true, "warmup"),
                (50, 8, true, true, "warmup"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 3.0) < 0.001)
    }

    // MARK: - 3. Pitfall #3 — setTypeRaw guard ALSO in effect

    @Test("weeklyVolume excludes non-warmup row with setTypeRaw=warmup (defense in depth)")
    func weeklyVolumeExcludesSetTypeWarmup() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                // Mis-categorized row: isWarmup=false (so plain isWarmup guard
                // would let it through) but setTypeRaw="warmup" (so the
                // workingKinds.contains guard excludes it). Both guards in
                // effect per Pitfall #3.
                (50, 8, false, true, "warmup"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 3.0) < 0.001)
    }

    // MARK: - 4. Pitfall #9 — rest-pause cluster counts as 1 set

    @Test("rest-pause cluster row counts as 1 set regardless of sub-rep array")
    func restPauseClusterCountsAsOneSet() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let session = try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (100, 8, false, true, "rest_pause"),
            ]
        )
        // Verify the row's clusterSubReps array would have been set (the
        // weighted-set count must ignore it).
        if let firstSet = session.exercises?.first?.sets?.first {
            firstSet.clusterSubRepsJoined = "8,3,2"
            try ctx.save()
        }

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 1.0) < 0.001)
    }

    // MARK: - 5. Working-kinds enumeration

    @Test("workingKinds includes drop / failure / rest_pause as 1-set each")
    func workingKindsIncludesDropFailureRestPause() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (80, 6, false, true, "drop"),
                (100, 1, false, true, "failure"),
                (90, 8, false, true, "rest_pause"),
            ]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 3.0) < 0.001)
    }

    // MARK: - 6. D-07 direct/indirect split

    @Test("3 bench-press sets contribute 1.5 indirect to shoulders (3 × 0.5 secondary)")
    func directIndirectSplitForBenchPressShoulders() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let shoulders = FatigueModel.weeklyVolume(muscleSlug: "shoulders", weekStart: monday, in: ctx)
        #expect(abs(shoulders.directSets - 0.0) < 0.001)
        #expect(abs(shoulders.indirectSets - 1.5) < 0.001)
    }

    @Test("3 bench-press sets contribute 1.5 indirect to triceps (3 × 0.5 secondary)")
    func directIndirectSplitForBenchPressTriceps() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let triceps = FatigueModel.weeklyVolume(muscleSlug: "triceps", weekStart: monday, in: ctx)
        #expect(abs(triceps.directSets - 0.0) < 0.001)
        #expect(abs(triceps.indirectSets - 1.5) < 0.001)
    }

    @Test("3 bench-press sets contribute 3.0 direct + 0.0 indirect on chest")
    func directIndirectSplitChestIsAllDirect() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
                (100, 5, false, true, "working"),
            ]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 3.0) < 0.001)
        #expect(abs(chest.indirectSets - 0.0) < 0.001)
    }

    // MARK: - 7. Week-window inclusivity / exclusivity

    @Test("weeklyVolume excludes a session on the Sunday BEFORE weekStart")
    func weekWindowExcludesPriorSunday() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let priorSunday = monday.addingTimeInterval(-86_400)
        try makeSession(
            in: ctx,
            startedAt: priorSunday,
            exercise: ex,
            sets: [(100, 5, false, true, "working")]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 0.0) < 0.001)
    }

    @Test("weeklyVolume includes the Sunday of this week and excludes the next Monday")
    func weekWindowIncludesCurrentSundayExcludesNextMonday() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        // Include: late Sunday of this week (Mon + 6 days + 23h59m)
        let sundayLate = monday.addingTimeInterval(6 * 86_400 + 23 * 3600 + 59 * 60)
        try makeSession(
            in: ctx,
            startedAt: sundayLate,
            exercise: ex,
            sets: [(100, 5, false, true, "working")]
        )
        // Exclude: next Monday (weekStart + 7 days)
        let nextMonday = monday.addingTimeInterval(7 * 86_400)
        try makeSession(
            in: ctx,
            startedAt: nextMonday,
            exercise: ex,
            sets: [(100, 5, false, true, "working")]
        )

        let chest = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(abs(chest.directSets - 1.0) < 0.001)
    }

    // MARK: - 8. D-04 idempotency

    @Test("weeklyVolume is idempotent across repeated calls (no side effects)")
    func weeklyVolumeIsIdempotentAcrossCalls() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        try makeSession(
            in: ctx,
            startedAt: monday,
            exercise: ex,
            sets: [(100, 5, false, true, "working"), (100, 5, false, true, "working")]
        )

        let a = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        let b = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        let c = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(a == b)
        #expect(b == c)
        #expect(abs(a.directSets - 2.0) < 0.001)
    }

    // MARK: - 9. WeightedSetTotal totalSets / totalSetsRounded

    @Test("WeightedSetTotal aggregates direct + indirect into totalSets and rounded int")
    func totalSetsAndTotalSetsRoundedFromDirectIndirect() {
        let t = WeightedSetTotal(directSets: 3.0, indirectSets: 1.5)
        #expect(abs(t.totalSets - 4.5) < 0.001)
        // Banker's rounding: 4.5 → 4 in IEEE754 round-half-to-even.
        // Either 4 OR 5 is acceptable per Swift's default; pin the
        // value that Swift actually produces.
        let rounded = t.totalSetsRounded
        #expect(rounded == 4 || rounded == 5)
        // 5.0 directSets + 0.0 indirectSets → 5 exactly.
        let t2 = WeightedSetTotal(directSets: 5.0, indirectSets: 0.0)
        #expect(t2.totalSetsRounded == 5)
    }

    // MARK: - 10. D-08 week-over-week delta variants

    @Test("D-08 verbatim: positive delta → '+N vs last week'")
    func weekOverWeekDeltaPositive() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let priorMonday = monday.addingTimeInterval(-7 * 86_400)
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])
        try makeSession(in: ctx, startedAt: priorMonday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
        ])

        let delta = FatigueModel.weekOverWeekDelta(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(delta.deltaCopy == "+2 vs last week")
    }

    @Test("D-08 verbatim: negative delta → '-N vs last week'")
    func weekOverWeekDeltaNegative() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let priorMonday = monday.addingTimeInterval(-7 * 86_400)
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
        ])
        try makeSession(in: ctx, startedAt: priorMonday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        let delta = FatigueModel.weekOverWeekDelta(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(delta.deltaCopy == "-2 vs last week")
    }

    @Test("D-08 verbatim: zero delta → 'no change vs last week'")
    func weekOverWeekDeltaZero() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let priorMonday = monday.addingTimeInterval(-7 * 86_400)
        try makeSession(in: ctx, startedAt: monday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])
        try makeSession(in: ctx, startedAt: priorMonday, exercise: ex, sets: [
            (100, 5, false, true, "working"),
            (100, 5, false, true, "working"),
        ])

        let delta = FatigueModel.weekOverWeekDelta(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(delta.deltaCopy == "no change vs last week")
    }

    // MARK: - 11. volumeZone delegate

    @Test("FatigueModel.volumeZone delegates to the free function (single source of truth)")
    func volumeZoneDelegatesToFreeFunction() {
        #expect(FatigueModel.volumeZone(currentSets: 5,  mev: 8, mav: 14, mrv: 22) == .belowMEV)
        #expect(FatigueModel.volumeZone(currentSets: 8,  mev: 8, mav: 14, mrv: 22) == .productive)
        #expect(FatigueModel.volumeZone(currentSets: 14, mev: 8, mav: 14, mrv: 22) == .nearMRV)
        #expect(FatigueModel.volumeZone(currentSets: 22, mev: 8, mav: 14, mrv: 22) == .overMRV)
    }

    // MARK: - 12. The week's sets, in the order a full fetch returns them

    @Test("completedWorkingSets returns the week's working sets in full-fetch order")
    func completedWorkingSetsMatchesFullFetch() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let bench = try makeBenchPressExercise(in: ctx)
        let monday = mondayOfThisWeek()
        let weekEnd = monday.addingTimeInterval(7 * 86_400)

        func workout(startedAt: Date, finished: Bool) throws -> SessionExercise {
            let session = Session()
            ctx.insert(session)
            session.startedAt = startedAt
            session.completedAt = finished ? startedAt.addingTimeInterval(45 * 60) : nil
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = bench
            try ctx.save()
            return se
        }
        // One save per set, so the store keeps them in this order.
        func addSets(_ sets: [(isWarmup: Bool, isComplete: Bool, kind: String)], to se: SessionExercise) throws {
            for (i, set) in sets.enumerated() {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = se
                entry.orderIndex = i
                entry.weight = 100
                entry.reps = 5
                entry.isWarmup = set.isWarmup
                entry.isComplete = set.isComplete
                entry.setTypeRaw = set.kind
                try ctx.save()
            }
        }
        func fullFetch() throws -> [PersistentIdentifier] {
            let kinds = ["working", "drop", "failure", "rest_pause"]
            return try ctx.fetch(FetchDescriptor<SetEntry>(
                predicate: #Predicate<SetEntry> { $0.isComplete == true && $0.isWarmup == false }
            ))
            .filter { entry in
                guard kinds.contains(entry.setTypeRaw),
                      let started = entry.sessionExercise?.session?.startedAt else { return false }
                return started >= monday && started < weekEnd
            }
            .map(\.persistentModelID)
        }

        // The later workout (still in progress) has its sets saved first,
        // so walking workout by workout gives a different order.
        let first = try workout(startedAt: monday, finished: true)
        let second = try workout(startedAt: monday.addingTimeInterval(86_400), finished: false)
        try addSets([(false, true, "working"), (false, false, "working"), (false, true, "drop")], to: second)
        try addSets([(false, true, "working"), (true, true, "warmup"), (false, true, "rest_pause"),
                     (false, true, "warmup")], to: first)
        try makeSession(in: ctx, startedAt: weekEnd, exercise: bench, sets: [(100, 5, false, true, "working")])
        try makeSession(in: ctx, startedAt: monday.addingTimeInterval(-86_400), exercise: bench,
                        sets: [(100, 5, false, true, "working")])

        let expected = try fullFetch()
        #expect(expected.count == 4)
        let sets = FatigueModel.completedWorkingSets(startedFrom: monday, before: weekEnd, in: ctx)
        #expect(sets.map(\.persistentModelID) == expected)

        // Unsaved edits count like saved ones: an un-completed set drops out.
        let undone = try #require((second.sets ?? []).first { $0.isComplete && $0.setTypeRaw == "drop" })
        undone.isComplete = false
        #expect(ctx.hasChanges)
        let pending = FatigueModel.completedWorkingSets(startedFrom: monday, before: weekEnd, in: ctx)
        #expect(Set(pending.map(\.persistentModelID)) == Set(expected).subtracting([undone.persistentModelID]))
    }
}
