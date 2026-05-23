//
//  ExerciseProgressView.swift
//  fitbod
//
//  Wave-3 plan 06-05 — per-exercise intent-split e1RM time series.
//  REQUIREMENTS PROG-01 + PROG-03 + CONTEXT D-07/D-08/D-09 + UI-SPEC
//  § ExerciseProgressView + RESEARCH Pattern 1.
//
//  ## Layout
//
//    VStack {
//      SeriesToggleChipRow (both default ON)
//      ProgressChartHost   (inner @Query host)
//    }
//
//  ## Chart styling (UI-SPEC verbatim)
//
//    LineMark + PointMark per E1RMSeriesPoint
//      .foregroundStyle(by: .value("Series", p.kind.displayLabel))
//      .lineStyle(StrokeStyle(
//        lineWidth: p.kind == .topSet ? 2 : 1.5,
//        dash:      p.intent == .hypertrophy ? [4, 3] : []
//      ))
//    chartForegroundStyleScale ["Top set": .accentColor,
//                               "All-set avg": ProgressColors.allSetAverageSeries]
//    chartXScale(.automatic(includesZero: false))
//    chartYScale(.automatic(includesZero: false))
//    .frame(minHeight: 240)
//
//  ## Three layout branches
//
//    A. Both toggles OFF             → "Select a series to display."
//    B. < 2 distinct sessions w/ pts → "Not enough data" / "Log 2 sessions..."
//    C. otherwise                    → Chart(filtered)
//
//  ## Outer/inner @Query split (RESEARCH Pitfall 3 + Phase 6 perf)
//
//  Outer view owns the `.exercise` parameter and the two toggle bindings.
//  Inner `ProgressChartHost` declares `@Query var sessionExercises`
//  with a predicate scoped via local-let UUID capture — keeps the
//  outer view stable across re-renders and confines the @Query
//  invalidation surface to the chart host.
//

import Charts
import SwiftData
import SwiftUI

public struct ExerciseProgressView: View {
    public let exercise: Exercise
    @State private var showTopSet: Bool = true
    @State private var showAllAvg: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        VStack(spacing: 0) {
            SeriesToggleChipRow(
                showTopSet: $showTopSet,
                showAllAvg: $showAllAvg
            )
            ProgressChartHost(
                exerciseID: exercise.id,
                showTopSet: showTopSet,
                showAllAvg: showAllAvg,
                reduceMotion: reduceMotion
            )
            Spacer()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressChartHost: View {
    @Query private var sessionExercises: [SessionExercise]
    let showTopSet: Bool
    let showAllAvg: Bool
    let reduceMotion: Bool

    init(exerciseID: UUID, showTopSet: Bool, showAllAvg: Bool, reduceMotion: Bool) {
        // RESEARCH Pitfall 3: local-let capture of the UUID before
        // the #Predicate so the macro expansion sees a value-typed
        // immutable, not a property access on the enclosing struct.
        let targetID = exerciseID
        _sessionExercises = Query(
            filter: #Predicate<SessionExercise> { se in
                se.exercise?.id == targetID
            },
            sort: [SortDescriptor(\SessionExercise.orderIndex, order: .forward)]
        )
        self.showTopSet = showTopSet
        self.showAllAvg = showAllAvg
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        let allPoints = SeriesBuilder.buildPoints(from: sessionExercises)
        let filtered = allPoints.filter { point in
            (showTopSet && point.kind == .topSet)
                || (showAllAvg && point.kind == .allSetAvg)
        }
        let distinctSessionCount = Set(allPoints.map(\.date)).count
        let anyHighRepSuppressed = sessionExercises.contains { se in
            (se.sets ?? []).contains { entry in
                entry.setType == .working
                    && !entry.isWarmup
                    && entry.isComplete
                    && entry.reps > 10
            }
        }

        return Group {
            if !showTopSet && !showAllAvg {
                dualOffLayout
            } else if distinctSessionCount < 2 {
                emptyStateLayout
            } else {
                chartLayout(filtered: filtered, highRepSuppressed: anyHighRepSuppressed)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: filtered)
    }

    // MARK: - Branches

    private var dualOffLayout: some View {
        VStack {
            Spacer(minLength: 16)
            Text("Select a series to display.")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var emptyStateLayout: some View {
        VStack(spacing: 8) {
            Text("Not enough data")
                .font(.headline)
            Text("Log 2 sessions to see your trend.")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    @ViewBuilder
    private func chartLayout(filtered: [E1RMSeriesPoint], highRepSuppressed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(filtered) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.e1RM)
                )
                .foregroundStyle(by: .value("Series", point.kind.displayLabel))
                .lineStyle(StrokeStyle(
                    lineWidth: point.kind == .topSet ? 2 : 1.5,
                    dash: point.intent == .hypertrophy ? [4, 3] : []
                ))
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.e1RM)
                )
                .foregroundStyle(by: .value("Series", point.kind.displayLabel))
                .symbolSize(point.kind == .topSet ? 60 : 40)
            }
            .chartForegroundStyleScale([
                "Top set": Color.accentColor,
                "All-set avg": ProgressColors.allSetAverageSeries,
            ])
            .chartXScale(domain: .automatic(includesZero: false))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("e1RM (kg)")
            .frame(minHeight: 240)
            .padding(.horizontal, 16)

            Text("Solid: Strength · Dashed: Hypertrophy")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, 16)
            if highRepSuppressed {
                Text("Sets above 10 reps aren't shown in e1RM.")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.horizontal, 16)
            }
        }
    }
}
