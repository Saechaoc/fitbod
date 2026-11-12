//
//  PlateauDetector.swift
//  fitbod
//
//  Phase 5 — pure-function namespace for per-exercise plateau detection
//  per CONTEXT D-10..D-13.
//
//  evaluate(exerciseID:intent:in:settings:now:) reads the last N
//  intent-matched FINISHED sessions (completedAt != nil) that log the
//  target exercise, computes the top-set e1RM per session, across every
//  time the session logs the exercise, via OneRepMaxEstimator (Brzycki ≤6 /
//  Epley 6–10 / nil >10 per PROG-02), and returns:
//    - .notEnoughData when fewer than N e1RM-eligible sessions remain
//    - .stalled(e1RMs:rangeRatio:) when (max - min) / mean ≤ tolerance
//    - .progressing(e1RMs:) otherwise
//  evaluateWindow(...) returns the same signal with the workouts it read,
//  for the Stalled list and the chart's stall mark (RM-019). Given a
//  stream's logs (`Prefetched`), it reads them instead of fetching, and
//  suggestedAction(for:...) takes that read, so StalledExercises.find runs
//  the card's check on every stream with one fetch of the logs.
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

/// One finished workout the plateau check read: when it started and its
/// top set, the set the check ranks the workout by.
public struct PlateauWorkout: Sendable, Equatable {
    public let startedAt: Date
    public let e1RM: Double
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
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


    // MARK: - evaluate

    /// Compute the plateau signal for one exercise / intent stream.
    ///
    /// Algorithm:
    ///   1. Look up the Exercise to resolve N + tolerance overrides.
    ///   2. Fetch the intent-matched sessions that log the exercise, newest first.
    ///   3. Compute the top-set e1RM per session via OneRepMaxEstimator (PROG-02 high-rep suppression in-loop).
    ///   4. Take the most recent N e1RM-eligible sessions; if fewer remain, return `.notEnoughData`.
    ///   5. Compute `mean`, `range`, `rangeRatio`; classify against tolerance.
    ///
    /// Only FINISHED sessions (`completedAt != nil`) count, the same rule as
    /// `PreviousMatchingIntent.fetchTopWorkingSet`, so a set logged in the
    /// workout in progress never feeds its own stall signal. A session that
    /// logs the exercise several times counts once, with its top set across
    /// all of those logs.
    ///
    /// `machineID` is the machine of the log asking (RM-066), nil for none:
    /// only workouts on that machine count, since loads on different
    /// machines don't compare.
    @MainActor
    public static func evaluate(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now,
        machineID: UUID? = nil
    ) -> PlateauSignal {
        evaluateWindow(
            exerciseID: exerciseID, intent: intent, in: context, settings: settings, now: now, machineID: machineID
        ).signal
    }

    /// A stream's exercise and its logs, read by the caller already, so the
    /// check fetches neither: `StalledExercises.find` reads every log once
    /// and hands each stream its own (RM-019). The check still keeps only
    /// the finished logs of its intent and machine, as with fetched ones.
    struct Prefetched {
        let exercise: Exercise
        let logs: [SessionExercise]
    }

