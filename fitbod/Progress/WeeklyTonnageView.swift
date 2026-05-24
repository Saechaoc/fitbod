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
//  ## Bar tap → WeekDetailView (CONTEXT D-21)
//
//  Preserved unchanged via .chartOverlay + GeometryReader hit-test that translates
//  x-coordinate to an ISO week-start Date, then triggers navigationDestination.
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

    private func heroSummary(bars: [WeeklyTonnageBar]) -> some View {
        let total = bars.reduce(0.0) { $0 + $1.totalTonnage }
        let totalKg = Int(total.rounded())
        let unitLabel = "KG"
        let totalFormatted = totalKg >= 1_000
            ? String(format: "%d,%03d", totalKg / 1_000, totalKg % 1_000)
            : "\(totalKg)"

        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL · \(bars.count) WEEKS")
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

    @ViewBuilder
    private func chart(bars: [WeeklyTonnageBar], weekStartsMonday: Bool) -> some View {
        // RuleMark value: the overall max week tonnage (used as "previous best" reference)
        let previousBest = bars.map(\.totalTonnage).max() ?? 0

        VStack(alignment: .leading, spacing: 4) {
            // Y-axis label above the chart frame
            Text("TONNAGE (KG)")
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
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Tonnage (kg)", week.totalTonnage)
                        )
                        .foregroundStyle(Color.bruInk)
                        .cornerRadius(0)
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
                                x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Tonnage (kg)", slice.tonnage)
                            )
                            .foregroundStyle(by: .value("Muscle", slice.muscleName))
                            .cornerRadius(0)
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
            // X-axis: bruMuted mono labels, bruHair gridlines
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisGridLine()
                        .foregroundStyle(Color.bruHair)
                    AxisTick()
                        .foregroundStyle(Color.bruMuted)
                    AxisValueLabel()
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
                            // Snap to the containing ISO week start.
                            var calendar = Calendar(identifier: .iso8601)
                            calendar.firstWeekday = weekStartsMonday ? 2 : 1
                            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return }
                            onBarTap(interval.start)
                        }
                }
            }
        }
    }
}
