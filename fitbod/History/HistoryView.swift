//
//  HistoryView.swift
//  fitbod
//
//  History tab: every finished workout, newest first, grouped by training
//  week (week start follows Settings). Each row shows the day, the routine
//  snapshot name, duration, sets and volume; tapping opens the summary.
//
//  Replaces the Phase 6 "Progress" placeholder tab so every visible tab
//  does something real in milestone 1.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppRouter.self) private var router
    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var sessions: [Session]
    @Query private var settingsList: [UserSettings]

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.historyPath) {
            Group {
                if sessions.isEmpty {
                    ScrollView {
                        ChalkEmptyState(
                            systemImage: "clock.arrow.circlepath",
                            title: "No workouts yet",
                            message: "Finished workouts land here with every set, total volume and your best lifts.",
                            primaryTitle: "Go to routines",
                            primaryAction: { router.selectedTab = .routines }
                        )
                        .padding(Chalk.Space.gutter)
                    }
                } else {
                    List {
                        ForEach(weeks, id: \.start) { week in
                            Section {
                                ForEach(week.sessions) { session in
                                    NavigationLink(value: AppRoute.workoutSummary(session)) {
                                        HistoryRow(session: session, unitLabel: unitLabel)
                                    }
                                    .listRowBackground(Color.chalkSurface)
                                }
                            } header: {
                                weekHeader(week)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .chalkCanvasBackground()
            .navigationTitle("HISTORY")
            .appRouteDestinations()
        }
    }

    // MARK: Grouping

    struct Week {
        let start: Date
        let sessions: [Session]
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = (settingsList.first?.weekStartsMonday ?? true) ? 2 : 1
        return cal
    }

    private var weeks: [Week] {
        let cal = calendar
        var buckets: [Date: [Session]] = [:]
        for session in sessions {
            let start = cal.dateInterval(of: .weekOfYear, for: session.startedAt)?.start ?? cal.startOfDay(for: session.startedAt)
            buckets[start, default: []].append(session)
        }
        return buckets
            .map { Week(start: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.start > $1.start }
    }

    private func weekHeader(_ week: Week) -> some View {
        let sets = week.sessions.reduce(0) { $0 + WorkoutStats.compute(for: $1).completedSets }
        let count = week.sessions.count
        return HStack {
            Text(weekTitle(week.start))
            Spacer()
            Text("\(count) workout\(count == 1 ? "" : "s") · \(sets) sets")
        }
        .chalkLabelStyle()
        .textCase(nil)
    }

    private func weekTitle(_ start: Date) -> String {
        let cal = calendar
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start
        if start == thisWeek { return "THIS WEEK" }
        if let thisWeek, let last = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek), start == last {
            return "LAST WEEK"
        }
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let from = start.formatted(.dateTime.month(.abbreviated).day())
        let to = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(from) – \(to)".uppercased()
    }

    private var unitLabel: String {
        (settingsList.first?.weightUnit ?? .lb).rawValue
    }
}

/// One finished workout: big day number, routine name, meta line.
struct HistoryRow: View {
    let session: Session
    let unitLabel: String

    var body: some View {
        let stats = WorkoutStats.compute(for: session)
        HStack(spacing: Chalk.Space.md) {
            VStack(spacing: 0) {
                Text(session.startedAt.formatted(.dateTime.day(.twoDigits)))
                    .font(.chalkMetricLarge)
                    .foregroundStyle(.chalkInk)
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated)))
                    .chalkLabelStyle()
            }
            .frame(minWidth: 44)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                Text(session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName)
                    .font(.chalkHeadline)
                    .foregroundStyle(.chalkInk)
                Text(meta(stats))
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
            }
        }
        .padding(.vertical, Chalk.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText(stats)))
        .accessibilityIdentifier("history.row")
    }

    private func meta(_ stats: WorkoutStats) -> String {
        "\(Self.duration(stats.durationSeconds)) · \(stats.completedSets) sets · \(ChalkFormat.volume(stats.volume)) \(unitLabel)"
    }

    private func accessibilityText(_ stats: WorkoutStats) -> String {
        let day = session.startedAt.formatted(date: .complete, time: .omitted)
        let name = session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName
        return "\(name), \(day). \(meta(stats))"
    }

    /// "1 h 9 min" / "58 min".
    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes >= 60 {
            return "\(minutes / 60) h \(minutes % 60) min"
        }
        return "\(minutes) min"
    }
}
