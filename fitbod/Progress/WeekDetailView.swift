//
//  WeekDetailView.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — BRUHeaderBar + BRU session list replaces
//  .navigationTitle + List scaffolding. Drill-down destination for the
//  Weekly Tonnage bar tap (CONTEXT D-21).
//
//  ## BRU chrome
//
//  - BRUHeaderBar(left: "‹ Back", center: "Week of {date}") at top.
//  - Total band: uppercase BRUFont.labelSmall caption + BRUDisplay(.large)
//    value, as the chart's hero prints its total.
//  - ScrollView → LazyVStack(spacing: 0) of workout rows separated by
//    BRUDivider(.hair).
//  - Each row: routineName in BRUFont.bodyEmphasis bruInk + day and
//    tonnage in BRUFont.labelSmall bruMuted + "›" disclosure glyph.
//  - Empty state: BRUFont.bodyEmphasis bruInk.
//  - Background: Color.bruPaper.ignoresSafeArea().
//
//  ## The work its bar counts (T104)
//
//  The detail lists what its bar totals: every set the aggregator counts
//  lands in the week that holds its completion time, by the week-start
//  setting, in the shared week calendar, so a workout that runs past
//  midnight at a week's end counts in the same week here as on the chart,
//  and the detail's total equals the bar. `WeekDetailGrouping` does the
//  grouping.
//
//  ## Predicate-narrowed @Query (RESEARCH Pitfall 3)
//
//  The @Query for sets uses local-let captures of the lower/upper
//  bounds before the #Predicate so the macro expansion sees value-
//  typed immutables. The bounds span the week from weekStart.
//
//  [CITED: CONTEXT D-21 + UI-SPEC v2 §Design Pivot BRU chrome]
//

import SwiftData
import SwiftUI

public struct WeekDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    public let weekStart: Date
    private let weekStartsMonday: Bool
    @Query private var sets: [SetEntry]

    public init(weekStart: Date, weekStartsMonday: Bool) {
        let calendar = WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: weekStartsMonday)
        let lower = weekStart
        let upper = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        self.weekStart = weekStart
        self.weekStartsMonday = weekStartsMonday
        _sets = Query(
            filter: #Predicate<SetEntry> { entry in
                entry.isComplete
                    && !entry.isWarmup
                    && entry.completedAt >= lower
                    && entry.completedAt < upper
            },
            sort: \.completedAt
        )
    }

    public var body: some View {
        let workouts = WeekDetailGrouping.workouts(
            counting: sets,
            inWeekStarting: weekStart,
            weekStartsMonday: weekStartsMonday
        )

        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: navTitle
            )

            if workouts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        totalBand(workouts)
                        BRUDivider(.ink)
                        LazyVStack(spacing: 0) {
                            ForEach(workouts) { workout in
                                workoutRow(workout)
                                BRUDivider(.hair)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Total band

    /// The week's total, which is its bar's: the tonnage of every set it
    /// lists, in the app-wide unit, which relabels the stored numbers
    /// without converting them.
    private func totalBand(_ workouts: [WeekDetailWorkout]) -> some View {
        let total = workouts.reduce(0.0) { $0 + $1.tonnage }

        return VStack(alignment: .leading, spacing: 4) {
            Text("TOTAL · \(BRUCountLabel.text(workouts.count, "WORKOUT"))")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .foregroundStyle(Color.bruMuted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                BRUDisplay(Int(total.rounded()).formatted(), size: .large)
                Text(weightUnit.rawValue.uppercased())
                    .font(BRUFont.bodyDefault)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Workout row

    @ViewBuilder
    private func workoutRow(_ workout: WeekDetailWorkout) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name.isEmpty ? "Unnamed workout" : workout.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Text(workoutMeta(workout))
                    .font(BRUFont.labelSmall)
                    .tracking(0.8)
                    .foregroundStyle(Color.bruMuted)
            }
            Spacer()
            Text("›")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No workouts in this week")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private var navTitle: String {
        "Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    /// The day the workout's sets in this week were done, and their
    /// tonnage, such as "Sun, Oct 25 · 1,500 lb".
    private func workoutMeta(_ workout: WeekDetailWorkout) -> String {
        let day = workout.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(Int(workout.tonnage.rounded()).formatted()) \(weightUnit.rawValue)"
    }
}

// MARK: - WeekDetailGrouping

/// One workout's part of a Weekly Tonnage week: the sets of it that the
/// week's bar counts.
struct WeekDetailWorkout: Identifiable, Equatable {
    /// The workout's id; nil gathers sets that belong to none.
    let id: UUID?
    let name: String
    /// When the first of its counted sets was completed.
    let day: Date
    /// Σ (weight × reps) of its counted sets.
    let tonnage: Double
}

/// The week detail's grouping, apart from the view so tests can call it.
enum WeekDetailGrouping {
    /// The workouts whose sets the bar of the week from `weekStart` counts,
    /// newest first. A set counts as the aggregator counts it, in the week
    /// that holds its completion time in the shared week calendar, so the
    /// workouts' tonnage adds up to the bar, and a workout that runs past
    /// midnight at a week's end shows each set in the week it was done in.
    static func workouts(
        counting sets: [SetEntry],
        inWeekStarting weekStart: Date,
        weekStartsMonday: Bool
    ) -> [WeekDetailWorkout] {
        let calendar = WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: weekStartsMonday)
        var byWorkout: [UUID?: [SetEntry]] = [:]
        for set in sets where WeeklyTonnageAggregator.counts(set)
            && calendar.dateInterval(of: .weekOfYear, for: set.completedAt)?.start == weekStart {
            byWorkout[set.sessionExercise?.session?.id, default: []].append(set)
        }
        return byWorkout
            .map { id, sets in
                WeekDetailWorkout(
                    id: id,
                    name: sets.first?.sessionExercise?.session?.routineSnapshotName ?? "",
                    day: sets.map(\.completedAt).min() ?? weekStart,
                    tonnage: sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
                )
            }
            .sorted { $0.day > $1.day }
    }
}