    /// `evaluate`, with the workouts it read, newest first: on `.stalled`
    /// and `.progressing`, one per e1RM of the signal, in reverse order.
    /// The Stalled list and the chart's stall mark read these, so they show
    /// the stall the exercise card's STALLED badge shows (RM-019).
    @MainActor
    static func evaluateWindow(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now,
        machineID: UUID? = nil,
        prefetched: Prefetched? = nil
    ) -> (signal: PlateauSignal, workouts: [PlateauWorkout]) {
        // 1. Resolve the Exercise + per-exercise overrides.
        let exercise = prefetched?.exercise ?? fetchExercise(exerciseID, in: context)
        let windowN = exercise?.plateauWindowOverride ?? settings.plateauWindowSessions
        let tolerance = exercise?.plateauToleranceOverride ?? settings.plateauTolerance

        guard windowN > 0 else { return (.notEnoughData, []) }

        // 2–3. The newest N finished intent-matched sessions with a top-set
        //      e1RM, newest first.
        let workouts = window(
            exerciseID: exerciseID, intent: intent, machineID: machineID, size: windowN,
            logs: prefetched?.logs, in: context
        )

        // 4. Apply the window threshold.
        guard workouts.count >= windowN else {
            return (.notEnoughData, workouts)
        }

        // 5. Classify against tolerance.
        let trimmed = workouts.map(\.e1RM)
        let minVal = trimmed.min() ?? 0
        let maxVal = trimmed.max() ?? 0
        let mean = trimmed.reduce(0, +) / Double(trimmed.count)
        guard mean > 0 else { return (.notEnoughData, workouts) }
        let rangeRatio = (maxVal - minVal) / mean

        if rangeRatio <= tolerance {
            return (.stalled(e1RMs: trimmed, rangeRatio: rangeRatio), workouts)
        }
        return (.progressing(e1RMs: trimmed), workouts)
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
        now: Date = .now,
        machineID: UUID? = nil
    ) -> SuggestedAction? {
        let read = evaluateWindow(
            exerciseID: exerciseID, intent: intent, in: context, settings: settings, now: now, machineID: machineID
        )
        guard case .stalled = read.signal else { return nil }
        return suggestedAction(
            for: read, exercise: fetchExercise(exerciseID, in: context), settings: settings,
            facts: SuggestionFacts(context: context, settings: settings, now: now)
        )
    }

    /// `suggestedAction` for a window `evaluateWindow` has read, so the
    /// Stalled list does not read it again (RM-019). `facts` holds what no
    /// stream decides; one shared by many streams reads each fact once.
    @MainActor
    static func suggestedAction(
        for read: (signal: PlateauSignal, workouts: [PlateauWorkout]),
        exercise: Exercise?,
        settings: UserSettings,
        facts: SuggestionFacts
    ) -> SuggestedAction? {
        guard case .stalled = read.signal else { return nil }
        guard let exercise else { return .tryVariation }  // safe default

        // Branch 1 — primary muscle volume below MAV this week.
        if let slug = primaryMuscleSlug(of: exercise), facts.isBelowMAV(slug) {
            return .addVolume
        }

        // Branch 2 — RPE creep ≥1.0 at matched load across the window.
        let increment = max(exercise.smallestIncrement ?? settings.defaultIncrementKg, 0.5)
        if hasRPECreep(in: read.workouts, increment: increment) {
            return .dropIntensity
        }

        // Branch 3 — active block week ≥3 AND deload ≤14d.
        if facts.deloadComing {
            return .deload
        }

        // Branch 4 default.
        return .tryVariation
    }

    /// What `suggestedAction` reads that no stream decides: each primary
    /// muscle's sets this week against its MAV target (Branch 1) and the
    /// active block's deload check (Branch 3). Each is read when first
    /// asked and then kept, so `StalledExercises.find` reads each once for
    /// all its streams; the card makes a new one for each ask.
    @MainActor
    final class SuggestionFacts {
        private let context: ModelContext
        private let now: Date
        private let weekStart: Date
        private var belowMAV: [String: Bool] = [:]
        private lazy var volumes = FatigueModel.weeklyVolumes(weekStart: weekStart, in: context)
        private(set) lazy var deloadComing = PlateauDetector.isInBlockWeekThreeWithDeloadComing(now: now, in: context)

        init(context: ModelContext, settings: UserSettings, now: Date) {
            self.context = context
            self.now = now
            weekStart = PlateauDetector.mondayAtMidnight(now, weekStartsMonday: settings.weekStartsMonday)
        }

