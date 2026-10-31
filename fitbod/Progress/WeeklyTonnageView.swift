//
//  WeeklyTonnageView.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — BRUHeaderBar + hero summary band + BRU chart chrome.
//  (CONTEXT D-18..D-21 + REQUIREMENTS PROG-04). Three horizontal-scroll BRU
//  filter chip rows sit above the chart.
//
//  ## BRU chrome overview
//
//  - NavigationStack wrapper removed; BRUHeaderBar replaces .navigationTitle.
//  - Hero total band: uppercase BRUFont.labelSmall caption + BRUDisplay(.large) value.
//  - BarMark baseline fill: Color.bruInk (single-color mode).
//  - Stacked-bar (muscle filter active): Plan B — system palette per muscle name.
//    WeeklyTonnageAggregator groups slices by muscle, not by intent. Extending
//    the aggregator to carry intent would be a new data-path change (deviation
//    Rule 4 architectural scope); Plan B is explicitly permitted by UI-SPEC §Design
//    Pivot #7 disclaimer ("sketch fidelity lets the system palette stand for
//    stacked muscle mode"). BRU intent palette (bruInk/bruInk@0.4/bruMuted) is
//    applied to the BASELINE (non-stacked) bar only.
//  - Chart grid: bruHair dashed gridlines, bruMuted BRUFont.labelSmall axis labels.
//  - RuleMark: bruMuted, StrokeStyle(lineWidth:1, dash:[2,4]), BRUFont.labelMicro.
//  - Background: Color.bruPaper.
//
//  ## Outer/inner @Query split (PATTERNS §Pattern D)
//
//  WeeklyTonnageView (outer) owns @State ChartFilterState + DI provider.
//  WeeklyTonnageChartHost (inner) reads @Query<SetEntry> filtered by time range.
//
//  ## Weeks
//
//  The chart bins its bars, marks its x axis and snaps bar taps with the
//  aggregator's rule, the user's week-start setting, through
//  `WeeklyTonnageChartWeeks`, never the device calendar. Its x axis covers
//  the whole selected range, so one week of data draws one narrow bar.
//
//  ## Bar tap → WeekDetailView (CONTEXT D-21)
//
//  A .chartOverlay + GeometryReader hit-test translates the x-coordinate to
//  the start of its chart week, then triggers navigationDestination.
//
//  [CITED: CONTEXT D-18..D-21 + UI-SPEC v2 §Design Pivot #7 + §Reference mockup map]
//

import Charts
import SwiftData
import SwiftUI

// MARK: - TimeRangeChoice → lowerBound helper

extension TimeRangeChoice {
    /// Inclusive lower bound for the `@Query<SetEntry>` predicate.
    /// `nil` means "no lower bound" (All time).
    public func lowerBound(now: Date) -> Date? {
        switch self {
        case .last8wk:
            return Calendar.current.date(byAdding: .weekOfYear, value: -8, to: now)
        case .last26wk:
            return Calendar.current.date(byAdding: .weekOfYear, value: -26, to: now)
        case .allTime:
            return nil
        }
    }
}

// MARK: - WeeklyTonnageView (outer)

public struct WeeklyTonnageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var filterState = ChartFilterState()
    @State private var navigationDestination: Date?
    private let provider: MuscleVolumeProvider

    public init(provider: MuscleVolumeProvider = UnweightedMuscleVolumeProvider()) {
        self.provider = provider
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹") { dismiss() },
                center: "Weekly Tonnage"
            )

            ScrollView {
                VStack(spacing: 0) {
                    // Filter chip rows
                    VStack(spacing: 8) {
                        TimeRangeChipRow(selection: $filterState.timeRange)
                        BlockPhaseChipRow(selection: $filterState.blockPhases)
                        MuscleChipRow(selection: $filterState.selectedMuscles)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    BRUDivider(.ink)

                    // Chart host (holds @Query)
                    WeeklyTonnageChartHost(
                        filterState: filterState,
                        provider: provider,
                        onBarTap: { date in
                            navigationDestination = date
                        }
                    )
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $navigationDestination) { weekStart in
            WeekDetailView(weekStart: weekStart)
        }
    }
}

// MARK: - WeeklyTonnageChartHost (inner @Query host)

private struct WeeklyTonnageChartHost: View {
    @Query private var sets: [SetEntry]
    @Query private var userSettingsList: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit
    let filterState: ChartFilterState
    let provider: MuscleVolumeProvider
    let onBarTap: (Date) -> Void

