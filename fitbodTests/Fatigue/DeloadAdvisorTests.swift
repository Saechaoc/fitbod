//
//  DeloadAdvisorTests.swift
//  fitbodTests
//
//  Pins DeloadAdvisor.evaluate + signalReport semantics per
//  D-14 (3-signal OR) / D-15 (whole-week scope) / D-17 (dismissal).
//  Threat T-05-03: canonicality preserved by type signature
//  (DeloadAdvisor returns DeloadAdvisory? — the compiler refuses to
//  coerce to a mutation type).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("DeloadAdvisor", .serialized)
struct DeloadAdvisorTests {

    // MARK: - Fixtures

    private func mondayOfThisWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return cal.date(from: comps) ?? .now
    }

    private func defaultSettings(_ ctx: ModelContext) -> UserSettings {
        let s = UserSettings.default()
        ctx.insert(s)
        try? ctx.save()
        return s
    }

    private func makeBench(_ ctx: ModelContext) throws -> Exercise {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        ctx.insert(chest)
        let ex = Exercise()
        ex.name = "Barbell Bench Press"
        ex.canonicalName = "barbell bench press"
        ctx.insert(ex)
        let stim = ExerciseMuscleStimulus()
        stim.role = "primary"
        stim.weight = 1.0
        stim.muscle = chest
        stim.exercise = ex
        ctx.insert(stim)
        try ctx.save()
        return ex
    }

    /// Insert N sessions with a single bench-press top set per session.
    /// `weightsReps[0]` is the most-recent session (offset 0 from `weekStart`).
    @discardableResult
    private func insertSessions(
        _ ctx: ModelContext,
        ex: Exercise,
        weekStart: Date,
        intent: Intent = .strength,
        weightsReps: [(Double, Int)],
        rpes: [Double?]? = nil,
        targetRepsHigh: Int = 8
    ) throws -> [Session] {
        var sessions: [Session] = []
        for (i, wr) in weightsReps.enumerated() {
            let session = Session()
            // Index 0 = most recent (offset 1 day before weekStart so it falls
            // in the prior week's range when needed; we use multi-day offsets).
            session.startedAt = weekStart.addingTimeInterval(-Double(i + 1) * 2 * 86_400)
            session.completedAt = session.startedAt.addingTimeInterval(60 * 45)
            session.routineSnapshotName = "Test"
            session.intentRaw = intent.rawValue
            ctx.insert(session)
            let se = SessionExercise()
            se.session = session
            se.exercise = ex
            se.orderIndex = 0
            se.targetRepsHigh = targetRepsHigh
            ctx.insert(se)
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = 0
            entry.weight = wr.0
            entry.reps = wr.1
            entry.rpe = rpes?[i]
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

    // MARK: - 1. Sig-1 fires on e1RM drop >5%

    @Test("Sig-1 fires when last-3 e1RM mean drops >5% vs prior-3")
    func sig1FiresOnE1RMDropAbove5Percent() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // Recent 3 sessions (indices 0..2): 94 × 5 → e1RM ≈ 105.75
        // Prior 3 sessions (indices 3..5):  100 × 5 → e1RM = 112.5
        // Drop = (112.5 - 105.75) / 112.5 ≈ 6% — fires.
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (94, 5), (94, 5), (94, 5),
            (100, 5), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)

        let advisory = DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings)
        #expect(advisory != nil)
        if let a = advisory {
            let hasSig1 = a.firedSignals.contains { signal in
                if case .e1RMDrop = signal { return true } else { return false }
            }
            #expect(hasSig1)
        }
    }

    // MARK: - 2. Sig-1 does NOT fire on <5% drop

    @Test("Sig-1 does NOT fire when drop is below 5%")
    func sig1DoesNotFireOnDropBelow5Percent() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // Recent 3: 98 × 5 → e1RM 110.25; Prior 3: 100 × 5 → 112.5;
        // Drop ≈ 2% < 5% → no Sig-1.
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (98, 5), (98, 5), (98, 5),
            (100, 5), (100, 5), (100, 5),
        ])
        let settings = defaultSettings(ctx)
        let report = DeloadAdvisor.signalReport(weekStart: monday, in: ctx, settings: settings)
        let hasSig1 = report.firedSignals.contains { signal in
            if case .e1RMDrop = signal { return true } else { return false }
        }
        #expect(!hasSig1)
    }

    // MARK: - 3. Sig-2 fires on RPE creep ≥1.0 at same load

    @Test("Sig-2 fires when RPE creeps ≥1.0 across 3 sessions at the same load")
    func sig2FiresOnRPECreepAtSameLoad() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // 3 sessions all 100 × 5 with RPEs 7.0 / 8.0 / 9.0 — creep = 2.0 ≥ 1.0.
        // Need at least 3 sessions in the last 3 weeks.
        try insertSessions(
            ctx, ex: ex, weekStart: monday,
            weightsReps: [(100, 5), (100, 5), (100, 5)],
            rpes: [9.0, 8.0, 7.0]   // index 0 is most-recent
        )
        let settings = defaultSettings(ctx)
        let report = DeloadAdvisor.signalReport(weekStart: monday, in: ctx, settings: settings)
        let hasSig2 = report.firedSignals.contains { signal in
            if case .rpeCreep = signal { return true } else { return false }
        }
        #expect(hasSig2)
    }

    // MARK: - 4. Sig-3 fires on >50% missed top of rep range

    @Test("Sig-3 fires when >50% of working sets miss the target rep range")
    func sig3FiresOnMissedTopOfRepRange() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // Target high = 8 reps. Reps {5, 5, 5} — all missing → 100% miss ratio.
        try insertSessions(
            ctx, ex: ex, weekStart: monday,
            weightsReps: [(100, 5), (100, 5), (100, 5)],
            rpes: nil,
            targetRepsHigh: 8
        )
        let settings = defaultSettings(ctx)
        let report = DeloadAdvisor.signalReport(weekStart: monday, in: ctx, settings: settings)
        let hasSig3 = report.firedSignals.contains { signal in
            if case .missedTopOfRange = signal { return true } else { return false }
        }
        #expect(hasSig3)
    }

    // MARK: - 5. Multi-signal OR: any single signal → non-nil

    @Test("Any single signal firing → advisory non-nil (multi-signal OR)")
    func multiSignalORAnySingleSignalNonNil() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // Only Sig-1 fires; other signals don't.
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (94, 8), (94, 8), (94, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        #expect(DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings) != nil)
    }

    // MARK: - 6. All signals nil → advisory nil

    @Test("No signals fired → advisory nil")
    func allSignalsNilReturnsNil() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        // Recent + prior progressing upward (recent e1RM higher than prior).
        // Recent: 105 × 5 → 118.125; Prior: 100 × 5 → 112.5; "drop" is negative.
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (105, 8), (105, 8), (105, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        #expect(DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings) == nil)
    }

    // MARK: - 7. Dismissal suppresses within same week

    @Test("Dismissal of the current week suppresses the advisory")
    func dismissalSuppressesAdvisoryThisWeek() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (94, 8), (94, 8), (94, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        // Without dismissal: non-nil.
        #expect(DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings) != nil)
        // With dismissal set to thisMonday → nil.
        settings.deloadAdvisoryDismissedWeekStart = monday
        try ctx.save()
        #expect(DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings) == nil)
    }

    // MARK: - 8. Next Monday re-evaluates

    @Test("Dismissal of the prior Monday does not suppress the next week")
    func newMondayAfterDismissalReEvaluates() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        let priorMonday = monday.addingTimeInterval(-7 * 86_400)
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (94, 8), (94, 8), (94, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        // Dismissal applies to LAST week's Monday.
        settings.deloadAdvisoryDismissedWeekStart = priorMonday
        try ctx.save()
        // Evaluate THIS week → not suppressed.
        let advisory = DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings)
        #expect(advisory != nil)
    }

    // MARK: - 9. Canonicality (type-level)

    @Test("DeloadAdvisor.evaluate type signature is DeloadAdvisory? — compile-time canonicality pin")
    func canonicalityCannotReturnMutationType() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let settings = defaultSettings(ctx)
        let monday = mondayOfThisWeek()
        // The line below compiles ONLY if evaluate's return type is
        // DeloadAdvisory? — any drift to a mutation type would fail
        // compilation. The runtime assertion is incidental; the
        // compile-time check is the test.
        let result: DeloadAdvisory? = DeloadAdvisor.evaluate(weekStart: monday, in: ctx, settings: settings)
        _ = result
        #expect(Bool(true))  // assertion: the cast compiled
    }

    // MARK: - 10. signalReport returns per-signal values

    @Test("signalReport returns per-signal numeric values")
    func signalReportReturnsPerSignalValues() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (94, 8), (94, 8), (94, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        let report = DeloadAdvisor.signalReport(weekStart: monday, in: ctx, settings: settings)
        // Sig-1 numeric value is the drop fraction; should be > 0.05.
        #expect(report.sig1_e1RMDrop != nil)
        #expect((report.sig1_e1RMDrop ?? 0) > 0.05)
    }

    // MARK: - 11. signalReport handles all-nil case

    @Test("signalReport returns nil signal fields + empty firedSignals when nothing fires")
    func signalReportHandlesAllNilCase() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let ex = try makeBench(ctx)
        let monday = mondayOfThisWeek()
        try insertSessions(ctx, ex: ex, weekStart: monday, weightsReps: [
            (105, 8), (105, 8), (105, 8),
            (100, 8), (100, 8), (100, 8),
        ])
        let settings = defaultSettings(ctx)
        let report = DeloadAdvisor.signalReport(weekStart: monday, in: ctx, settings: settings)
        #expect(report.firedSignals.isEmpty)
    }

    // MARK: - 12. bannerCopy single-signal verbatim

    @Test("bannerCopy renders D-16 verbatim for a single signal")
    func bannerCopySingleSignalVerbatim() {
        let monday = Date.now
        let advisory = DeloadAdvisory(
            firedSignals: [.e1RMDrop(percentDrop: 0.06)],
            weekStart: monday
        )
        #expect(advisory.bannerCopy == "Consider deload — e1RM dropped 6% over last 3 sessions. Tap to see signals.")
    }

    // MARK: - 13. bannerCopy multi-signal verbatim

    @Test("bannerCopy renders D-16 verbatim for multiple signals")
    func bannerCopyMultiSignalVerbatim() {
        let monday = Date.now
        let advisory = DeloadAdvisory(
            firedSignals: [
                .e1RMDrop(percentDrop: 0.06),
                .missedTopOfRange(missRatio: 0.7),
            ],
            weekStart: monday
        )
        #expect(advisory.bannerCopy == "Consider deload — 2 fatigue signals tripped over last 3 sessions. Tap to see signals.")
    }
}
