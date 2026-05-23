//
//  WeeklyTonnageView.swift
//  fitbod
//
//  Wave-4 plan 06-06 — Swift Charts BarMark weekly tonnage chart
//  (CONTEXT D-18..D-21 + REQUIREMENTS PROG-04). Three horizontal-
//  scroll filter chip rows sit above the chart; the chart itself is
//  rendered by an inner `WeeklyTonnageChartHost` view that holds the
//  date-bounded `@Query<SetEntry>` so the outer view stays stable.
//
//  ## Outer/inner @Query split (PATTERNS §Pattern D)
//
//  `WeeklyTonnageView` (outer) owns the @State ChartFilterState +
//  the injectable MuscleVolumeProvider.
//  `WeeklyTonnageChartHost` (inner) reads the @Query<SetEntry>
//  filtered by `filterState.timeRange.lowerBound(now:)` so changing
//  the time-range chip rebuilds the @Query predicate via a fresh
//  init of the inner view.
//
//  ## MuscleVolumeProvider DI seam (CONTEXT D-20)
//
//  Default provider is `UnweightedMuscleVolumeProvider()` — Phase 5's
//  stimulus-weighted implementation drops in via a one-line edit at
//  the ProgressHomeView call site without touching this file.
//
//  ## Bar tap → WeekDetailView (CONTEXT D-21)
//
//  Implemented via `.chartOverlay { proxy in ... }` with a clear
//  Rectangle that catches `.onTapGesture(coordinateSpace: .local)`
//  and translates the x-coordinate back to a `Date` via
//  `proxy.value(atX:)`. The detected date snaps to its containing
//  bar's weekStart by re-running the same ISO-calendar bucketing.
//  When the user taps inside the chart area but not on a bar, the
//  closest-bar tolerance heuristic is intentionally absent in v1 —
//  this keeps the hit logic auditable.
//
//  [CITED: CONTEXT D-18..D-21 + UI-SPEC § Chart Styling
//   WeeklyTonnageView + PATTERNS §Pattern D]
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
    @State private var filterState = ChartFilterState()
    @State private var navigationDestination: Date?
    private let provider: MuscleVolumeProvider

    public init(provider: MuscleVolumeProvider = UnweightedMuscleVolumeProvider()) {
        self.provider = provider
    }

    public var body: some View {
        VStack(spacing: 8) {
            TimeRangeChipRow(selection: $filterState.timeRange)
            BlockPhaseChipRow(selection: $filterState.blockPhases)
            MuscleChipRow(selection: $filterState.selectedMuscles)
            WeeklyTonnageChartHost(
                filterState: filterState,
                provider: provider,
                onBarTap: { date in
                    navigationDestination = date
                }
            )
            Spacer(minLength: 0)
        }
        .navigationTitle("Weekly Tonnage")
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
        VStack(alignment: .leading, spacing: 8) {
            if bars.isEmpty {
                emptyState
            } else {
                summaryLine(bars: bars)
                chart(bars: bars, weekStartsMonday: weekStartsMonday)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("Not enough data")
                .font(.headline)
            Text("Log one week of training to see tonnage.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 24)
    }

    private func summaryLine(bars: [WeeklyTonnageBar]) -> some View {
        let total = bars.reduce(0.0) { $0 + $1.totalTonnage }
        let totalKg = Int(total.rounded())
        return Text("\(totalKg) kg over \(bars.count) weeks")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chart(bars: [WeeklyTonnageBar], weekStartsMonday: Bool) -> some View {
        let previousBest = bars.map(\.totalTonnage).max() ?? 0
        Chart {
            ForEach(bars, id: \.weekStart) { week in
                if filterState.selectedMuscles.isEmpty {
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Tonnage (kg)", week.totalTonnage)
                    )
                    .foregroundStyle(Color.accentColor)
                } else {
                    ForEach(week.muscleBreakdown ?? [], id: \.muscleID) { slice in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Tonnage (kg)", slice.tonnage)
                        )
                        .foregroundStyle(by: .value("Muscle", slice.muscleName))
                    }
                }
            }
            if bars.count >= 2 {
                RuleMark(y: .value("Previous best", previousBest))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("Previous best")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear))
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(minHeight: 280)
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
