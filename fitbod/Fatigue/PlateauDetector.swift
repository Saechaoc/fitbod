//
//  PlateauDetector.swift
//  fitbod
//
//  Phase 5 — pure-function namespace for per-exercise plateau detection
//  per CONTEXT D-10..D-13.
//
//  evaluate(exerciseID:intent:in:settings:now:) reads the last N
//  intent-matched SessionExercise rows from FINISHED sessions
//  (completedAt != nil) for the target exercise, computes
//  the top-set e1RM per session via OneRepMaxEstimator (Brzycki ≤6 /
//  Epley 6–10 / nil >10 per PROG-02), and returns:
//    - .notEnoughData when fewer than N e1RM-eligible sessions remain
//    - .stalled(e1RMs:rangeRatio:) when (max - min) / mean ≤ tolerance
//    - .progressing(e1RMs:) otherwise
//
//  Tolerance / window resolution: each Exercise may override the global
//  defaults via plateauWindowOverride: Int? + plateauToleranceOverride:
//  Double? (SET-06, plan 01 schema additive). nil → fall back to
//  UserSettings.plateauWindowSessions / .plateauTolerance.
//
//  suggestedAction(...) implements the D-13 4-branch decision tree:
//    Branch 1 (priority): primary-muscle volume < MAV this week → .addVolume
//    Branch 2: RPE creep ≥ 1.0 at matched load across the window → .dropIntensity
//    Branch 3: active block week ≥3 AND scheduled deload ≤14 days out → .deload
//    Branch 4 (default): → .tryVariation
//
//  Pitfall #1 mitigated: the SessionExercise fetch predicate keeps the
//  optional-chain on a single hop (exercise?.id == targetID) and the
//  intent gate runs as a simple non-optional comparison; multi-hop
//  traversals live in Swift post-filters.
//
//  Pitfall #6 partially addressed: PlateauDetector itself doesn't surface
//  variations — that's TryVariationSheet's job (plan 03 task 2).
//
//  Branch 3 BLOCK-08 / Pitfall #11 anchor: returns the .deload SuggestedAction
//  case (an advisory hint that the UI surfaces as a chip); does NOT mutate
//  Block state. The block schedule remains canonical.
//
//  @MainActor because ModelContext is @MainActor-bound under Swift 6.
//  No SwiftData mutations.
//

import Foundation
import SwiftData

/// The output of `PlateauDetector.evaluate(...)`. Three terminal cases
/// with the e1RM array attached so callers can render diagnostics
/// without re-fetching.
public enum PlateauSignal: Sendable, Equatable {
    case notEnoughData
    case stalled(e1RMs: [Double], rangeRatio: Double)
    case progressing(e1RMs: [Double])
}

/// One of D-13's 4 suggested actions. The UI chip surfaces exactly one
/// per stalled exercise; the parent view routes the tap.
public enum SuggestedAction: String, Sendable, Equatable {
    case addVolume
    case dropIntensity
    case deload
    case tryVariation
}

public enum PlateauDetector {

    /// Working SetEntry kinds that count toward top-set e1RM selection.
    /// Mirrors FatigueModel.workingKinds.
    private static let workingKinds: Set<String> = ["working", "drop", "failure", "rest_pause"]

    // MARK: - evaluate

    /// Compute the plateau signal for one exercise / intent stream.
    ///
    /// Algorithm:
    ///   1. Look up the Exercise to resolve N + tolerance overrides.
    ///   2. Fetch the last N intent-matched SessionExercise rows (over-fetch by 2× to survive high-rep filtering).
    ///   3. Compute the top-set e1RM per row via OneRepMaxEstimator (PROG-02 high-rep suppression in-loop).
    ///   4. Take the most recent N e1RM-eligible sessions; if fewer remain, return `.notEnoughData`.
    ///   5. Compute `mean`, `range`, `rangeRatio`; classify against tolerance.
    ///
    /// Only FINISHED sessions (`completedAt != nil`) count, the same rule as
    /// `PreviousMatchingIntent.fetchTopWorkingSet`, so a set logged in the
    /// workout in progress never feeds its own stall signal.
    @MainActor
    public static func evaluate(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> PlateauSignal {
        // 1. Resolve the Exercise + per-exercise overrides.
        let targetExerciseID = exerciseID
        let exDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.id == targetExerciseID }
        )
        let exercise = (try? context.fetch(exDescriptor))?.first
        let windowN = exercise?.plateauWindowOverride ?? settings.plateauWindowSessions
        let tolerance = exercise?.plateauToleranceOverride ?? settings.plateauTolerance

        guard windowN > 0 else { return .notEnoughData }

