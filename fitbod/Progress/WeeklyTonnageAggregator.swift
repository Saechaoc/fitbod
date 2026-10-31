//
//  WeeklyTonnageAggregator.swift
//  fitbod
//
//  Wave-1 plan 06-03 — pure-function weekly tonnage aggregator
//  (CONTEXT D-18..D-21, REQUIREMENTS PROG-04).
//
//  Inputs:
//    sets:               a SwiftData-fetched [SetEntry] from the call
//                        site (Wave 2 WeeklyTonnageView does the
//                        @Query; the aggregator never touches a
//                        ModelContainer).
//    weekStartsMonday:   read from UserSettings.weekStartsMonday by
//                        the call site (RESEARCH "Don't Hand-Roll —
//                        time-zone math for week start").
//    selectedMuscleIDs:  Set<UUID> of MuscleGroup IDs the user has
//                        ticked in the muscle filter chip row. When
//                        empty, every bar emits with muscleBreakdown
//                        == nil (single-color bar mode).
//    provider:           injected `MuscleVolumeProvider` (D-20 seam).
//
//  Algorithm:
//    1. Filter input to working-only sets (`counts(_:)`):
//          set.setType == .working
//       && !set.isWarmup
//       && set.isComplete
//       && set.weight > 0
//       && set.reps > 0
//    2. Bucket each surviving set by its ISO week start computed
//       through `weekCalendar(weekStartsMonday:)`: ISO 8601 with
//       `firstWeekday = weekStartsMonday ? 2 : 1`. The chart and the
//       week detail read the same calendar.
//    3. Per bucket: totalTonnage = Σ (weight × reps).
//    4. If selectedMuscleIDs is empty → muscleBreakdown = nil.
//       Else: for every working set in the bucket call
//       `provider.contributions(for:exercise:)`, filter to
//       selectedMuscleIDs, sum by muscleID, emit [MuscleSlice]
//       sorted by tonnage desc.
//    5. Return [WeeklyTonnageBar] sorted by weekStart asc.
//
//  Determinism: identical input → identical output (no
//  Date.now coupling, no `Calendar.current` mutation — the
//  aggregator constructs its own ISO8601 calendar value).
//
//  Sendable: every output type is Sendable + Equatable so Swift
//  Testing can do `#expect(bars == expected)` cleanly and the
//  aggregator can be invoked off the main actor when the chart
//  is computed in the background.
//
//  [CITED: CONTEXT D-18..D-21 + RESEARCH Don't-Hand-Roll]
//

import Foundation
import SwiftData

/// One bar of the Weekly Tonnage chart.
public struct WeeklyTonnageBar: Sendable, Equatable {
    /// ISO-8601 week start at 00:00 (Monday when weekStartsMonday == true).
    public let weekStart: Date
    /// Σ (weight × reps) of every working set in this week bucket.
    public let totalTonnage: Double
    /// Per-muscle breakdown when a muscle filter is active; nil otherwise.
    public let muscleBreakdown: [MuscleSlice]?

    public init(weekStart: Date, totalTonnage: Double, muscleBreakdown: [MuscleSlice]?) {
        self.weekStart = weekStart
        self.totalTonnage = totalTonnage
        self.muscleBreakdown = muscleBreakdown
    }
}

/// One stacked slice of a multi-muscle weekly bar.
public struct MuscleSlice: Sendable, Equatable {
    public let muscleID: UUID
    public let muscleName: String
    public let tonnage: Double

    public init(muscleID: UUID, muscleName: String, tonnage: Double) {
        self.muscleID = muscleID
        self.muscleName = muscleName
        self.tonnage = tonnage
    }
}

/// Pure-function aggregator that turns a flat `[SetEntry]` into a sorted
/// array of weekly bars suitable for Swift Charts `BarMark` rendering.
public enum WeeklyTonnageAggregator {

    /// The calendar Weekly Tonnage buckets weeks with: ISO 8601, its weeks
    /// starting on Monday or Sunday by the week-start setting, never the
    /// device calendar's first weekday. The chart draws its weeks and the
    /// week detail gathers its sets with it too, so all three agree.
    public static func weekCalendar(weekStartsMonday: Bool) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = weekStartsMonday ? 2 : 1
        return calendar
    }

    /// Whether the totals count `entry`: a completed working set, not a
    /// warm-up, with weight and reps.
    public static func counts(_ entry: SetEntry) -> Bool {
        entry.setType == .working
            && !entry.isWarmup
            && entry.isComplete
            && entry.weight > 0
            && entry.reps > 0
    }

    /// Aggregate working-set tonnage into per-week bars.
    ///
    /// See file header for the algorithm and filtering contract.
    public static func aggregate(
        sets: [SetEntry],
        weekStartsMonday: Bool,
        selectedMuscleIDs: Set<UUID>,
        provider: MuscleVolumeProvider
    ) -> [WeeklyTonnageBar] {

        // 1. Working-set filter (defense in depth — every property checked).
        let working = sets.filter(counts)
        guard !working.isEmpty else { return [] }

        // 2. Bucket by ISO week start in the shared week calendar, so the
        //    input weekStartsMonday flag is the ONLY source of firstWeekday,
        //    never Calendar.current.firstWeekday.
        let calendar = weekCalendar(weekStartsMonday: weekStartsMonday)

        // Group SetEntries by their week-start key. Skip any whose
        // dateInterval cannot resolve (impossible in practice but
        // protects the algorithm from a malformed Date).
        var byWeek: [Date: [SetEntry]] = [:]
        for entry in working {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: entry.completedAt) else { continue }
            byWeek[interval.start, default: []].append(entry)
        }

        // 3 + 4. Per-bucket totals (and optional muscle breakdown).
        let muscleFilterActive = !selectedMuscleIDs.isEmpty
        var bars: [WeeklyTonnageBar] = []
        bars.reserveCapacity(byWeek.count)

        for (weekStart, entries) in byWeek {
            var total: Double = 0
            // muscleID → (name, runningTonnage) accumulator for the slice rollup.
            var sliceByID: [UUID: (name: String, tonnage: Double)] = [:]

            for entry in entries {
                total += entry.weight * Double(entry.reps)
                guard muscleFilterActive, let exercise = entry.sessionExercise?.exercise else { continue }
                for contribution in provider.contributions(for: entry, exercise: exercise) {
                    guard selectedMuscleIDs.contains(contribution.muscleID) else { continue }
                    var current = sliceByID[contribution.muscleID]
                        ?? (name: contribution.muscleName, tonnage: 0)
                    current.tonnage += contribution.tonnage
                    sliceByID[contribution.muscleID] = current
                }
            }

            let breakdown: [MuscleSlice]?
            if muscleFilterActive {
                breakdown = sliceByID
                    .map { MuscleSlice(muscleID: $0.key, muscleName: $0.value.name, tonnage: $0.value.tonnage) }
                    .sorted { $0.tonnage > $1.tonnage }
            } else {
                breakdown = nil
            }

            bars.append(WeeklyTonnageBar(
                weekStart: weekStart,
                totalTonnage: total,
                muscleBreakdown: breakdown
            ))
        }

        // 5. Sorted by weekStart asc for deterministic chart rendering.
        return bars.sorted { $0.weekStart < $1.weekStart }
    }
}
