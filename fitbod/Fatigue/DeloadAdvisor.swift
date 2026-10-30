//
//  DeloadAdvisor.swift
//  fitbod
//
//  Phase 5 — pure-function namespace for fatigue-triggered deload
//  advisory per CONTEXT D-14..D-17.
//
//  Evaluates 3 signals over the last 3 weeks of training data
//  (multi-signal OR — any ONE firing surfaces the advisory):
//    Sig-1: top-set e1RM drop > 5% (pooled across all exercises,
//           last 3 sessions vs prior 3 sessions)
//    Sig-2: RPE creep ≥ 1.0 at the same load per (exercise, intent)
//           pair across the last 3 sessions
//    Sig-3: >50% of working sets in the last 3 sessions missed the
//           top of the targeted rep range
//
//  D-17 dismissal scope: setting
//  `UserSettings.deloadAdvisoryDismissedWeekStart = thisMonday`
//  suppresses the advisory for the current calendar week; the next
//  Monday re-evaluates. Compare via Pitfall #7 pattern
//  `Calendar.current.isDate(_:equalTo:toGranularity: .day)` so DST /
//  timezone edges don't false-trigger.
//
//  BLOCK-08 / T-05-03 type-level enforcement: this function returns
//  `DeloadAdvisory?` — a value type carrying only signal data + banner
//  copy. The compiler refuses to coerce it into a mutation type. The
//  only writer of block deload state remains
//  `PeriodizationEngine.advance(...)` per Phase 4 D-25.
//
//  Phase 4 FatigueAdvisory protocol bridge: `DeloadAdvisorAdapter`
//  conforms to the existing protocol (`Bool` + `FatigueSuggestion`
//  surface — see fitbod/Prescription/FatigueAdvisory.swift). This lets
//  the Phase 4 `ConsiderDeloadBanner` stub be superseded by Phase 5's
//  richer surface (`DeloadAdvisoryBanner`) without breaking any Phase 4
//  consumer that still binds to the protocol.
//
//  @MainActor because ModelContext is @MainActor-bound under Swift 6.
//  No SwiftData mutations — every read is a FetchDescriptor over
//  Session / SessionExercise / SetEntry rows.
//

import Foundation
import SwiftData

/// One of the three D-14 deload signals with the numeric value that
/// fired it (consumed by `DeloadSignalDetailSheet` for the per-row
/// detail copy).
public enum DeloadSignal: Sendable, Equatable, Hashable {
    case e1RMDrop(percentDrop: Double)
    case rpeCreep(amount: Double, exerciseName: String, intent: Intent)
    case missedTopOfRange(missRatio: Double)
}

/// The advisory output. Carries the fired signals + the Monday this
/// advisory applies to (used for D-17 dismissal compare). The
/// `bannerCopy` computed property bakes D-16 verbatim templates.
public struct DeloadAdvisory: Sendable, Equatable {
    public let firedSignals: [DeloadSignal]
    public let weekStart: Date

    public init(firedSignals: [DeloadSignal], weekStart: Date) {
        self.firedSignals = firedSignals
        self.weekStart = weekStart
    }

    /// D-16 verbatim copy:
    ///   Single signal → "Consider deload — {description} over last 3
    ///                    sessions. Tap to see signals."
    ///   Multi signal  → "Consider deload — {N} fatigue signals
    ///                    tripped over last 3 sessions. Tap to see signals."
    public var bannerCopy: String {
        if firedSignals.count == 1 {
            let desc: String
            switch firedSignals[0] {
            case .e1RMDrop(let p):
                desc = "e1RM dropped \(Int((p * 100).rounded()))%"
            case .rpeCreep(let amount, let name, let intent):
                let rounded = String(format: "%.1f", amount)
                desc = "RPE crept +\(rounded) at same load on \(name) (\(intent.rawValue))"
            case .missedTopOfRange(let r):
                desc = "\(Int((r * 100).rounded()))% of working sets missed target rep range"
            }
            return "Consider deload — \(desc) over last 3 sessions. Tap to see signals."
        } else {
            return "Consider deload — \(firedSignals.count) fatigue signals tripped over last 3 sessions. Tap to see signals."
        }
    }
}

/// Per-signal numeric report. Consumed by `DeloadSignalDetailSheet`
/// to render one List row per fired signal. `sig*` fields are nil when
/// the underlying signal did not fire.
public struct DeloadSignalReport: Sendable, Equatable {
    public let sig1_e1RMDrop: Double?
    public let sig2_rpeCreep: Double?
    public let sig3_missedTopRatio: Double?
    public let firedSignals: [DeloadSignal]

    public init(
        sig1_e1RMDrop: Double?,
        sig2_rpeCreep: Double?,
        sig3_missedTopRatio: Double?,
        firedSignals: [DeloadSignal]
    ) {
        self.sig1_e1RMDrop = sig1_e1RMDrop
        self.sig2_rpeCreep = sig2_rpeCreep
        self.sig3_missedTopRatio = sig3_missedTopRatio
        self.firedSignals = firedSignals
    }
}