        /// The muscle has a MAV target and fewer sets than it this week.
        func isBelowMAV(_ slug: String) -> Bool {
            if let known = belowMAV[slug] { return known }
            let below = PlateauDetector.fetchMuscleVolumeTarget(slug: slug, in: context).map { target in
                (volumes[slug] ?? WeightedSetTotal(directSets: 0, indirectSets: 0)).totalSetsRounded < target.mav
            } ?? false
            belowMAV[slug] = below
            return below
        }
    }

    // MARK: - Helpers

    /// One session's top set: the e1RM it ranks by, plus the load and RPE
    /// the RPE-creep check reads and the reps the Stalled list shows.
    typealias TopSet = (e1RM: Double, weight: Double, reps: Int, rpe: Double?)

    /// The muscle the volume check reads: the most heavily weighted primary
    /// muscle, else the first muscle the exercise works. ADD VOLUME opens it
    /// outside a workout (RM-019).
    static func primaryMuscleSlug(of exercise: Exercise) -> String? {
        let stims = exercise.muscleStimuli ?? []
        let primaryStim = stims
            .filter { $0.role == "primary" }
            .sorted { $0.weight > $1.weight }
            .first
            ?? stims.first
        return primaryStim?.muscle?.slug
    }

    /// The exercise, or nil when it is gone.
    @MainActor
    private static func fetchExercise(_ id: UUID, in context: ModelContext) -> Exercise? {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// The newest `size` finished sessions of the stream that have a top
    /// set, newest first: the window `evaluate` and the RPE-creep check
    /// read. Sessions whose working sets all lack an e1RM (all above 10
    /// reps) are skipped, so they never take a place in the window.
    @MainActor
    private static func window(
        exerciseID: UUID,
        intent: Intent,
        machineID: UUID?,
        size: Int,
        logs: [SessionExercise]?,
        in context: ModelContext
    ) -> [PlateauWorkout] {
        var workouts: [PlateauWorkout] = []
        let sessions = finishedSessionLogs(
            exerciseID: exerciseID, intent: intent, machineID: machineID, logs: logs, in: context
        )
        for session in sessions {
            guard let top = topSet(in: session.logs) else { continue }
            workouts.append(PlateauWorkout(
                startedAt: session.startedAt, e1RM: top.e1RM, weight: top.weight, reps: top.reps, rpe: top.rpe
            ))
            if workouts.count >= size { break }
        }
        return workouts
    }

    /// The exercise's logs in each FINISHED session (`completedAt != nil`)
    /// of `intent`, newest session first, each session's logs in workout
    /// order. A session that logs the exercise several times is one entry,
    /// so it takes one place in a window, as in `SeriesBuilder.buildPoints`.
    ///
    /// Pitfall #1: the fetch predicate keeps the optional chain on a single
    /// hop; the finished and intent gates on the parent Session run as Swift
    /// post-filters, which also drop SessionExercises without a parent
    /// session (orphan rows). Given `logs`, the exercise's logs the caller
    /// read, they stand in for the fetch.
    @MainActor
    private static func finishedSessionLogs(
        exerciseID: UUID,
        intent: Intent,
        machineID: UUID?,
        logs: [SessionExercise]?,
        in context: ModelContext
    ) -> [(startedAt: Date, logs: [SessionExercise])] {
        let targetIntentRaw = intent.rawValue
        let all: [SessionExercise]
        if let logs {
            all = logs
        } else {
            let targetExerciseID = exerciseID
            let seDescriptor = FetchDescriptor<SessionExercise>(
                predicate: #Predicate<SessionExercise> { se in
                    se.exercise?.id == targetExerciseID
                }
            )
            all = (try? context.fetch(seDescriptor)) ?? []
        }
        // Each session's logs, in the order the sessions first appear.
        var sessions: [(startedAt: Date, logs: [SessionExercise])] = []
        var sessionIndex: [UUID: Int] = [:]
        for se in all {
            guard let session = se.session, session.completedAt != nil else { continue }
            guard session.intentRaw == targetIntentRaw else { continue }
            guard se.machine?.id == machineID else { continue }
            if let index = sessionIndex[session.id] {
                sessions[index].logs.append(se)
            } else {
                sessionIndex[session.id] = sessions.count
                sessions.append((session.startedAt, [se]))
            }
        }
        return sessions
            .sorted { $0.startedAt > $1.startedAt }
            .map { ($0.startedAt, $0.logs.sorted { $0.orderIndex < $1.orderIndex }) }
    }

