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
//    BRUHeaderBar (‹ dismiss | PROGRESS)
//    ↓
//    Name row (the exercise's whole name, wrapping: the bar's middle
//    third cuts long names short on the 390pt phone)
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
//  VoiceOver reads each point by itself, by its series and date, then
//  its value ("112 lb", "2,140 lb", "RPE 7.6"). The chart's audio graph
//  is ProgressChartDescriptor, not the one Swift Charts makes: dates on
//  the x axis, values read the same way on the y axis, and a series per
//  line drawn, named as the legend names it. The PR rule and the
//  above-10-reps caption are e1RM only. The legend names the lines
//  drawn, each beside a stretch of its line: TOP SET and ALL-SET AVG on
//  e1RM, TOP SET alone on TOP SET; on VOLUME and AVG RPE,
//  HYPERTROPHY · N SESSIONS and STRENGTH · N SESSIONS, then POWER,
//  ENDURANCE and TECHNIQUE · N SESSIONS for each of those drawn. Keys
//  that run out of width wrap onto the next row.
//
//  ## Chart styling (BRU contract)
//
//    LineMark / PointMark per plotted point, one line per series, 2pt
//    wide, in the series' ChartLineStyle:
//      ink     top set, hypertrophy   bruInk     solid          square   50
//      signal  all-set avg, strength  bruSignal  dash [6, 3]    circle   40
//      blue    power                  bruBlue    dots [2, 3]    triangle 50
//      green   endurance              bruGreen   [8, 3, 2, 3]   diamond  50
//      muted   technique              bruMuted   dash [12, 4]   cross    50
//    PR RuleMark → foregroundStyle(Color.bruSignal) lineStyle(dash [4, 2])
//    PR label → chart overlay, just above the rule at the plot's
//               trailing edge, kept inside the plot
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

import Accessibility
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
                left: HeaderAction("‹ Back") { dismiss() },
                center: "Progress"
            )
            nameRow
            BRUDivider(.hair)

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

    /// The exercise's whole name in the bar's title style. The bar gives
    /// its title a third of the row, so the name gets the full width here
    /// and wraps instead of being cut short.
    private var nameRow: some View {
        Text(exercise.name)
            .font(BRUFont.labelSmall)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruInk)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Plotted point

/// One point the chart draws for the selected chip. Internal, so the
/// audio graph's tests can make one.
struct ChartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    /// The line the point belongs to, and its name for VoiceOver.
    let series: String
    /// How its line is drawn, and the legend's swatch for it.
    let style: ChartLineStyle
    let intent: Intent
}

/// How a line on the chart and its points are drawn, and the swatch that
/// keys the line in the legend. On the e1RM chips the top set and the
/// all-set average have one each; on VOLUME and AVG RPE each intent
/// does. The cases are in the legend's order. Blue, green and muted each
/// reach 3:1 against `bruBg` in light and dark (WCAG 1.4.11).
enum ChartLineStyle: Int, Comparable {
    /// The top set and hypertrophy: solid ink, squares.
    case ink
    /// The all-set average and strength: dashed signal, circles.
    case signal
    /// Power: dotted blue, triangles.
    case blue
    /// Endurance: dash-dot green, diamonds.
    case green
    /// Technique: long-dashed muted, crosses.
    case muted

    init(intent: Intent) {
        switch intent {
        case .hypertrophy: self = .ink
        case .strength:    self = .signal
        case .power:       self = .blue
        case .endurance:   self = .green
        case .technique:   self = .muted
        }
    }

    var color: Color {
        switch self {
        case .ink:    return .bruInk
        case .signal: return .bruSignal
        case .blue:   return .bruBlue
        case .green:  return .bruGreen
        case .muted:  return .bruMuted
        }
    }

    /// The line's dash pattern; empty for a solid line.
    var dash: [CGFloat] {
        switch self {
        case .ink:    return []
        case .signal: return [6, 3]
        case .blue:   return [2, 3]
        case .green:  return [8, 3, 2, 3]
        case .muted:  return [12, 4]
        }
    }

