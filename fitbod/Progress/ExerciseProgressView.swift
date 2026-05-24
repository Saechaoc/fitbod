//
//  ExerciseProgressView.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — per-exercise intent-split e1RM time series.
//  Supersedes the Phase 6 baseline which used .navigationTitle, .toolbar,
//  Color.accentColor, and the #3FBFC9 literal.
//
//  REQUIREMENTS PROG-01 + PROG-03 + CONTEXT D-07/D-08/D-09 + UI-SPEC
//  § ExerciseProgressView + RESEARCH Pattern 1 + 06-UI-SPEC §Design Pivot.
//
//  ## Layout (top to bottom)
//
//    BRUHeaderBar (‹ dismiss | exercise.name | optional EXPORT)
//    ↓
//    ProgressChartHost (owns @Query, renders hero + toggle + chart)
//      ├─ HeroSummaryBand (caption · BRUDisplay value · BRUChip delta · mono sub-line)
//      │  BRUDivider(.ink)
//      ├─ SeriesToggleChipRow (4-segment BRU inverted-active bar, bindings passed in)
//      │  BRUDivider(.ink)
//      └─ Chart content area (bruBg background)
//           Branch A: Both toggles OFF     → "Select a series to display."
//           Branch B: < 2 distinct sessions → empty-state (BRU fonts/colors)
//           Branch C: otherwise            → BRU-styled chart + legend
//
//  ## Chart styling (BRU contract)
//
//    LineMark / PointMark per E1RMSeriesPoint:
//      .topSet     → foregroundStyle(Color.bruInk)
//                    lineStyle(StrokeStyle(lineWidth: 2))
//                    symbol(.square) symbolSize(50)
//      .allSetAvg  → foregroundStyle(Color.bruSignal)
//                    lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
//                    symbol(.circle) symbolSize(40)
//    PR RuleMark → foregroundStyle(Color.bruSignal) lineStyle(dash [4, 2])
//    Y grid → bruHair dashed [2, 3]
//    Axes   → BRUFont.labelSmall bruMuted
//    Background → Color.bruBg
//
//  ## Outer/inner @Query split (RESEARCH Pitfall 3 + Phase 6 perf)
//
//  Outer view owns `.exercise` parameter and toggle bindings.
//  Inner `ProgressChartHost` declares `@Query var sessionExercises`
//  with a predicate scoped via local-let UUID capture — keeps the
//  outer view stable across re-renders and confines @Query
//  invalidation surface to the chart host.
//

import Charts
import SwiftData
import SwiftUI

public struct ExerciseProgressView: View {
    public let exercise: Exercise
    @State private var showTopSet: Bool = true
    @State private var showAllAvg: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹") { dismiss() },
                center: exercise.name
            )

            ProgressChartHost(
                exercise: exercise,
                showTopSet: $showTopSet,
                showAllAvg: $showAllAvg,
                reduceMotion: reduceMotion
            )

            Spacer()
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Inner chart host (owns @Query + bindings passthrough)

private struct ProgressChartHost: View {
    @Query private var sessionExercises: [SessionExercise]
    let exercise: Exercise
    @Binding var showTopSet: Bool
    @Binding var showAllAvg: Bool
    let reduceMotion: Bool

    init(
        exercise: Exercise,
        showTopSet: Binding<Bool>,
        showAllAvg: Binding<Bool>,
        reduceMotion: Bool
    ) {
        // RESEARCH Pitfall 3: local-let capture of the UUID before the #Predicate
        // so the macro expansion sees a value-typed immutable.
        let targetID = exercise.id
        _sessionExercises = Query(
            filter: #Predicate<SessionExercise> { se in
                se.exercise?.id == targetID
            },
            sort: [SortDescriptor(\SessionExercise.orderIndex, order: .forward)]
        )
        self.exercise = exercise
        self._showTopSet = showTopSet
        self._showAllAvg = showAllAvg
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

