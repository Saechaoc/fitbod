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
//  entity. The volume math runs on demand inside views, so it must stay
//  proportional to one week of training, not to all history:
//  `completedWorkingSets` reads only the window's workouts, and
//  `weeklyVolumes` totals every muscle from one read so a screen showing
//  all muscles does not repeat the read per muscle.
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
    /// 7d` (exclusive). Returns the direct/indirect split per D-07; a
    /// muscle nothing hit this week reads zero. Read from
    /// `weeklyVolumes`, so one muscle and every muscle always agree.
    @MainActor
    public static func weeklyVolume(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> WeightedSetTotal {
        weeklyVolumes(weekStart: weekStart, in: context)[muscleSlug]
            ?? WeightedSetTotal(directSets: 0, indirectSets: 0)
    }

    // MARK: - weeklyVolumes

    /// `weeklyVolume` for every muscle at once, keyed by muscle slug, from
    /// one read of the week's sets. A muscle with no stimulus this week has
    /// no key.
    ///
    /// Algorithm:
    ///   1. Read the week's completed working sets (`completedWorkingSets`).
    ///   2. In-memory join through `entry.sessionExercise.exercise.muscleStimuli`
    ///      (multi-hop traversal is not safe inside #Predicate per
    ///      Pitfall #1 — must live in Swift).
    ///   3. For each stimulus, branch on role:
    ///        "primary"   → direct += stimulus.weight
    ///        "secondary" → indirect += stimulus.weight
    ///        default     → skip.
    @MainActor
    public static func weeklyVolumes(
        weekStart: Date,
        in context: ModelContext
    ) -> [String: WeightedSetTotal] {
        let entries = fetchWorkingSets(weekStart: weekStart, in: context)

        var direct: [String: Double] = [:]
        var indirect: [String: Double] = [:]
        for entry in entries {
            guard let stimuli = entry.sessionExercise?.exercise?.muscleStimuli else { continue }
            for stimulus in stimuli {
                guard let slug = stimulus.muscle?.slug else { continue }
                switch stimulus.role {
                case "primary":   direct[slug, default: 0.0] += stimulus.weight
                case "secondary": indirect[slug, default: 0.0] += stimulus.weight
                default:          break
                }
            }
        }

        var totals: [String: WeightedSetTotal] = [:]
        for slug in Set(direct.keys).union(indirect.keys) {
            totals[slug] = WeightedSetTotal(
                directSets: direct[slug] ?? 0.0,
                indirectSets: indirect[slug] ?? 0.0
            )
        }
        return totals
    }

    // MARK: - contributionPerSession

    /// Per-session stimulus-weighted contribution to a single muscle,
    /// summed across the session's working sets. Returned as a
    /// `[Session.id: contribution]` dictionary so `frequencyHits` can
    /// thresh-and-count. Read from `contributionsPerSession`.
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
        contributionsPerSession(weekStart: weekStart, in: context)[muscleSlug] ?? [:]
    }

    /// `contributionPerSession` for every muscle at once, keyed by muscle
    /// slug, from one read of the week's sets. A muscle nothing hit this
    /// week has no key.
    @MainActor
    public static func contributionsPerSession(
        weekStart: Date,
        in context: ModelContext
    ) -> [String: [UUID: Double]] {
        let entries = fetchWorkingSets(weekStart: weekStart, in: context)

        var perMuscle: [String: [UUID: Double]] = [:]
        for entry in entries {
            guard
                let sessionID = entry.sessionExercise?.session?.id,
                let stimuli = entry.sessionExercise?.exercise?.muscleStimuli
            else { continue }
            for stimulus in stimuli {
                guard let slug = stimulus.muscle?.slug else { continue }
                // Both primary and secondary contributions count for D-03.
                perMuscle[slug, default: [:]][sessionID, default: 0.0] += stimulus.weight
            }
        }
        return perMuscle
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

    /// The working sets `weeklyVolume` sums for the week starting at
    /// `weekStart`.
    @MainActor
    private static func fetchWorkingSets(
        weekStart: Date,
        in context: ModelContext
    ) -> [SetEntry] {
        completedWorkingSets(
            startedFrom: weekStart,
            before: weekStart.addingTimeInterval(7 * 86_400),
            in: context
        )
    }

    /// Completed working sets of the workouts started in `[start, end)`,
    /// in the order a fetch of every completed non-warm-up set returns
    /// them. Pitfall #3: a set counts only when `isWarmup == false` AND
    /// `setTypeRaw` is one of `workingKinds`, to defend against
    /// mis-categorized rows.
    ///
    /// Only the window's workouts are read: an indexed `startedAt` fetch,
    /// then `Session.exercises` and `SessionExercise.sets`. Fetching every
    /// completed set in history and walking
    /// `sessionExercise?.session?.startedAt` per row (a multi-hop chain
    /// cannot go inside #Predicate, Pitfall #1) cost about 0.3 s per call
    /// with a year and a half of history. An identifier-only fetch then
    /// restores that full fetch's order: callers sum stimulus weights such
    /// as 0.3, which are not exact binary fractions, so another order could
    /// move a total across a rounding boundary. (While the context holds
    /// unsaved changes, both fetches return rows in hash order, which can
    /// change from one fetch to the next.)
    @MainActor
    static func completedWorkingSets(
        startedFrom start: Date,
        before end: Date,
        in context: ModelContext
    ) -> [SetEntry] {
        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.startedAt >= start && session.startedAt < end
            }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        var inWindow: [PersistentIdentifier: SetEntry] = [:]
        var traversalOrder: [SetEntry] = []
        for session in sessions {
            for sessionExercise in session.exercises ?? [] {
                for entry in sessionExercise.sets ?? []
                where entry.isComplete && !entry.isWarmup && workingKinds.contains(entry.setTypeRaw) {
                    if inWindow.updateValue(entry, forKey: entry.persistentModelID) == nil {
                        traversalOrder.append(entry)
                    }
                }
            }
        }
        guard !inWindow.isEmpty else { return [] }

        let orderDescriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true && entry.isWarmup == false
            }
        )
        let order = (try? context.fetchIdentifiers(orderDescriptor)) ?? []
        var result: [SetEntry] = []
        result.reserveCapacity(inWindow.count)
        for id in order {
            if let entry = inWindow.removeValue(forKey: id) {
                result.append(entry)
            }
        }
        // Never drop a set the identifier fetch missed; keep it, last.
        if !inWindow.isEmpty {
            result.append(contentsOf: traversalOrder.filter { inWindow[$0.persistentModelID] != nil })
        }
        return result
    }
}