    /// The dash pattern at the legend swatch's 16pt.
    var swatchDash: [CGFloat] {
        switch self {
        case .ink:    return []
        case .signal: return [3, 2]
        case .blue:   return [2, 2]
        case .green:  return [5, 2, 2, 2]
        case .muted:  return [6, 2]
        }
    }

    var symbol: BasicChartSymbolShape {
        switch self {
        case .ink:    return .square
        case .signal: return .circle
        case .blue:   return .triangle
        case .green:  return .diamond
        case .muted:  return .cross
        }
    }

    var symbolSize: CGFloat { self == .signal ? 40 : 50 }

    static func < (lhs: ChartLineStyle, rhs: ChartLineStyle) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private extension Intent {
    /// This intent's line on VOLUME and AVG RPE, named in the legend and
    /// the audio graph by the workouts it plots: HYPERTROPHY · 2 SESSIONS.
    func lineName(sessions: Int) -> String {
        "\(rawValue.uppercased()) · \(BRUCountLabel.text(sessions, "SESSION"))"
    }
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

    /// How VoiceOver reads a value on this chip's chart, by each point and
    /// on the audio graph's y axis.
    func spokenValue(_ value: Double, unit: WeightUnit) -> String {
        switch self {
        case .e1RM, .topSet:
            return "\(wholeWeight(value)) \(unit.rawValue)"
        case .volume:
            return "\(wholeWeight(value).formatted()) \(unit.rawValue)"
        case .averageRPE:
            return "RPE \(value.formatted(.number.precision(.fractionLength(0...1))))"
        }
    }
}

/// A weight in whole units, halves up, so the hero, the PR label and
/// VoiceOver all read 112.5 as 113. `%.0f` rounds a half to the even
/// number instead.
private func wholeWeight(_ value: Double) -> Int {
    Int(value.rounded())
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
                        style: point.kind == .topSet ? .ink : .signal,
                        intent: point.intent
                    )
                }
        case .volume:
            return workoutChartPoints(SeriesBuilder.volumePoints(from: sessionExercises))
        case .averageRPE:
            return workoutChartPoints(SeriesBuilder.averageRPEPoints(from: sessionExercises))
        }
    }

    /// One line per intent, each in its intent's style, as the legend keys it.
    private func workoutChartPoints(_ points: [WorkoutSeriesPoint]) -> [ChartPoint] {
        points.map { point in
            ChartPoint(
                id: point.id,
                date: point.date,
                value: point.value,
                series: point.intent.rawValue.capitalized,
                style: ChartLineStyle(intent: point.intent),
                intent: point.intent
            )
        }
    }

    /// The unit this exercise's weights are labeled in: its own override,
    /// else the lifter's setting. A label only; the numbers are as logged.
    private var unit: WeightUnit {
        WeightUnit.effective(for: exercise, default: defaultUnit)
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
        let unitLabel = unit.rawValue.uppercased()
        let latest = wholeWeight(hero.latest)
        let earliest = wholeWeight(hero.earliest)
        // The change is the value minus the FROM number, as both are shown.
        let delta = latest - earliest
        let deltaSigned = delta >= 0
            ? "+ \(delta) \(unitLabel)"
            : "- \(abs(delta)) \(unitLabel)"
        let weeksLabel = "\(hero.weeks) WEEK\(hero.weeks == 1 ? "" : "S")"

        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EST. 1 REP MAX · \(weeksLabel)")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                BRUDisplay(
                    "\(latest) \(unitLabel)",
                    size: .hero
                )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                BRUChip(deltaSigned, color: .bruSignal, fill: true, textCase: nil)
                Text(verbatim: "FROM \(earliest) \(unitLabel)")
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

        VStack(alignment: .leading, spacing: 8) {
            Chart {
                // PR RuleMark — dashed bruSignal; its label is a chart
                // overlay, and VoiceOver reads the PR once, by that label
                if prValue > 0 {
                    RuleMark(y: .value("PR", prValue))
                        .foregroundStyle(Color.bruSignal)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .accessibilityHidden(true)
                }

                // Data series — one line per series, so the lines never join
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.axisName, point.value),
                        series: .value("Series", point.series)
                    )
                    .foregroundStyle(point.style.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: point.style.dash))
                    .interpolationMethod(.linear)
                    .accessibilityHidden(true)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.axisName, point.value)
                    )
                    .foregroundStyle(point.style.color)
                    .symbol(point.style.symbol)
                    .symbolSize(point.style.symbolSize)
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
            // Replaces the marks' elements rather than hiding the marks,
            // which would take the chart's audio graph with them.
            .accessibilityChildren {
                pointElements(points)
            }
            // Its own audio graph: the one Swift Charts makes reads the
            // y axis unrounded and without a unit, and names no line.
            .accessibilityChartDescriptor(
                ProgressChartDescriptor(metric: metric, points: points, unit: unit)
            )
            // After the chart's label and identifier, so the PR label
            // keeps its own text for VoiceOver.
            .chartOverlay { proxy in
                if prValue > 0 {
                    prLabel(prValue, proxy: proxy)
                }
            }
            // A new chart per chip: morphing marks between e1RM, volume
            // and RPE scales gives SwiftUI non-finite frames mid-animation.
            .id(metric)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Legend row below chart
            legendRow(points: points)
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

    /// The PR rule's label: just above the rule, 4pt in from the plot's
    /// trailing edge, and never above the plot's top, so it stays inside
    /// the chart. An overlay, because Charts keeps mark annotations out of
    /// reach of VoiceOver.
    private func prLabel(_ value: Double, proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let plotFrame = proxy.plotFrame,
               let ruleY = proxy.position(forY: value) {
                let plot = geometry[plotFrame]
                Text(verbatim: "PR \(wholeWeight(value))")
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
                    .padding(.trailing, 4)
                    // Bottom 2pt above the rule, top no higher than the plot's.
                    .alignmentGuide(.top) { label in min(0, label.height + 2 - ruleY) }
                    .frame(width: plot.width, height: plot.height, alignment: .topTrailing)
                    .offset(x: plot.minX, y: plot.minY)
            }
        }
    }

    /// VoiceOver's elements for the points: one per point, read by its
    /// series and date, then its value. Swift Charts' own group the points
    /// in a stretch of dates, so e1RM's top set and all-set average read
    /// as one unrounded range. Each date is a column, left to right, with
    /// the top set above the all-set average as drawn, and a container,
    /// so VoiceOver reads a date's points before the next date's.
    @ViewBuilder
    private func pointElements(_ points: [ChartPoint]) -> some View {
        let byDate = Dictionary(grouping: points, by: \.date)
        HStack(spacing: 0) {
            ForEach(byDate.keys.sorted(), id: \.self) { date in
                VStack(spacing: 0) {
                    ForEach(byDate[date, default: []].sorted { $0.style < $1.style }) { point in
                        Rectangle()
                            .accessibilityLabel("\(point.series), \(date.formatted(date: .abbreviated, time: .omitted))")
                            .accessibilityValue(metric.spokenValue(point.value, unit: unit))
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    // MARK: - Legend

    /// One key per line on the chart, in its line style.
    private struct LegendKey: Identifiable {
        let label: String
        let style: ChartLineStyle
        var id: String { label }
    }

    /// The e1RM chips draw the top set and the all-set average. VOLUME and
    /// AVG RPE draw one line per intent: HYPERTROPHY and STRENGTH always
    /// have a key, and the other intents have one when their line is drawn.
    private func legendKeys(points: [ChartPoint]) -> [LegendKey] {
        switch metric {
        case .e1RM:
            return [
                LegendKey(label: SeriesKind.topSet.displayLabel, style: .ink),
                LegendKey(label: SeriesKind.allSetAvg.displayLabel, style: .signal),
            ]
        case .topSet:
            return [LegendKey(label: SeriesKind.topSet.displayLabel, style: .ink)]
        case .volume, .averageRPE:
            let drawn = Set(points.map(\.intent))
            return Intent.allCases
                .filter { $0 == .hypertrophy || $0 == .strength || drawn.contains($0) }
                .map { intent in
                    let sessions = Set(points.filter { $0.intent == intent }.map(\.date)).count
                    return LegendKey(label: intent.lineName(sessions: sessions), style: ChartLineStyle(intent: intent))
                }
                .sorted { $0.style < $1.style }
        }
    }

    /// The keys in a row, wrapping onto the next row when they run out of
    /// width.
    @ViewBuilder
    private func legendRow(points: [ChartPoint]) -> some View {
        BRUFlowLayout(spacing: 16, lineSpacing: 6) {
            ForEach(legendKeys(points: points)) { key in
                HStack(spacing: 4) {
                    legendSwatch(key.style)
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

    /// A stretch of the line in `style`: a bar for a solid line, a Canvas
    /// stroke for a dashed one.
    @ViewBuilder
    private func legendSwatch(_ style: ChartLineStyle) -> some View {
        if style.swatchDash.isEmpty {
            Rectangle()
                .fill(style.color)
                .frame(width: 16, height: 2)
        } else {
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(
                    path,
                    with: .color(style.color),
                    style: StrokeStyle(lineWidth: 2, dash: style.swatchDash)
                )
            }
            .frame(width: 16, height: 2)
        }
    }
}

// MARK: - Audio graph

/// The chart's audio graph. The one Swift Charts makes from the marks
/// reads the y axis unrounded and without a unit ("112.5") and names no
/// line. This one reads dates on the x axis and values on the y axis the
/// way each point reads its own ("113 lb", "2,140 lb", "RPE 7.6"), with a
/// series per line drawn, named as the legend names it.
struct ProgressChartDescriptor: AXChartDescriptorRepresentable {
    let metric: ProgressChartMetric
    let points: [ChartPoint]
    /// The unit the exercise's weights are labeled in.
    let unit: WeightUnit

    func makeChartDescriptor() -> AXChartDescriptor {
        let dates = points.map(\.date.timeIntervalSinceReferenceDate)
        let values = points.map(\.value)
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: (dates.min() ?? 0)...(dates.max() ?? 0),
            gridlinePositions: []
        ) { Date(timeIntervalSinceReferenceDate: $0).formatted(date: .abbreviated, time: .omitted) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: metric.axisName,
            range: (values.min() ?? 0)...(values.max() ?? 0),
            gridlinePositions: []
        ) { metric.spokenValue($0, unit: unit) }
        return AXChartDescriptor(
            title: metric.chartName,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }

    /// SwiftUI updates the descriptor it made, rather than asking for a
    /// new one, when the chart's points or unit change.
    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        let current = makeChartDescriptor()
        descriptor.title = current.title
        descriptor.xAxis = current.xAxis
        descriptor.yAxis = current.yAxis
        descriptor.series = current.series
    }

    /// A series per line drawn, its points in date order, in the legend's
    /// order.
    private var series: [AXDataSeriesDescriptor] {
        let grouped: [[ChartPoint]] = Dictionary(grouping: points, by: \.series).values
            .map { line in line.sorted { $0.date < $1.date } }
        let ordered: [[ChartPoint]] = grouped.sorted { lhs, rhs in
            lhs[0].style != rhs[0].style ? lhs[0].style < rhs[0].style : lhs[0].series < rhs[0].series
        }
        return ordered.map { line in
            AXDataSeriesDescriptor(
                name: legendName(of: line),
                isContinuous: true,
                dataPoints: line.map { AXDataPoint(x: $0.date.timeIntervalSinceReferenceDate, y: $0.value) }
            )
        }
    }

    /// The legend's name for a line: TOP SET or ALL-SET AVG on the e1RM
    /// chips; on VOLUME and AVG RPE, its intent and how many workouts it
    /// plots, as in HYPERTROPHY · 2 SESSIONS.
    private func legendName(of line: [ChartPoint]) -> String {
        guard !metric.plotsE1RM else { return line[0].series.uppercased() }
        return line[0].intent.lineName(sessions: Set(line.map(\.date)).count)
    }
}