        // 2. Fetch intent-matched SessionExercise rows (over-fetch buffer for
        //    high-rep filtering). Sort by parent session.startedAt DESC.
        //    Pitfall #1: keep multi-hop traversal out of #Predicate.
        let targetIntentRaw = intent.rawValue
        let seDescriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { se in
                se.exercise?.id == targetExerciseID
            }
        )
        let allMatching = (try? context.fetch(seDescriptor)) ?? []
        // Finished-session + intent filter via parent Session (multi-hop
        // optional → Swift post-filter). Also drop SessionExercises without
        // a parent session (orphan rows).
        let intentMatched = allMatching.compactMap { se -> (SessionExercise, Date)? in
            guard let session = se.session, session.completedAt != nil else { return nil }
            guard session.intentRaw == targetIntentRaw else { return nil }
            return (se, session.startedAt)
        }
        let sortedDesc = intentMatched.sorted { $0.1 > $1.1 }

        // 3. Compute per-session top-set e1RM. Skip sessions where no
        //    working set has a defined e1RM (all-high-rep sessions).
        var e1RMs: [Double] = []
        for (se, _) in sortedDesc {
            guard let top = topSetE1RM(for: se) else { continue }
            e1RMs.append(top)
            if e1RMs.count >= windowN { break }
        }

        // 4. Apply the window threshold.
        guard e1RMs.count >= windowN else {
            return .notEnoughData
        }

        // 5. Classify against tolerance.
        let trimmed = Array(e1RMs.prefix(windowN))
        let minVal = trimmed.min() ?? 0
        let maxVal = trimmed.max() ?? 0
        let mean = trimmed.reduce(0, +) / Double(trimmed.count)
        guard mean > 0 else { return .notEnoughData }
        let rangeRatio = (maxVal - minVal) / mean

        if rangeRatio <= tolerance {
            return .stalled(e1RMs: trimmed, rangeRatio: rangeRatio)
        }
        return .progressing(e1RMs: trimmed)
    }

    // MARK: - suggestedAction

    /// Pick a single suggested action for a stalled exercise per D-13.
    /// Returns nil when the underlying signal is `.notEnoughData` or
    /// `.progressing` (no chip surfaced).
    @MainActor
    public static func suggestedAction(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> SuggestedAction? {
        let signal = evaluate(exerciseID: exerciseID, intent: intent, in: context, settings: settings, now: now)
        guard case .stalled = signal else { return nil }

        // Look up Exercise + primary muscle for Branch 1.
        let targetExerciseID = exerciseID
        let exDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.id == targetExerciseID }
        )
        guard let exercise = (try? context.fetch(exDescriptor))?.first else {
            return .tryVariation  // safe default
        }

        // Resolve primary muscle (highest weight primary; fallback first stim).
        let stims = exercise.muscleStimuli ?? []
        let primaryStim = stims
            .filter { $0.role == "primary" }
            .sorted { $0.weight > $1.weight }
            .first
            ?? stims.first
        let primarySlug = primaryStim?.muscle?.slug

        // 4. Compute weekStart (Monday-anchored midnight) for Branches 1/2.
        let weekStart = mondayAtMidnight(now, weekStartsMonday: settings.weekStartsMonday)

        // 5. Branch 1 — primary muscle volume below MAV this week.
        if let slug = primarySlug,
           let target = fetchMuscleVolumeTarget(slug: slug, in: context) {
            let total = FatigueModel.weeklyVolume(muscleSlug: slug, weekStart: weekStart, in: context)
            if total.totalSetsRounded < target.mav {
                return .addVolume
            }
        }

        // 6. Branch 2 — RPE creep ≥1.0 at matched load across the window.
        if hasRPECreep(
            exerciseID: exerciseID,
            intent: intent,
            in: context,
            settings: settings
        ) {
            return .dropIntensity
        }

        // 7. Branch 3 — active block week ≥3 AND deload ≤14d.
        if isInBlockWeekThreeWithDeloadComing(now: now, in: context) {
            return .deload
        }

        // 8. Branch 4 default.
        return .tryVariation
    }

    // MARK: - Helpers

    /// Compute the top-set e1RM for one SessionExercise. The "top" set
    /// is the working set with the highest OneRepMaxEstimator output
    /// (NOT necessarily the heaviest weight — high-reps-at-lower-weight
    /// can produce a higher e1RM via Epley). Returns nil if no working
    /// set has a defined e1RM (all sets suppressed at >10 reps).
    private static func topSetE1RM(for se: SessionExercise) -> Double? {
        let sets = se.sets ?? []
        var best: Double? = nil
        for set in sets {
            guard set.isComplete, !set.isWarmup, set.reps > 0 else { continue }
            guard workingKinds.contains(set.setTypeRaw) else { continue }
            if let e = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) {
                if best == nil || e > best! { best = e }
            }
        }
        return best
    }

    /// Fetch the MuscleVolumeTarget for a slug, or nil if none exists yet.
    @MainActor
    private static func fetchMuscleVolumeTarget(slug: String, in context: ModelContext) -> MuscleVolumeTarget? {
        let targetSlug = slug
        let descriptor = FetchDescriptor<MuscleVolumeTarget>(
            predicate: #Predicate<MuscleVolumeTarget> { $0.muscle?.slug == targetSlug }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// D-13 Branch 2 — RPE creep detection. Reads the same N intent-matched
    /// sessions used by evaluate, identifies a "matched load" (the modal
    /// top-set weight across the window within ±max(smallestIncrement, 0.5kg)),
    /// and compares avg of last 2 sessions' RPE vs avg of first 2.
    ///
    /// Only FINISHED sessions (`completedAt != nil`) count, as in `evaluate`:
    /// the workout in progress never enters the window, even before a set
    /// is logged.
    @MainActor
    private static func hasRPECreep(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings
    ) -> Bool {
        let targetExerciseID = exerciseID
        let exDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.id == targetExerciseID }
        )
        guard let exercise = (try? context.fetch(exDescriptor))?.first else { return false }
        let windowN = exercise.plateauWindowOverride ?? settings.plateauWindowSessions
        let increment = max(exercise.smallestIncrement ?? settings.defaultIncrementKg, 0.5)

        let targetIntentRaw = intent.rawValue
        let seDescriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { se in
                se.exercise?.id == targetExerciseID
            }
        )
        let all = (try? context.fetch(seDescriptor)) ?? []
        let intentMatched = all.compactMap { se -> (SessionExercise, Date)? in
            guard let session = se.session, session.completedAt != nil else { return nil }
            guard session.intentRaw == targetIntentRaw else { return nil }
            return (se, session.startedAt)
        }
        let sortedAsc = intentMatched.sorted { $0.1 < $1.1 }
        let trimmed = Array(sortedAsc.suffix(windowN))   // most-recent N, ASC
        guard trimmed.count >= 4 else { return false }   // need ≥2 + ≥2 pairs

        // For each session collect the top working set's (weight, rpe).
        var picks: [(weight: Double, rpe: Double?)] = []
        for (se, _) in trimmed {
            var topE: Double? = nil
            var topWeight = 0.0
            var topRPE: Double? = nil
            for set in (se.sets ?? []) {
                guard set.isComplete, !set.isWarmup, set.reps > 0 else { continue }
                guard workingKinds.contains(set.setTypeRaw) else { continue }
                guard let e = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) else { continue }
                if topE == nil || e > topE! {
                    topE = e
                    topWeight = set.weight
                    topRPE = set.rpe
                }
            }
            picks.append((weight: topWeight, rpe: topRPE))
        }
        guard picks.count >= 4 else { return false }
        // Use the modal load: the most common weight bucket within `increment`.
        // Simplified — use the median weight as the "matched load" anchor.
        let weights = picks.map { $0.weight }.sorted()
        let anchor = weights[weights.count / 2]
        let matched = picks.filter { abs($0.weight - anchor) <= increment }
        guard matched.count >= 4 else { return false }

        let rpes = matched.compactMap { $0.rpe }
        guard rpes.count >= 4 else { return false }
        let firstPairAvg = (rpes[0] + rpes[1]) / 2.0
        let lastPairAvg = (rpes[rpes.count - 1] + rpes[rpes.count - 2]) / 2.0
        return (lastPairAvg - firstPairAvg) >= 1.0
    }

    /// D-13 Branch 3 — active block in accumulation/intensification week
    /// ≥3 (zero-indexed weekIndex ≥2) with a scheduled deload phase
    /// within 14 days. If no Block.isActive row exists, Branch 3
    /// cannot fire and we return false (falls through to Branch 4).
    ///
    /// Per the Phase 1 schema, BlockPhase carries `weeks: Int` + `nameRaw:
    /// String` and does NOT carry its own startDate — phase start dates
    /// are computed as Block.startDate + cumulative weeks of preceding
    /// phases (ordered by `orderIndex`).
    @MainActor
    private static func isInBlockWeekThreeWithDeloadComing(now: Date, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.isActive == true }
        )
        guard let block = (try? context.fetch(descriptor))?.first else { return false }
        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        guard !phases.isEmpty else { return false }

        // Compute the start date of each phase by accumulating weeks.
        var phaseStart = block.startDate
        var currentIdx: Int? = nil
        var weekIndex: Int = 0
        var deloadStart: Date? = nil
        var sawCurrent = false
        for (i, phase) in phases.enumerated() {
            let span = TimeInterval(phase.weeks) * 7 * 86_400
            let phaseEnd = phaseStart.addingTimeInterval(span)
            if !sawCurrent, now >= phaseStart, now < phaseEnd {
                currentIdx = i
                let elapsed = now.timeIntervalSince(phaseStart)
                weekIndex = Int(elapsed / (7 * 86_400))
                sawCurrent = true
            }
            // Track the first deload AFTER the current phase.
            if sawCurrent, deloadStart == nil, phase.nameRaw == "deload" {
                deloadStart = phaseStart
            }
            phaseStart = phaseEnd
        }
        guard let idx = currentIdx else { return false }
        let phase = phases[idx]
        guard phase.nameRaw == "accumulation" || phase.nameRaw == "intensification" else { return false }
        guard weekIndex >= 2 else { return false }

        guard let deload = deloadStart else { return false }
        let delta = deload.timeIntervalSince(now)
        return delta >= 0 && delta <= 14 * 86_400
    }

    /// Monday-anchored midnight per Pitfall #4.
    private static func mondayAtMidnight(_ d: Date, weekStartsMonday: Bool) -> Date {
        var cal = Calendar.current
        if weekStartsMonday { cal.firstWeekday = 2 }
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return cal.date(from: comps) ?? d
    }
}