    init(
        filterState: ChartFilterState,
        provider: MuscleVolumeProvider,
        onBarTap: @escaping (Date) -> Void
    ) {
        let lowerBound = filterState.timeRange.lowerBound(now: Date.now)
        if let lower = lowerBound {
            let lowerLet = lower
            _sets = Query(
                filter: #Predicate<SetEntry> { entry in
                    entry.isComplete
                        && !entry.isWarmup
                        && entry.completedAt >= lowerLet
                },
                sort: \.completedAt
            )
        } else {
            _sets = Query(
                filter: #Predicate<SetEntry> { entry in
                    entry.isComplete && !entry.isWarmup
                },
                sort: \.completedAt
            )
        }
        _userSettingsList = Query()
        self.filterState = filterState
        self.provider = provider
        self.onBarTap = onBarTap
    }

    var body: some View {
        let weekStartsMonday = userSettingsList.first?.weekStartsMonday ?? true
        let bars = WeeklyTonnageAggregator.aggregate(
            sets: sets,
            weekStartsMonday: weekStartsMonday,
            selectedMuscleIDs: filterState.selectedMuscles,
            provider: provider
        )

        VStack(alignment: .leading, spacing: 0) {
            if bars.isEmpty {
                emptyState
            } else {
                heroSummary(bars: bars)
                BRUDivider(.ink)
                    .padding(.horizontal, 0)
                chart(bars: bars, weekStartsMonday: weekStartsMonday)
            }
        }
    }

    // MARK: - Hero summary band

    /// The app-wide unit, as the hero and the axis title print it. Tonnage
    /// mixes every exercise, so it reads in that unit, and units relabel the
    /// stored numbers without converting them.
    private var unitLabel: String {
        weightUnit.rawValue.uppercased()
    }

    private func heroSummary(bars: [WeeklyTonnageBar]) -> some View {
        let total = bars.reduce(0.0) { $0 + $1.totalTonnage }
        let totalFormatted = Int(total.rounded()).formatted()

        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL · \(BRUCountLabel.text(bars.count, "WEEK"))")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruMuted)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    BRUDisplay("\(totalFormatted)", size: .large)
                    Text(unitLabel)
                        .font(BRUFont.bodyDefault)
                        .tracking(0.5)
                        .foregroundStyle(Color.bruMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Not enough data")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Log one week of training to see tonnage.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 48)
        .padding(.horizontal, 16)
    }

    // MARK: - Chart

    /// VoiceOver's name for a bar: its week as the totals count it, the way
    /// WeekDetailView titles it. Swift Charts would read the device
    /// calendar's week.
    private func spokenWeek(_ weekStart: Date) -> String {
        "Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func spokenTonnage(_ tonnage: Double) -> String {
        "\(Int(tonnage.rounded()).formatted()) \(weightUnit.rawValue)"
    }

    @ViewBuilder
    private func chart(bars: [WeeklyTonnageBar], weekStartsMonday: Bool) -> some View {
        // RuleMark value: the overall max week tonnage (used as "previous best" reference)
        let previousBest = bars.map(\.totalTonnage).max() ?? 0
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        let domain = WeeklyTonnageChartWeeks.domain(
            for: filterState.timeRange,
            bars: bars,
            now: Date.now,
            calendar: calendar
        )
        let weeks = WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar)
        let datedWeeks = WeeklyTonnageChartWeeks.datedWeeks(weeks)

        VStack(alignment: .leading, spacing: 4) {
            // Y-axis label above the chart frame
            Text("TONNAGE (\(unitLabel))")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Chart {
                ForEach(bars, id: \.weekStart) { week in
                    if filterState.selectedMuscles.isEmpty {
                        // Baseline mode: single bruInk bar
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear, calendar: calendar),
                            y: .value("Tonnage (\(weightUnit.rawValue))", week.totalTonnage)
                        )
                        .foregroundStyle(Color.bruInk)
                        .cornerRadius(0)
                        .accessibilityLabel(spokenWeek(week.weekStart))
                        .accessibilityValue(spokenTonnage(week.totalTonnage))
                    } else {
                        // Muscle-stacked mode (Plan B): system palette per muscle name.
                        // WeeklyTonnageAggregator groups by muscle, not intent.
                        // BRU intent palette (strength/hypertrophy/deload) requires an
                        // intent field on MuscleSlice — a new data-path (Rule 4 scope).
                        // Plan B is explicitly permitted by UI-SPEC §Design Pivot #7
                        // disclaimer: "sketch fidelity lets the system palette stand for
                        // stacked muscle mode."
                        ForEach(week.muscleBreakdown ?? [], id: \.muscleID) { slice in
                            BarMark(
                                x: .value("Week", week.weekStart, unit: .weekOfYear, calendar: calendar),
                                y: .value("Tonnage (\(weightUnit.rawValue))", slice.tonnage)
                            )
                            .foregroundStyle(by: .value("Muscle", slice.muscleName))
                            .cornerRadius(0)
                            .accessibilityLabel("\(spokenWeek(week.weekStart)), \(slice.muscleName)")
                            .accessibilityValue(spokenTonnage(slice.tonnage))
                        }
                    }
                }

                // RuleMark "previous best" — bruMuted dashed, BRUFont.labelMicro annotation
                if bars.count >= 2 {
                    RuleMark(y: .value("Previous best", previousBest))
                        .foregroundStyle(Color.bruMuted)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .annotation(position: .topTrailing, alignment: .trailing) {
                            Text("PREVIOUS BEST")
                                .font(BRUFont.labelMicro)
                                .tracking(1.0)
                                .foregroundStyle(Color.bruMuted)
                        }
                }
            }
            // X-axis: a bruHair gridline at every week start, and bruMuted
            // mono dates on about five of them, each as wide as its gap
            .chartXScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: weeks) {
                    AxisGridLine()
                        .foregroundStyle(Color.bruHair)
                    AxisTick()
                        .foregroundStyle(Color.bruMuted)
                }
                AxisMarks(values: datedWeeks) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            // Y-axis: bruHair dashed gridlines, bruMuted mono labels, no tick marks
            .chartYAxis {
                AxisMarks {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .foregroundStyle(Color.bruHair)
                    AxisValueLabel()
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .accessibilityIdentifier("weeklyTonnage.chart")
            .frame(minHeight: 280)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Preserve existing bar-tap → WeekDetailView drill logic
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let plotRect = geometry[plotFrame]
                            let relativeX = location.x - plotRect.minX
                            guard relativeX >= 0, relativeX <= plotRect.width else { return }
                            guard let date: Date = proxy.value(atX: relativeX) else { return }
                            // Snap to the start of the chart week the tap falls in.
                            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return }
                            onBarTap(interval.start)
                        }
                }
            }
        }
    }
}