        ScrollView {
            VStack(spacing: 0) {
                // Hero band + toggle only visible when there's data to show
                if distinctSessionCount >= 2 {
                    heroBand(allPoints: allPoints)
                    BRUDivider(.ink)
                }

                // Series toggle — always visible
                SeriesToggleChipRow(
                    showTopSet: $showTopSet,
                    showAllAvg: $showAllAvg
                )
                BRUDivider(.ink)

                // Chart content branch
                Group {
                    if !showTopSet && !showAllAvg {
                        dualOffLayout
                    } else if distinctSessionCount < 2 {
                        emptyStateLayout
                    } else {
                        chartLayout(
                            allPoints: allPoints,
                            filtered: filtered,
                            highRepSuppressed: anyHighRepSuppressed
                        )
                    }
                }
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.18),
                    value: filtered
                )
            }
        }
        .background(Color.bruBg)
    }

    // MARK: - Hero summary band

    private func heroValues(from points: [E1RMSeriesPoint])
        -> (latest: Double, earliest: Double, weeks: Int)
    {
        let sorted = points.sorted { $0.date < $1.date }
        let topSetPoints = sorted.filter { $0.kind == .topSet }
        let sourcePoints = topSetPoints.isEmpty ? sorted : topSetPoints
        let latest = sourcePoints.last?.e1RM ?? 0
        let earliest = sourcePoints.first?.e1RM ?? 0
        let weeks: Int = {
            guard
                let first = sourcePoints.first?.date,
                let last = sourcePoints.last?.date
            else { return 0 }
            let days = Calendar.current
                .dateComponents([.day], from: first, to: last).day ?? 0
            return max(1, Int(ceil(Double(days) / 7.0)))
        }()
        return (latest, earliest, weeks)
    }

    @ViewBuilder
    private func heroBand(allPoints: [E1RMSeriesPoint]) -> some View {
        let hero = heroValues(from: allPoints)
        let delta = hero.latest - hero.earliest
        let deltaSigned = delta >= 0
            ? "+ \(String(format: "%.0f", delta)) LB"
            : "- \(String(format: "%.0f", abs(delta))) LB"
        let weeksLabel = "\(hero.weeks) WEEK\(hero.weeks == 1 ? "" : "S")"

        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EST. 1 REP MAX · \(weeksLabel)")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                BRUDisplay(
                    "\(String(format: "%.0f", hero.latest)) LB",
                    size: .hero
                )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                BRUChip(deltaSigned, color: .bruSignal, fill: true, textCase: nil)
                Text("FROM \(String(format: "%.0f", hero.earliest)) LB")
                    .font(BRUFont.labelMicro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruPaper)
    }

    // MARK: - Branch A: both toggles off

    private var dualOffLayout: some View {
        VStack {
            Spacer(minLength: 16)
            Text("Select a series to display.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(Color.bruBg)
    }

    // MARK: - Branch B: empty state

    private var emptyStateLayout: some View {
        VStack(spacing: 8) {
            Text("Not enough data")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Log 2 sessions to see your trend.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.vertical, 32)
        .background(Color.bruBg)
    }

    // MARK: - Branch C: chart

    @ViewBuilder
    private func chartLayout(
        allPoints: [E1RMSeriesPoint],
        filtered: [E1RMSeriesPoint],
        highRepSuppressed: Bool
    ) -> some View {
        let prValue = filtered.map(\.e1RM).max() ?? 0
        let hypCount = Set(
            allPoints.filter { $0.intent == .hypertrophy }.map(\.date)
        ).count
        let strCount = Set(
            allPoints.filter { $0.intent == .strength }.map(\.date)
        ).count

        VStack(alignment: .leading, spacing: 8) {
            Chart {
                // PR RuleMark — dashed bruSignal with inline label
                if prValue > 0 {
                    RuleMark(y: .value("PR", prValue))
                        .foregroundStyle(Color.bruSignal)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .annotation(position: .topTrailing) {
                            Text("PR \(String(format: "%.0f", prValue))")
                                .font(BRUFont.labelMicro)
                                .tracking(1.0)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruSignal)
                        }
                }

                // Data series
                ForEach(filtered) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1RM)
                    )
                    .foregroundStyle(
                        point.kind == .topSet
                            ? Color.bruInk
                            : Color.bruSignal
                    )
                    .lineStyle(StrokeStyle(
                        lineWidth: 2,
                        dash: point.kind == .allSetAvg ? [6, 3] : []
                    ))
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1RM)
                    )
                    .foregroundStyle(
                        point.kind == .topSet
                            ? Color.bruInk
                            : Color.bruSignal
                    )
                    .symbol(point.kind == .topSet ? .square : .circle)
                    .symbolSize(point.kind == .topSet ? 50 : 40)
                }
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) {
                    AxisGridLine()
                        .foregroundStyle(Color.bruHair)
                    AxisTick()
                        .foregroundStyle(Color.bruMuted)
                    AxisValueLabel()
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 1, dash: [2, 3])
                    )
                    .foregroundStyle(Color.bruHair)
                    AxisValueLabel()
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .background(Color.bruBg)
            .frame(minHeight: 240)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Legend row below chart
            legendRow(hypCount: hypCount, strCount: strCount)
                .padding(.horizontal, 16)

            if highRepSuppressed {
                Text("Sets above 10 reps aren't shown in e1RM.")
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
        .background(Color.bruBg)
    }

    // MARK: - Legend

    @ViewBuilder
    private func legendRow(hypCount: Int, strCount: Int) -> some View {
        HStack(spacing: 16) {
            // Hypertrophy: solid bruInk swatch
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 16, height: 2)
                Text("HYPERTROPHY · \(hypCount) SESSIONS")
                    .font(BRUFont.labelMicro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
            }

            // Strength: dashed bruSignal swatch via Canvas
            HStack(spacing: 4) {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    context.stroke(
                        path,
                        with: .color(Color.bruSignal),
                        style: StrokeStyle(lineWidth: 2, dash: [3, 2])
                    )
                }
                .frame(width: 16, height: 2)
                Text("STRENGTH · \(strCount) SESSIONS")
                    .font(BRUFont.labelMicro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
            }
        }
        .padding(.top, 4)
    }
}