    /// The top set across one session's logs of the exercise. The "top" set
    /// is the working set with the highest OneRepMaxEstimator output
    /// (NOT necessarily the heaviest weight — high-reps-at-lower-weight
    /// can produce a higher e1RM via Epley). The logs are read in workout
    /// order and each log's sets in set order (`orderIndex` both times),
    /// whatever order they come in, so on a tie in e1RM the earlier set
    /// wins. Returns nil if no working set has a defined e1RM (all sets
    /// suppressed at >10 reps).
    static func topSet(in logs: [SessionExercise]) -> TopSet? {
        var best: TopSet? = nil
        for se in logs.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            for set in (se.sets ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard set.countsAsWork, set.reps > 0 else { continue }
                guard let e = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) else { continue }
                if best == nil || e > best!.e1RM {
                    best = (e1RM: e, weight: set.weight, reps: set.reps, rpe: set.rpe)
                }
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

    /// D-13 Branch 2 — RPE creep detection. Reads the window `evaluate`
    /// read (`workouts`, newest first), identifies a "matched load" (the
    /// modal top-set weight across the window, within ±`increment`, which
    /// is max(smallestIncrement, 0.5kg)), and compares avg of last 2
    /// sessions' RPE vs avg of first 2.
    ///
    /// As the window is `evaluate`'s, only FINISHED sessions
    /// (`completedAt != nil`) count: the workout in progress never enters
    /// it, even before a set is logged. A finished session with no top set
    /// (no logged working set, or none with an e1RM) never takes a place in
    /// it. A session that logs the exercise several times takes one place,
    /// with its top set across all of those logs.
    private static func hasRPECreep(in workouts: [PlateauWorkout], increment: Double) -> Bool {
        // Each session's top working set (weight, rpe), oldest first.
        let picks: [(weight: Double, rpe: Double?)] = workouts
            .reversed()
            .map { (weight: $0.weight, rpe: $0.rpe) }
        guard picks.count >= 4 else { return false }     // need ≥2 + ≥2 pairs
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
    /// String` and does NOT carry its own startDate — a phase starts on the
    /// block day after the cumulative weeks of preceding phases (ordered by
    /// `orderIndex`). Block days are calendar days from the day the block
    /// started, as `PeriodizationEngine` counts them, so a phase starts at
    /// local midnight.
    @MainActor
    private static func isInBlockWeekThreeWithDeloadComing(now: Date, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.isActive == true }
        )
        guard let block = (try? context.fetch(descriptor))?.first else { return false }
        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        guard !phases.isEmpty else { return false }

        // Compute the first day of each phase by accumulating weeks.
        let today = PeriodizationEngine.days(from: block.startDate, to: now)
        var phaseStart = 0
        var currentIdx: Int? = nil
        var weekIndex: Int = 0
        var deloadStart: Int? = nil
        var sawCurrent = false
        for (i, phase) in phases.enumerated() {
            let phaseEnd = phaseStart + phase.weeks * 7
            if !sawCurrent, today >= phaseStart, today < phaseEnd {
                currentIdx = i
                weekIndex = (today - phaseStart) / 7
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
        let daysToDeload = deload - today
        return daysToDeload >= 0 && daysToDeload <= 14
    }

    /// Monday-anchored midnight per Pitfall #4.
    private static func mondayAtMidnight(_ d: Date, weekStartsMonday: Bool) -> Date {
        var cal = Calendar.current
        if weekStartsMonday { cal.firstWeekday = 2 }
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return cal.date(from: comps) ?? d
    }
}
