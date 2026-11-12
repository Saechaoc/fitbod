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

    // MARK: - weeklyVolume

    /// Stimulus-weighted weekly volume for one muscle, for the week
    /// starting at `weekStart` (inclusive) and ending where the next week
    /// starts, 7 calendar days later (exclusive). Returns the
    /// direct/indirect split per D-07; a muscle nothing hit this week
    /// reads zero. Read from `weeklyVolumes`, so one muscle and every
    /// muscle always agree.
    @MainActor
    public static func weeklyVolume(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> WeightedSetTotal {
        weeklyVolumes(weekStart: weekStart, in: context, calendar: calendar)[muscleSlug]
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
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [String: WeightedSetTotal] {
        volumes(of: fetchWorkingSets(weekStart: weekStart, in: context, calendar: calendar))
    }

    /// `weeklyVolumes` for working sets already read, summed in the order
    /// given: the past weekly recaps total many weeks from one read
    /// (RM-020). Given in `completedWorkingSets` order, the totals match
    /// `weeklyVolumes` exactly; stimulus weights such as 0.3 can sum to a
    /// different last digit in another order.
    static func volumes(of entries: [SetEntry]) -> [String: WeightedSetTotal] {
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

    // MARK: - workingSetCount

    /// The working sets `weeklyVolumes` reads, each counted once however many
    /// muscles it trains: the week's total on Today and Progress (RM-038).
    /// A set of an exercise that trains no muscle, such as cardio, adds no
    /// volume and is left out.
    @MainActor
    public static func workingSetCount(
        weekStart: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Int {
        workingSetCount(of: fetchWorkingSets(weekStart: weekStart, in: context, calendar: calendar))
    }

    /// `workingSetCount` for working sets already read.
    static func workingSetCount(of entries: [SetEntry]) -> Int {
        entries.count { !($0.sessionExercise?.exercise?.muscleStimuli ?? []).isEmpty }
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
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [UUID: Double] {
        contributionsPerSession(weekStart: weekStart, in: context, calendar: calendar)[muscleSlug] ?? [:]
    }

    /// `contributionPerSession` for every muscle at once, keyed by muscle
    /// slug, from one read of the week's sets. A muscle nothing hit this
    /// week has no key. Not tied to the main actor: a past weekly recap
    /// reads its week in a context of its own (RM-020).
    public static func contributionsPerSession(
        weekStart: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [String: [UUID: Double]] {
        let entries = fetchWorkingSets(weekStart: weekStart, in: context, calendar: calendar)

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
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Int {
        let perSession = contributionPerSession(
            muscleSlug: muscleSlug,
            weekStart: weekStart,
            in: context,
            calendar: calendar
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
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> WeekOverWeekDelta {
        let previousWeekStart = date(byAddingWeeks: -1, to: weekStart, calendar: calendar)
        let current = weeklyVolume(muscleSlug: muscleSlug, weekStart: weekStart, in: context, calendar: calendar)
        let prior = weeklyVolume(muscleSlug: muscleSlug, weekStart: previousWeekStart, in: context, calendar: calendar)
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

    // MARK: - Week boundaries

    /// `date` moved by `weeks` whole weeks, back when `weeks` is negative:
    /// the same local time `7 × weeks` calendar days away, so the week
    /// before or after one that starts at local midnight starts at local
    /// midnight too. A week that holds a daylight-saving change is an hour
    /// shorter or longer than 7 × 86,400 seconds, so a fixed span would
    /// land an hour off midnight (F333).
    static func date(byAddingWeeks weeks: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 7 * weeks, to: date) ?? date
    }

    // MARK: - Internal helpers

    /// The working sets `weeklyVolume` sums for the week starting at
    /// `weekStart`.
    private static func fetchWorkingSets(
        weekStart: Date,
        in context: ModelContext,
        calendar: Calendar
    ) -> [SetEntry] {
        completedWorkingSets(
            startedFrom: weekStart,
            before: date(byAddingWeeks: 1, to: weekStart, calendar: calendar),
            in: context
        )
    }

    /// Completed working sets of the workouts started in `[start, end)`,
    /// in the order a fetch of every completed non-warm-up set returns
    /// them. Pitfall #3: a set counts by `SetEntry.countsAsWork`, which
    /// excludes a warm-up by flag and by type, to defend against
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
    /// change from one fetch to the next.) Not tied to the main actor, nor
    /// are the helpers below: a past weekly recap reads its week in a
    /// context of its own (RM-020).
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
        let sets = workingSets(of: (try? context.fetch(sessionDescriptor)) ?? [])
        // A window with no working sets needs no order.
        guard !sets.isEmpty else { return [] }
        return ordered(sets, by: workingSetPositions(in: context))
    }

    /// The working sets of `sessions` (`SetEntry.countsAsWork`), each once,
    /// in workout order.
    static func workingSets(of sessions: [Session]) -> [SetEntry] {
        var seen: Set<PersistentIdentifier> = []
        var sets: [SetEntry] = []
        for session in sessions {
            for sessionExercise in session.exercises ?? [] {
                for entry in sessionExercise.sets ?? []
                where entry.countsAsWork && seen.insert(entry.persistentModelID).inserted {
                    sets.append(entry)
                }
            }
        }
        return sets
    }

    /// Where each completed non-warm-up set comes in a fetch of all of them,
    /// the order `completedWorkingSets` returns its sets in. The past weekly
    /// recaps read it once for every week (RM-020).
    static func workingSetPositions(in context: ModelContext) -> [PersistentIdentifier: Int] {
        let orderDescriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true && entry.isWarmup == false
            }
        )
        let order = (try? context.fetchIdentifiers(orderDescriptor)) ?? []
        var position: [PersistentIdentifier: Int] = [:]
        position.reserveCapacity(order.count)
        for (index, id) in order.enumerated() where position[id] == nil {
            position[id] = index
        }
        return position
    }

    /// `sets` in `position` order. Never drops a set the identifier fetch
    /// missed: it comes last, in the order given.
    static func ordered(_ sets: [SetEntry], by position: [PersistentIdentifier: Int]) -> [SetEntry] {
        sets.enumerated()
            .map { (rank: position[$0.element.persistentModelID] ?? Int.max, given: $0.offset, set: $0.element) }
            .sorted { ($0.rank, $0.given) < ($1.rank, $1.given) }
            .map(\.set)
    }
}
