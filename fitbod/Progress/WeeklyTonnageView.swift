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
//  - Bar fill (a RectangleMark over each week's span): Color.bruInk (single-color mode).
//  - Stacked-bar (muscle filter active): Plan B — system palette per muscle name.
//    WeeklyTonnageAggregator groups slices by muscle, not by intent. Extending
//    the aggregator to carry intent would be a new data-path change (deviation
//    Rule 4 architectural scope); Plan B is explicitly permitted by UI-SPEC §Design
//    Pivot #7 disclaimer ("sketch fidelity lets the system palette stand for
//    stacked muscle mode"). BRU intent palette (bruInk/bruInk@0.4/bruMuted) is
//    applied to the BASELINE (non-stacked) bar only.
//  - Chart grid: bruHair dashed gridlines, bruMuted BRUFont.labelSmall axis labels.
//  - RuleMark: bruMuted, StrokeStyle(lineWidth:1, dash:[2,4]), BRUFont.labelMicro
//    annotation above the rule's trailing end, inside the plot.
//  - Background: Color.bruPaper.
//
//  ## Outer/inner @Query split (PATTERNS §Pattern D)
//
//  WeeklyTonnageView (outer) owns @State ChartFilterState + DI provider.
//  WeeklyTonnageChartHost (inner) reads @Query<SetEntry> filtered by time range.
//
//  ## Weeks
//
//  The chart places its bars, marks its x axis and snaps bar taps in the
//  aggregator's week calendar, `WeeklyTonnageAggregator.weekCalendar`, with
//  the user's week-start setting, never the device calendar. It works out
//  each bar's week itself and hands Swift Charts plain dates, never a
//  calendar or a date unit to bin by. Last 8 wk and Last 26 wk hold 8 and
//  26 whole weeks, this one included, so the label never reads more weeks
//  than the range. Its x axis covers the whole selected range, so one week
//  of data draws one narrow bar.
//
//  ## Bar tap → WeekDetailView (CONTEXT D-21)
//
//  A .chartOverlay + GeometryReader hit-test translates the x-coordinate to
//  the start of its chart week, then triggers navigationDestination.
//  VoiceOver reads one element per week with data, over its bar, which
//  opens the same week when activated.
//
//  [CITED: CONTEXT D-18..D-21 + UI-SPEC v2 §Design Pivot #7 + §Reference mockup map]
//

import Charts
import SwiftData
import SwiftUI

// MARK: - TimeRangeChoice → lowerBound helper

extension TimeRangeChoice {
    /// Inclusive lower bound for the `@Query<SetEntry>` predicate: the
    /// start of the week 7 (Last 8 wk) or 25 (Last 26 wk) weeks before the
    /// one that holds `now`, in `calendar`, so the range holds 8 or 26
    /// whole weeks, this one included. `nil` means "no lower bound" (All
    /// time).
    public func lowerBound(now: Date, calendar: Calendar) -> Date? {
        let weeks: Int
        switch self {
        case .last8wk:
            weeks = 8
        case .last26wk:
            weeks = 26
        case .allTime:
            return nil
        }
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return calendar.date(byAdding: .weekOfYear, value: 1 - weeks, to: thisWeek)
    }
}

// MARK: - WeeklyTonnageView (outer)

public struct WeeklyTonnageView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var userSettingsList: [UserSettings]
    @State private var filterState = ChartFilterState()
    @State private var navigationDestination: Date?
    private let provider: MuscleVolumeProvider

    public init(provider: MuscleVolumeProvider = UnweightedMuscleVolumeProvider()) {
        self.provider = provider
    }

    public var body: some View {
        let weekStartsMonday = userSettingsList.first?.weekStartsMonday ?? true

        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
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
                        weekStartsMonday: weekStartsMonday,
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
            WeekDetailView(weekStart: weekStart, weekStartsMonday: weekStartsMonday)
        }
    }
}

// MARK: - WeeklyTonnageChartHost (inner @Query host)

private struct WeeklyTonnageChartHost: View {
    @Query private var sets: [SetEntry]
    @Environment(\.weightUnit) private var weightUnit
    /// Where each bar's week lies on the chart, read off the chart's proxy
    /// after it lays out, so VoiceOver's week elements cover their bars.
    @State private var weekSlots: [Date: CGRect] = [:]
    let filterState: ChartFilterState
    let weekStartsMonday: Bool
    let provider: MuscleVolumeProvider
    let onBarTap: (Date) -> Void
    /// The moment the query and the axis both read the range from, so they
    /// never disagree on its weeks, even past midnight at a week's end.
    private let now: Date