// MARK: - WeeklyTonnageChartWeeks

/// The weeks the Weekly Tonnage chart draws. It bins its bars, marks its
/// axis and snaps bar taps with the aggregator's rule, the user's
/// week-start setting, never the device calendar, which starts weeks on
/// Sunday in the US, so a Sunday workout sits in the same week on the chart
/// as in the totals. Its axis covers the whole selected range, so one week
/// of data draws one narrow bar.
enum WeeklyTonnageChartWeeks {
    /// The calendar `WeeklyTonnageAggregator` buckets weeks with.
    static func calendar(weekStartsMonday: Bool) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = weekStartsMonday ? 2 : 1
        return calendar
    }

    /// The x axis's weeks: from the week that holds the range's rolling
    /// lower bound through the end of the current week, usually 9 weeks for
    /// Last 8 wk and 27 for Last 26 wk. All time starts at the oldest bar's
    /// week, but never later than Last 8 wk does. A bar outside those weeks
    /// widens them, so no bar is drawn off the plot.
    static func domain(
        for range: TimeRangeChoice,
        bars: [WeeklyTonnageBar],
        now: Date,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let lowerBound = range.lowerBound(now: now) ?? TimeRangeChoice.last8wk.lowerBound(now: now) ?? now
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: lowerBound)?.start ?? lowerBound
        let currentWeekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
        let oldest = bars.map(\.weekStart).min() ?? firstWeek
        let newestEnd = bars.map(\.weekStart).max()
            .flatMap { calendar.date(byAdding: .weekOfYear, value: 1, to: $0) } ?? currentWeekEnd
        return min(firstWeek, oldest)...max(currentWeekEnd, newestEnd)
    }

    /// Every week start from `domain`'s start through its end, oldest
    /// first: the slot edges the axis draws its gridlines on.
    static func weekStarts(in domain: ClosedRange<Date>, calendar: Calendar) -> [Date] {
        var weeks: [Date] = []
        var week = domain.lowerBound
        while week <= domain.upperBound {
            weeks.append(week)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return weeks
    }

    /// About five of `weeks`, evenly spaced from the first, for the axis to
    /// date, so each date has room. The last week start only closes the
    /// axis, so it gets no date.
    static func datedWeeks(_ weeks: [Date]) -> [Date] {
        let starts = weeks.dropLast()
        let stride = max(1, (starts.count + 4) / 5)
        return starts.enumerated().filter { $0.offset % stride == 0 }.map(\.element)
    }
}
