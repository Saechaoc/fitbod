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
//    ProgressChartHost (owns @Query, renders hero + chips + chart)
//      ├─ HeroSummaryBand (caption · BRUDisplay value · BRUChip delta · mono sub-line)
//      │  BRUDivider(.ink)
//      ├─ SeriesToggleChipRow (4-segment BRU bar, one ProgressChartMetric selected)
//      │  BRUDivider(.ink)
//      └─ Chart content area (bruBg background)
//           Branch A: < 2 distinct sessions in the series → empty-state (BRU fonts/colors)
//           Branch B: otherwise                           → BRU-styled chart + legend
//
//  ## Series per chip
//
//    e1RM     top-set e1RM + all-set average e1RM (SeriesBuilder.buildPoints)
//    TOP SET  top-set e1RM alone
//    VOLUME   SeriesBuilder.volumePoints, one line per intent
//    AVG RPE  SeriesBuilder.averageRPEPoints, one line per intent
//
//  Each point carries a VoiceOver label (series, date) and value
//  ("112 lb", "2,140 lb", "RPE 7.6"). The PR rule and the
//  above-10-reps caption are e1RM only. The legend names the lines
//  drawn: TOP SET and ALL-SET AVG on e1RM, TOP SET alone on TOP SET,
//  HYPERTROPHY · N SESSIONS and STRENGTH · N SESSIONS on VOLUME and
//  AVG RPE.
//
//  ## Chart styling (BRU contract)
//
//    LineMark / PointMark per plotted point, one line per series:
//      primary     → foregroundStyle(Color.bruInk)
//      (top set,     lineStyle(StrokeStyle(lineWidth: 2))
//       hypertrophy) symbol(.square) symbolSize(50)
//      secondary   → foregroundStyle(Color.bruSignal)
//      (all-set avg, lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
//       strength)    symbol(.circle) symbolSize(40)
//    PR RuleMark → foregroundStyle(Color.bruSignal) lineStyle(dash [4, 2])
//    Y grid → bruHair dashed [2, 3]
//    Axes   → BRUFont.labelSmall bruMuted
//    Background → Color.bruBg
//
//  ## Outer/inner @Query split (RESEARCH Pitfall 3 + Phase 6 perf)
//
//  Outer view owns `.exercise` parameter and the selected metric.
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
    @State private var metric: ProgressChartMetric = .e1RM
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
                metric: $metric,
                reduceMotion: reduceMotion
            )

            Spacer()
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Plotted point

/// One point the chart draws for the selected chip.
private struct ChartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    /// The line the point belongs to, and its name for VoiceOver.
    let series: String
    /// Ink, solid and square when true; signal, dashed and round when false.
    let isPrimary: Bool
    let intent: Intent
}

private extension ProgressChartMetric {
    /// The e1RM chips draw e1RM values, so the PR rule and the
    /// above-10-reps caption apply to them only.
    var plotsE1RM: Bool { self == .e1RM || self == .topSet }

    /// What VoiceOver calls the chart.
    var chartName: String {
        switch self {
        case .e1RM:       return "e1RM chart"
        case .topSet:     return "Top set e1RM chart"
        case .volume:     return "Volume chart"
        case .averageRPE: return "Average RPE chart"
        }
    }

    /// The Y value's name in the chart's audio graph.
    var axisName: String {
        switch self {
        case .e1RM, .topSet: return "e1RM"
        case .volume:        return "Volume"
        case .averageRPE:    return "RPE"
        }
    }
}

// MARK: - Inner chart host (owns @Query + metric binding passthrough)

private struct ProgressChartHost: View {
    @Query private var sessionExercises: [SessionExercise]
    @Environment(\.weightUnit) private var defaultUnit
    let exercise: Exercise
    @Binding var metric: ProgressChartMetric
    let reduceMotion: Bool

