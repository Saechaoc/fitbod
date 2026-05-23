//
//  FatigueModel.swift
//  fitbod
//
//  Phase 5 — pure-function namespace for stimulus-weighted weekly volume
//  aggregation per RESEARCH §3.1 + CONTEXT D-01..D-08.
//
//  All functions are @MainActor because ModelContext is @MainActor-bound
//  under Swift 6 strict concurrency. No SwiftData mutations — every
//  function is read-only over SetEntry / SessionExercise / Exercise /
//  ExerciseMuscleStimulus / MuscleGroup rows.
//
//  Supporting Sendable value types (`WeightedSetTotal`, `WeekOverWeekDelta`)
//  carry the direct/indirect split + the pre-computed delta copy so SwiftUI
//  views stay dumb: they bind to immutable input values and never re-run
//  fatigue math in body.
//
//  Why "pure" matters: D-04 explicitly forbids a denormalized snapshot
//  entity. The volume math runs on demand inside views — at 1-year scale
//  (~4500 SetEntry rows × 17 muscles per render = ~76K traversals) this
//  is well under the Pitfall #6 perf ceiling. If profiling later shows
//  regression, the migration path is a `@State` memo or a snapshot
//  entity — neither needed for v1.
//
//  Predicate semantics live behind Pitfall #1 local-let captures so
//  SwiftData's related-entity-ID compare footguns don't bite.
//

import Foundation
import SwiftData

/// Weighted-set rollup for a single muscle over a single week. Carries
/// the direct/indirect split per D-07 so views can render the two-tone
/// fill correctly.
public struct WeightedSetTotal: Sendable, Equatable {
    public let directSets: Double
    public let indirectSets: Double

    public init(directSets: Double, indirectSets: Double) {
        self.directSets = directSets
        self.indirectSets = indirectSets
    }

    /// Stimulus-weighted total (direct + indirect). The user sees this
    /// rolled up against the muscle's MRV target.
    public var totalSets: Double { directSets + indirectSets }

    /// Banker's-rounded integer total for the "{N} / {mrv}" trailing
    /// accessory on `MuscleVolumeBar`.
    public var totalSetsRounded: Int { Int(totalSets.rounded()) }
}

/// Week-over-week diff for a single muscle. The `deltaCopy` computed
/// property is D-08 verbatim — the planner pre-bakes the copy string
/// here so the view stays trivial.
public struct WeekOverWeekDelta: Sendable, Equatable {
    public let currentWeekTotal: Double
    public let previousWeekTotal: Double

    public init(currentWeekTotal: Double, previousWeekTotal: Double) {
        self.currentWeekTotal = currentWeekTotal
        self.previousWeekTotal = previousWeekTotal
    }

    public var delta: Double { currentWeekTotal - previousWeekTotal }

    /// D-08 verbatim copy. Rounded to nearest integer so the user
    /// doesn't see "+1.5 vs last week" — fatigue is communicated in
    /// whole sets.
    public var deltaCopy: String {
        let rounded = Int(delta.rounded())
        if rounded > 0 { return "+\(rounded) vs last week" }
        if rounded < 0 { return "\(rounded) vs last week" }   // negative sign is rendered by Int formatting
        return "no change vs last week"
    }
}

/// Pure-function namespace for stimulus-weighted weekly volume math.
public enum FatigueModel {

    /// SetEntry kinds that count as a "working set" per D-01.
    /// `warmup` is NEVER in this list — warmups are excluded twice (via
    /// `isWarmup == false` AND via this list) to defend against any
    /// future fixture row that mis-categorizes a non-warmup as
    /// `setTypeRaw == "warmup"`.
    static let workingKinds: [String] = ["working", "drop", "failure", "rest_pause"]

    // MARK: - weeklyVolume