public enum DeloadAdvisor {

    /// Working SetEntry kinds — mirrors FatigueModel.workingKinds.
    private static let workingKinds: Set<String> = ["working", "drop", "failure", "rest_pause"]

    // MARK: - evaluate

    /// Returns a non-nil advisory when ANY of the 3 signals fire AND
    /// the user has not already dismissed for this week. Returns nil
    /// otherwise. Caller passes `weekStart` as the current Monday at
    /// midnight (use `Date.mondayAtMidnight(weekStartsMonday:)`).
    @MainActor
    public static func evaluate(
        weekStart: Date,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> DeloadAdvisory? {
        // D-17: short-circuit if the user already dismissed for this week.
        if let dismissed = settings.deloadAdvisoryDismissedWeekStart,
           Calendar.current.isDate(dismissed, equalTo: weekStart, toGranularity: .day) {
            return nil
        }

        let report = signalReport(weekStart: weekStart, in: context, settings: settings, now: now)
        if report.firedSignals.isEmpty { return nil }
        return DeloadAdvisory(firedSignals: report.firedSignals, weekStart: weekStart)
    }

    // MARK: - signalReport

    /// Returns the per-signal numeric values + fired signals array.
    /// Always returns a report (no nil short-circuit) so the detail
    /// sheet can render the "no signals fired" empty state if the
    /// caller calls this directly.
    @MainActor
    public static func signalReport(
        weekStart: Date,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> DeloadSignalReport {
        // Fetch all completed sessions in the last 6 weeks for Sig-1.
        // Pitfall #1: simple #Predicate gates, multi-hop traversals in Swift.
        let cutoff = weekStart.addingTimeInterval(-21 * 86_400)   // 3 weeks of prior + 3 weeks of recent
        let sixWeekCutoff = weekStart.addingTimeInterval(-42 * 86_400)
        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.startedAt >= sixWeekCutoff
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let allRecentSessions = ((try? context.fetch(sessionDescriptor)) ?? [])
            // Finished workouts only: a workout still being logged is not
            // one of "the last 3 sessions", and its half-done sets would
            // skew every signal.
            .filter { $0.completedAt != nil }

        // --- Sig-1: top-set e1RM drop ---
        var sig1: Double? = nil
        let sessionsWithE1RM: [(Session, Double)] = allRecentSessions.compactMap { s in
            if let top = topSetE1RM(forSession: s) {
                return (s, top)
            }
            return nil
        }
        if sessionsWithE1RM.count >= 6 {
            let recent3 = sessionsWithE1RM.prefix(3).map { $0.1 }
            let prior3 = sessionsWithE1RM.dropFirst(3).prefix(3).map { $0.1 }
            if recent3.count == 3 && prior3.count == 3 {
                let meanRecent = recent3.reduce(0, +) / 3.0
                let meanPrior = prior3.reduce(0, +) / 3.0
                if meanPrior > 0 {
                    let drop = (meanPrior - meanRecent) / meanPrior
                    sig1 = drop
                }
            }
        }

        // --- Sig-2: RPE creep at same load per (exercise, intent) ---
        // Look at sessions in the last 3 weeks; group by (exercise.id, intent).
        let last3WeekSessions = allRecentSessions.filter { $0.startedAt >= cutoff }
        var perPair: [String: [(weight: Double, rpe: Double, startedAt: Date, name: String, intent: Intent, smallestIncrement: Double?)]] = [:]
        for session in last3WeekSessions {
            guard let intent = Intent(rawValue: session.intentRaw) else { continue }
            // One pick per exercise per session, read across every time the
            // session logs it, so the 3 sessions compared are 3 different
            // workouts. The logs run in workout order and each log's sets
            // in set order (`orderIndex` both times), whatever order
            // SwiftData returns them in, so a tie in e1RM goes to the
            // earlier set.
            var logsByExercise: [UUID: (exercise: Exercise, logs: [SessionExercise])] = [:]
            for se in (session.exercises ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard let exercise = se.exercise else { continue }
                logsByExercise[exercise.id, default: (exercise, [])].logs.append(se)
            }
            for (exercise, logs) in logsByExercise.values {
                let key = "\(exercise.id.uuidString)|\(session.intentRaw)"
                // Find the top-set across these logs (highest e1RM working set).
                var bestE: Double? = nil
                var bestWeight = 0.0
                var bestRPE: Double? = nil
                for set in logs.flatMap({ ($0.sets ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }) }) {
                    guard set.isComplete, !set.isWarmup, set.reps > 0 else { continue }
                    guard workingKinds.contains(set.setTypeRaw) else { continue }
                    guard let e = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) else { continue }
                    if bestE == nil || e > bestE! {
                        bestE = e
                        bestWeight = set.weight
                        bestRPE = set.rpe
                    }
                }
                guard bestE != nil, let rpe = bestRPE else { continue }
                perPair[key, default: []].append((
                    weight: bestWeight,
                    rpe: rpe,
                    startedAt: session.startedAt,
                    name: exercise.name,
                    intent: intent,
                    smallestIncrement: exercise.smallestIncrement
                ))
            }
        }
        // For each pair, find the worst RPE creep.
        var worstCreep: (amount: Double, name: String, intent: Intent)? = nil
        for picks in perPair.values where picks.count >= 3 {
            let sortedAsc = picks.sorted { $0.startedAt < $1.startedAt }
            let lastThree = Array(sortedAsc.suffix(3))
            // Anchor load = median weight; matched within max(smallestIncrement, 0.5kg).
            let weights = lastThree.map { $0.weight }.sorted()
            let anchor = weights[weights.count / 2]
            let increment = max(lastThree.first?.smallestIncrement ?? settings.defaultIncrementKg, 0.5)
            let matched = lastThree.filter { abs($0.weight - anchor) <= increment }
            guard matched.count >= 3 else { continue }
            let rpes = matched.map { $0.rpe }
            // Diff between first and last RPE (3-session window per RESEARCH §3.3).
            let creep = rpes.last! - rpes.first!
            if creep >= 1.0 {
                if worstCreep == nil || creep > worstCreep!.amount {
                    worstCreep = (amount: creep, name: matched.last!.name, intent: matched.last!.intent)
                }
            }
        }
        let sig2: Double? = worstCreep?.amount

        // --- Sig-3: missed top of rep range ---
        var sig3: Double? = nil
        // Take the last 3 sessions (any intent) and count working sets vs
        // misses. Like Sig-1 and Sig-2 it needs the full window: the banner
        // says "over last 3 sessions", and one short session is no trend.
        let last3 = Array(allRecentSessions.prefix(3))
        if last3.count == 3 {
            var total = 0
            var missed = 0
            for session in last3 {
                for se in (session.exercises ?? []) {
                    let target = se.targetRepsHigh
                    guard target > 0 else { continue }
                    for set in (se.sets ?? []) {
                        guard set.isComplete, !set.isWarmup, set.reps > 0 else { continue }
                        guard workingKinds.contains(set.setTypeRaw) else { continue }
                        total += 1
                        if set.reps < target { missed += 1 }
                    }
                }
            }
            if total > 0 {
                sig3 = Double(missed) / Double(total)
            }
        }

        // Aggregate fired signals.
        var fired: [DeloadSignal] = []
        if let drop = sig1, drop > 0.05 {
            fired.append(.e1RMDrop(percentDrop: drop))
        }
        if let creep = sig2, let wc = worstCreep, creep >= 1.0 {
            fired.append(.rpeCreep(amount: creep, exerciseName: wc.name, intent: wc.intent))
        }
        if let ratio = sig3, ratio > 0.5 {
            fired.append(.missedTopOfRange(missRatio: ratio))
        }

        return DeloadSignalReport(
            sig1_e1RMDrop: sig1,
            sig2_rpeCreep: sig2,
            sig3_missedTopRatio: sig3,
            firedSignals: fired
        )
    }