    init(
        exercise: Exercise,
        metric: Binding<ProgressChartMetric>,
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
        self._metric = metric
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        let allPoints = SeriesBuilder.buildPoints(from: sessionExercises)
        let plotted = chartPoints(e1RMPoints: allPoints)
        let distinctSessionCount = Set(allPoints.map(\.date)).count
        let plottedSessionCount = Set(plotted.map(\.date)).count
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
                // Hero band only visible when there's e1RM data to show
                if distinctSessionCount >= 2 {
                    heroBand(allPoints: allPoints)
                    BRUDivider(.ink)
                }

                // Series chips — always visible
                SeriesToggleChipRow(selection: $metric)
                BRUDivider(.ink)

                // Chart content branch
                Group {
                    if plottedSessionCount < 2 {
                        emptyStateLayout
                    } else {
                        chartLayout(
                            points: plotted,
                            highRepSuppressed: anyHighRepSuppressed && metric.plotsE1RM
                        )
                    }
                }
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.18),
                    value: metric
                )
            }
        }
        .background(Color.bruBg)
    }

    // MARK: - Series for the selected chip

    private func chartPoints(e1RMPoints: [E1RMSeriesPoint]) -> [ChartPoint] {
        switch metric {
        case .e1RM, .topSet:
            return e1RMPoints
                .filter { metric == .e1RM || $0.kind == .topSet }
                .map { point in
                    ChartPoint(
                        id: point.id,
                        date: point.date,
                        value: point.e1RM,
                        series: point.kind.displayLabel,
                        isPrimary: point.kind == .topSet,
                        intent: point.intent
                    )
                }
        case .volume:
            return workoutChartPoints(SeriesBuilder.volumePoints(from: sessionExercises))
        case .averageRPE:
            return workoutChartPoints(SeriesBuilder.averageRPEPoints(from: sessionExercises))
        }
    }

    /// One line per intent, styled like the legend below the chart.
    private func workoutChartPoints(_ points: [WorkoutSeriesPoint]) -> [ChartPoint] {
        points.map { point in
            ChartPoint(
                id: point.id,
                date: point.date,
                value: point.value,
                series: point.intent.rawValue.capitalized,
                isPrimary: point.intent == .hypertrophy,
                intent: point.intent
            )
        }
    }

    /// How VoiceOver reads a point's value.
    private func spokenValue(_ value: Double) -> String {
        let unit = WeightUnit.effective(for: exercise, default: defaultUnit).rawValue
        switch metric {
        case .e1RM, .topSet:
            return "\(Int(value.rounded())) \(unit)"
        case .volume:
            return "\(Int(value.rounded()).formatted()) \(unit)"
        case .averageRPE:
            return "RPE \(value.formatted(.number.precision(.fractionLength(0...1))))"
        }
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

    // MARK: - Branch A: empty state

    private var emptyStateLayout: some View {
        VStack(spacing: 8) {
            Text("Not enough data")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text(metric == .averageRPE
                 ? "Log RPE in 2 workouts to see your trend."
                 : "Log 2 sessions to see your trend.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.vertical, 32)
        .background(Color.bruBg)
    }

    // MARK: - Branch B: chart

    @ViewBuilder
    private func chartLayout(
        points: [ChartPoint],
        highRepSuppressed: Bool
    ) -> some View {
        let prValue = metric.plotsE1RM ? (points.map(\.value).max() ?? 0) : 0
        let hypCount = Set(
            points.filter { $0.intent == .hypertrophy }.map(\.date)
        ).count
        let strCount = Set(
            points.filter { $0.intent == .strength }.map(\.date)
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

                // Data series — one line per series, so the lines never join
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.axisName, point.value),
                        series: .value("Series", point.series)
                    )
                    .foregroundStyle(point.isPrimary ? Color.bruInk : Color.bruSignal)
                    .lineStyle(StrokeStyle(
                        lineWidth: 2,
                        dash: point.isPrimary ? [] : [6, 3]
                    ))
                    .interpolationMethod(.linear)
                    .accessibilityHidden(true)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.axisName, point.value)
                    )
                    .foregroundStyle(point.isPrimary ? Color.bruInk : Color.bruSignal)
                    .symbol(point.isPrimary ? .square : .circle)
                    .symbolSize(point.isPrimary ? 50 : 40)
                    .accessibilityLabel("\(point.series), \(point.date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue(spokenValue(point.value))
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
            .accessibilityLabel(metric.chartName)
            .accessibilityIdentifier("progress.chart")
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

    /// One key per line on the chart, in its line style.
    private struct LegendKey: Identifiable {
        let label: String
        let isPrimary: Bool
        var id: String { label }
    }

    /// The e1RM chips draw the top set and the all-set average; VOLUME and
    /// AVG RPE draw one line per intent.
    private func legendKeys(hypCount: Int, strCount: Int) -> [LegendKey] {
        switch metric {
        case .e1RM:
            return [
                LegendKey(label: SeriesKind.topSet.displayLabel, isPrimary: true),
                LegendKey(label: SeriesKind.allSetAvg.displayLabel, isPrimary: false),
            ]
        case .topSet:
            return [LegendKey(label: SeriesKind.topSet.displayLabel, isPrimary: true)]
        case .volume, .averageRPE:
            return [
                LegendKey(label: "HYPERTROPHY · \(hypCount) SESSIONS", isPrimary: true),
                LegendKey(label: "STRENGTH · \(strCount) SESSIONS", isPrimary: false),
            ]
        }
    }

    @ViewBuilder
    private func legendRow(hypCount: Int, strCount: Int) -> some View {
        HStack(spacing: 16) {
            ForEach(legendKeys(hypCount: hypCount, strCount: strCount)) { key in
                HStack(spacing: 4) {
                    legendSwatch(isPrimary: key.isPrimary)
                    Text(key.label)
                        .font(BRUFont.labelMicro)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                }
            }
        }
        .padding(.top, 4)
    }

    /// Solid bruInk for the primary line, dashed bruSignal (via Canvas)
    /// for the other.
    @ViewBuilder
    private func legendSwatch(isPrimary: Bool) -> some View {
        if isPrimary {
            Rectangle()
                .fill(Color.bruInk)
                .frame(width: 16, height: 2)
        } else {
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
        }
    }
}