    /// Stimulus-weighted weekly volume for one muscle, for the week
    /// starting at `weekStart` (inclusive) and ending at `weekStart +
    /// 7d` (exclusive). Returns the direct/indirect split per D-07.
    ///
    /// Algorithm:
    ///   1. Fetch SetEntry rows in the week window via a Pitfall #1
    ///      local-let-captured #Predicate.
    ///   2. In-memory join through `entry.sessionExercise.exercise.muscleStimuli`
    ///      (multi-hop traversal is not safe inside #Predicate per
    ///      Pitfall #1 — must live in Swift).
    ///   3. For each matching stimulus, branch on role:
    ///        "primary"   → directSum += stimulus.weight
    ///        "secondary" → indirectSum += stimulus.weight
    ///        default     → skip.
    @MainActor
    public static func weeklyVolume(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> WeightedSetTotal {
        let entries = fetchWorkingSets(weekStart: weekStart, in: context)

        var directSum = 0.0
        var indirectSum = 0.0
        for entry in entries {
            guard let stimuli = entry.sessionExercise?.exercise?.muscleStimuli else { continue }
            for stimulus in stimuli where stimulus.muscle?.slug == muscleSlug {
                switch stimulus.role {
                case "primary":   directSum += stimulus.weight
                case "secondary": indirectSum += stimulus.weight
                default:          break
                }
            }
        }
        return WeightedSetTotal(directSets: directSum, indirectSets: indirectSum)
    }

    // MARK: - contributionPerSession

    /// Per-session stimulus-weighted contribution to a single muscle,
    /// summed across the session's working sets. Returned as a
    /// `[Session.id: contribution]` dictionary so `frequencyHits` can
    /// thresh-and-count.
    ///
    /// `role` is collapsed for this calculation — both primary and
    /// secondary contributions count toward the frequency-hit threshold
    /// per D-03 (a session of barbell row that hits biceps with 4
    /// secondary 0.5 contributions DOES count as a frequency hit on
    /// biceps because the total is 2.0).
    @MainActor
    public static func contributionPerSession(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> [UUID: Double] {
        let entries = fetchWorkingSets(weekStart: weekStart, in: context)

        var perSession: [UUID: Double] = [:]
        for entry in entries {
            guard
                let sessionID = entry.sessionExercise?.session?.id,
                let stimuli = entry.sessionExercise?.exercise?.muscleStimuli
            else { continue }
            for stimulus in stimuli where stimulus.muscle?.slug == muscleSlug {
                // Both primary and secondary contributions count for D-03.
                perSession[sessionID, default: 0.0] += stimulus.weight
            }
        }
        return perSession
    }

    // MARK: - frequencyHits

    /// Number of sessions in the week whose weighted-set contribution
    /// to `muscleSlug` meets `minContribution`. Default threshold 2.0
    /// per D-03 — a single 0.5 indirect contribution does NOT count.
    @MainActor
    public static func frequencyHits(
        muscleSlug: String,
        weekStart: Date,
        minContribution: Double = 2.0,
        in context: ModelContext
    ) -> Int {
        let perSession = contributionPerSession(
            muscleSlug: muscleSlug,
            weekStart: weekStart,
            in: context
        )
        return perSession.values.filter { $0 >= minContribution }.count
    }

    // MARK: - weekOverWeekDelta

    /// Computes the diff between this week and the previous week's
    /// total volume for a muscle. The returned `WeekOverWeekDelta`
    /// carries the D-08 verbatim copy string.
    @MainActor
    public static func weekOverWeekDelta(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> WeekOverWeekDelta {
        let previousWeekStart = weekStart.addingTimeInterval(-7 * 86_400)
        let current = weeklyVolume(muscleSlug: muscleSlug, weekStart: weekStart, in: context)
        let prior = weeklyVolume(muscleSlug: muscleSlug, weekStart: previousWeekStart, in: context)
        return WeekOverWeekDelta(
            currentWeekTotal: current.totalSets,
            previousWeekTotal: prior.totalSets
        )
    }

    // MARK: - volumeZone delegate

    /// Delegates to plan 01's free `volumeZone(...)` so callers don't
    /// have to remember the free-function call site. Single source of
    /// truth for D-05 strict-`<` boundaries.
    public static func volumeZone(currentSets: Int, mev: Int, mav: Int, mrv: Int) -> VolumeZone {
        // Delegate to the free function from VolumeZone.swift — held in
        // a typed function value so the enclosing static method name
        // doesn't shadow the call. Equivalent to writing the body
        // inline; the indirection is purely for name disambiguation.
        let free: (Int, Int, Int, Int) -> VolumeZone = fitbod.volumeZone(currentSets:mev:mav:mrv:)
        return free(currentSets, mev, mav, mrv)
    }

    // MARK: - Internal helpers

    /// Shared SetEntry fetch for weekly aggregation. Pitfall #1
    /// local-let captures live here. Pitfall #3: `isWarmup == false`
    /// AND `workingKinds.contains(setTypeRaw)` — both guards in effect
    /// to defend against mis-categorized rows.
    ///
    /// Implementation note: the #Predicate body is intentionally
    /// minimal — only `isComplete` and `isWarmup` gates live there.
    /// The multi-hop `sessionExercise?.session?.startedAt` traversal
    /// AND the `workingKinds.contains(setTypeRaw)` array-contains
    /// gate are both Swift post-filters because Swift 6's type
    /// checker times out trying to compose all of them inside the
    /// macro body, and Pitfall #1 already advises against multi-hop
    /// optional chains inside #Predicate.
    @MainActor
    private static func fetchWorkingSets(
        weekStart: Date,
        in context: ModelContext
    ) -> [SetEntry] {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true && entry.isWarmup == false
            }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.filter { entry in
            // Pitfall #3: workingKinds gate via Swift array-contains.
            guard workingKinds.contains(entry.setTypeRaw) else { return false }
            // Multi-hop optional chain — Pitfall #1 forbids inside #Predicate.
            guard let started = entry.sessionExercise?.session?.startedAt else { return false }
            return started >= weekStart && started < weekEnd
        }
    }
}