    init(
        filterState: ChartFilterState,
        weekStartsMonday: Bool,
        provider: MuscleVolumeProvider,
        onBarTap: @escaping (Date) -> Void
    ) {
        let now = Date.now
        let calendar = WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: weekStartsMonday)
        let lowerBound = filterState.timeRange.lowerBound(now: now, calendar: calendar)
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
        self.filterState = filterState
        self.weekStartsMonday = weekStartsMonday
        self.provider = provider
        self.onBarTap = onBarTap
        self.now = now
    }

    var body: some View {
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
            now: now,
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
                // Each bar over the middle of its week. Swift Charts gets
                // plain dates, never a calendar or unit to bin by.
                ForEach(WeeklyTonnageChartWeeks.plotted(bars, calendar: calendar)) { week in
                    if filterState.selectedMuscles.isEmpty {
                        // Baseline mode: single bruInk bar, a rectangle over
                        // its span, since BarMark takes no date span
                        RectangleMark(
                            xStart: .value("Week", week.span.lowerBound),
                            xEnd: .value("Week", week.span.upperBound),
                            yStart: .value("Tonnage (\(weightUnit.rawValue))", 0.0),
                            yEnd: .value("Tonnage (\(weightUnit.rawValue))", week.bar.totalTonnage)
                        )
                        .foregroundStyle(Color.bruInk)
                        .cornerRadius(0)
                        .accessibilityLabel(spokenWeek(week.bar.weekStart))
                        .accessibilityValue(spokenTonnage(week.bar.totalTonnage))
                    } else {
                        // Muscle-stacked mode (Plan B): system palette per muscle name.
                        // WeeklyTonnageAggregator groups by muscle, not intent.
                        // BRU intent palette (strength/hypertrophy/deload) requires an
                        // intent field on MuscleSlice — a new data-path (Rule 4 scope).
                        // Plan B is explicitly permitted by UI-SPEC §Design Pivot #7
                        // disclaimer: "sketch fidelity lets the system palette stand for
                        // stacked muscle mode."
                        ForEach(WeeklyTonnageChartWeeks.stacked(week.bar.muscleBreakdown ?? [])) { stack in
                            RectangleMark(
                                xStart: .value("Week", week.span.lowerBound),
                                xEnd: .value("Week", week.span.upperBound),
                                yStart: .value("Tonnage (\(weightUnit.rawValue))", stack.base),
                                yEnd: .value("Tonnage (\(weightUnit.rawValue))", stack.base + stack.slice.tonnage)
                            )
                            .foregroundStyle(by: .value("Muscle", stack.slice.muscleName))
                            .cornerRadius(0)
                            .accessibilityLabel("\(spokenWeek(week.bar.weekStart)), \(stack.slice.muscleName)")
                            .accessibilityValue(spokenTonnage(stack.slice.tonnage))
                        }
                    }
                }

                // RuleMark "previous best" — bruMuted dashed, BRUFont.labelMicro annotation
                // above the rule's trailing end, inside the plot. At .topTrailing,
                // past the rule's end, Swift Charts cut it at the chart's edge, so
                // the small phone read "PREVIOU".
                if bars.count >= 2 {
                    RuleMark(y: .value("Previous best", previousBest))
                        .foregroundStyle(Color.bruMuted)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .annotation(position: .top, alignment: .trailing) {
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
            // Replaces the marks' elements rather than hiding the marks,
            // which would take the chart's audio graph with them.
            .accessibilityChildren {
                weekElements(bars)
            }
            // Preserve existing bar-tap → WeekDetailView drill logic
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    let slots = proxy.plotFrame.map { plotFrame in
                        Self.slots(of: bars, calendar: calendar, proxy: proxy, plot: geometry[plotFrame])
                    } ?? [:]
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
                        // VoiceOver opens weeks through the week elements.
                        .accessibilityHidden(true)
                        .onChange(of: slots, initial: true) { _, slots in
                            weekSlots = slots
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - VoiceOver's weeks

    /// Each bar's week on the chart: from its week start to the next, the
    /// plot's full height, in the chart's space.
    private static func slots(
        of bars: [WeeklyTonnageBar],
        calendar: Calendar,
        proxy: ChartProxy,
        plot: CGRect
    ) -> [Date: CGRect] {
        var slots: [Date: CGRect] = [:]
        for week in bars {
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week.weekStart),
                  let start = proxy.position(forX: week.weekStart),
                  let end = proxy.position(forX: next) else { continue }
            slots[week.weekStart] = CGRect(x: plot.minX + start, y: plot.minY, width: end - start, height: plot.height)
        }
        return slots
    }

    /// VoiceOver's elements for the chart: one per week with data, over
    /// its bar, named by its week and read as its tonnage, that opens the
    /// week when activated, as a tap on its bar does. Swift Charts' own
    /// read many weeks a month at a time, such as "Sep 1, 2026 to Oct 1,
    /// 2026", and opened nothing.
    private func weekElements(_ bars: [WeeklyTonnageBar]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(bars, id: \.weekStart) { week in
                if let slot = weekSlots[week.weekStart] {
                    Rectangle()
                        .frame(width: slot.width, height: slot.height)
                        .position(x: slot.midX, y: slot.midY)
                        .accessibilityLabel(spokenWeek(week.weekStart))
                        .accessibilityValue(spokenValue(of: week))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onBarTap(week.weekStart) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// What VoiceOver reads for a week: its tonnage, or with a muscle
    /// filter on, each muscle's part of it, as the bar stacks them.
    private func spokenValue(of week: WeeklyTonnageBar) -> String {
        guard let slices = week.muscleBreakdown else { return spokenTonnage(week.totalTonnage) }
        guard !slices.isEmpty else { return spokenTonnage(0) }
        return slices.map { "\($0.muscleName), \(spokenTonnage($0.tonnage))" }.joined(separator: "; ")
    }
}

// MARK: - WeeklyTonnageChartWeeks

/// The weeks the Weekly Tonnage chart draws. It places its bars, marks its
/// axis and snaps bar taps in `WeeklyTonnageAggregator.weekCalendar`, the
/// aggregator's own calendar with the user's week-start setting, never the
/// device calendar, which starts weeks on Sunday in the US, so a Sunday
/// workout sits in the same week on the chart as in the totals. Its axis
/// covers the whole selected range, so one week of data draws one narrow
/// bar.
enum WeeklyTonnageChartWeeks {
    /// The calendar the chart draws its weeks in: the one
    /// `WeeklyTonnageAggregator` buckets them with.
    static func calendar(weekStartsMonday: Bool) -> Calendar {
        WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: weekStartsMonday)
    }

    /// The x axis's weeks: the range's whole weeks through the end of the
    /// current week, 8 for Last 8 wk and 26 for Last 26 wk. All time
    /// starts at the oldest bar's week, but never later than Last 8 wk
    /// does. A bar outside those weeks widens them, so no bar is drawn off
    /// the plot.
    static func domain(
        for range: TimeRangeChoice,
        bars: [WeeklyTonnageBar],
        now: Date,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let firstWeek = range.lowerBound(now: now, calendar: calendar)
            ?? TimeRangeChoice.last8wk.lowerBound(now: now, calendar: calendar)
            ?? now
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

    /// Where the bar of the week from `weekStart` is drawn: the middle 70%
    /// of its week, as wide as Swift Charts drew a week-binned bar, so
    /// neighbors keep a gap. The chart works out each week here and hands
    /// Swift Charts plain dates, never a unit or calendar to bin by: Weekly
    /// Tonnage crashed now and then inside Swift Charts, on a Dictionary
    /// key that broke Hashable, once it was given a calendar to bin weeks.
    static func barSpan(of weekStart: Date, calendar: Calendar) -> ClosedRange<Date> {
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)
            ?? weekStart.addingTimeInterval(7 * 24 * 3600)
        let inset = weekEnd.timeIntervalSince(weekStart) * 0.15
        return weekStart.addingTimeInterval(inset)...weekEnd.addingTimeInterval(-inset)
    }

    /// A bar as the chart plots it: its week's totals, and the span of its
    /// week it is drawn over. Its id is its week start.
    struct PlottedWeek: Identifiable {
        let bar: WeeklyTonnageBar
        let span: ClosedRange<Date>
        var id: Date { bar.weekStart }
    }

    /// `bars` as the chart plots them, each over `barSpan(of:calendar:)`.
    static func plotted(_ bars: [WeeklyTonnageBar], calendar: Calendar) -> [PlottedWeek] {
        bars.map { PlottedWeek(bar: $0, span: barSpan(of: $0.weekStart, calendar: calendar)) }
    }

    /// One muscle's part of a stacked bar, from `base` up.
    struct StackedSlice: Identifiable {
        let slice: MuscleSlice
        let base: Double
        var id: UUID { slice.muscleID }
    }

    /// A week's muscle slices stacked bottom up in their order, each from
    /// the top of the one below it.
    static func stacked(_ slices: [MuscleSlice]) -> [StackedSlice] {
        var base = 0.0
        return slices.map { slice in
            defer { base += slice.tonnage }
            return StackedSlice(slice: slice, base: base)
        }
    }
}