    // MARK: - Helpers

    /// Highest OneRepMaxEstimator output across all working sets in
    /// any SessionExercise of `session`. Returns nil if no working set
    /// has a defined e1RM (e.g., session is all high-rep).
    private static func topSetE1RM(forSession session: Session) -> Double? {
        var best: Double? = nil
        for se in (session.exercises ?? []) {
            for set in (se.sets ?? []) {
                guard set.isComplete, !set.isWarmup, set.reps > 0 else { continue }
                guard workingKinds.contains(set.setTypeRaw) else { continue }
                if let e = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) {
                    if best == nil || e > best! { best = e }
                }
            }
        }
        return best
    }
}

// MARK: - Phase 4 FatigueAdvisory adapter

/// Bridges DeloadAdvisor's richer surface (DeloadAdvisory?) into
/// Phase 4's `FatigueAdvisory` protocol (`Bool` + `FatigueSuggestion`).
/// Replaces `StubFatigueAdvisory` as the production binding.
public struct DeloadAdvisorAdapter: FatigueAdvisory {

    public init() {}

    public func shouldSuggest(context: SessionContext) -> Bool {
        // The legacy SessionContext from Phase 4 doesn't carry a
        // ModelContext or UserSettings, so we cannot evaluate signals
        // here. Returning false matches the pre-existing
        // StubFatigueAdvisory behavior at the protocol surface; Phase
        // 5's DeloadAdvisoryBanner reads `DeloadAdvisor.evaluate`
        // directly via RootView's @State + .task / .onAppear flow
        // (no protocol indirection needed for the richer UI).
        false
    }

    public func suggestion(context: SessionContext) -> FatigueSuggestion {
        FatigueSuggestion(reason: "")
    }
}
