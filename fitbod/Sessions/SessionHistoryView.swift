// SessionHistoryView.swift
// fitbod
//
// Every finished workout, newest first. Pushed on the Today stack (the
// "Sessions" stat cell) and the Progress stack (the "Workouts" row) via
// `SessionHistoryRoute.list`; a row pushes that workout's summary via
// `SessionHistoryRoute.summary`. The host stack registers both with
// `.sessionHistoryDestinations()`.
//
// ## Composition
//
//   BRUHeaderBar (safeAreaInset .top, navigationBarHidden)
//   SessionHistoryStatStrip   sessions · 30d / tonnage · 30d / per week
//   BRUDivider(.ink)
//   WeeklyTonnageSparkCard    8 rolling weeks; hidden until there is tonnage
//   BRUSectionHead("Past sessions", right: "{N} sessions")
//   SessionHistoryRow per session (BRUDivider(.hair) between)
//
// The list shows every finished workout. Empty ones, finished with no
// logged work sets, are left out of the strip and the header's count
// (decision 6).
//
// ## Empty state
//   "No sessions yet" / "Finish a workout to see it here."
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

// MARK: - SessionHistoryView

public struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    private struct RecordsKey: Equatable {
        let sessionIDs: [UUID]
        let edits: Int
    }

    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var sessions: [Session]

    /// Records per session id, rebuilt whenever the list changes.
    @State private var prs: [UUID: SessionPRs] = [:]
    /// The finished workouts that count as sessions, for the header, worked
    /// out with the records. Nil until then, when the header counts every
    /// finished workout.
    @State private var sessionCount: Int?

    public init() {}

    public var body: some View {
        let recent = recentSessions
        ScrollView {
            LazyVStack(spacing: 0) {
                SessionHistoryStatStrip(
                    sessions: recent.count,
                    tonnageLabel: SessionHistoryFormat.compactTonnage(tonnage(of: recent)),
                    perWeekLabel: perWeekLabel,
                    unit: weightUnit
                )
                BRUDivider(.ink)

                if tonnageByWeek.contains(where: { $0 > 0 }) {
                    WeeklyTonnageSparkCard(values: tonnageByWeek, deltaPct: tonnageDeltaPct)
                }

                BRUSectionHead(
                    "Past sessions",
                    right: BRUCountLabel.text(sessionCount ?? sessions.count, "session")
                )

                if sessions.isEmpty {
                    emptyState
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(value: SessionHistoryRoute.summary(sessionID: session.id)) {
                            SessionHistoryRow(
                                session: session,
                                prs: prs[session.id],
                                unit: weightUnit
                            )
                        }
                        .buttonStyle(.bruRow)
                        .accessibilityIdentifier("history.row")
                        BRUDivider(.hair)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            BRUHeaderBar(left: HeaderAction("‹ Back") { dismiss() }, center: "History")
        }
        // A History correction changes sets, not which workouts are listed,
        // so the edit count joins the key.
        .task(id: RecordsKey(sessionIDs: sessions.map(\.id), edits: historyEdits?.version ?? 0)) {
            prs = SessionSummary.prsBySession(sessions)
            // The records pass has just read every finished workout's sets,
            // so the shared rule reads nothing more from the store here.
            sessionCount = SessionSetActions.countedWorkouts(sessions).count
        }
    }

    // MARK: - Stat strip

    /// The last 30 days' workouts that count as sessions.
    private var recentSessions: [Session] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return Array(SessionSetActions.countedWorkouts(sessions.filter { $0.startedAt >= cutoff }))
    }

    /// Average sessions per week over the last 4 weeks, e.g. "0.25" or "2".
    private var perWeekLabel: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now
        let count = SessionSetActions.countedWorkouts(sessions.filter { $0.startedAt >= cutoff }).count
        return SessionHistoryFormat.perWeek(workoutsInFourWeeks: count)
    }

    private func tonnage(of sessions: [Session]) -> Double {
        sessions.reduce(0) { $0 + SessionHistoryFormat.tonnage(of: $1) }
    }

    // MARK: - Spark card

    /// Tonnage for the last 8 rolling 7-day windows, oldest first.
    private var tonnageByWeek: [Double] {
        var weeks = [Double](repeating: 0, count: 8)
        let now = Date.now
        for session in sessions {
            guard let completedAt = session.completedAt else { continue }
            let daysAgo = Calendar.current.dateComponents([.day], from: completedAt, to: now).day ?? 0
            let weekIndex = daysAgo / 7
            guard weekIndex >= 0, weekIndex < 8 else { continue }
            weeks[7 - weekIndex] += SessionHistoryFormat.tonnage(of: session)
        }
        return weeks
    }

    /// This week against last week, in percent. Nil when last week had no
    /// tonnage, since there is nothing to compare against.
    private var tonnageDeltaPct: Double? {
        let weeks = tonnageByWeek
        let current = weeks[7]
        let prior = weeks[6]
        guard prior > 0 else { return nil }
        return ((current / prior) - 1) * 100
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            Text("No sessions yet")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            Text("Finish a workout to see it here.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Formatting shared by the history list

enum SessionHistoryFormat {
    /// An exercise's line on the workout summary and in Edit workout, such
    /// as "3 sets · 1,500 lb". A zero volume is left out.
    /// "3 sets · 4,050 lb"; `noun` is "bout" for cardio (RM-062).
    static func setsLine(count: Int, volume: Double, unit: WeightUnit, noun: String = "set") -> String {
        let sets = BRUCountLabel.text(count, noun)
        guard volume != 0 else { return sets }
        return "\(sets) · \(roundedVolume(volume)) \(unit.rawValue)"
    }

    static func roundedVolume(_ volume: Double, locale: Locale = .autoupdatingCurrent) -> String {
        guard volume.isFinite, volume >= 0, let rounded = Int(exactly: volume.rounded()) else { return "—" }
        return rounded.formatted(.number.grouping(.automatic).locale(locale))
    }

    /// A finished workout's completed, non-warm-up sets. Cardio logs bouts,
    /// which set totals leave out (RM-062); `Session.loggedSetCount` counts
    /// them, since it decides whether a workout logged anything.
    static func setCount(of session: Session) -> Int {
        (session.exercises ?? [])
            .filter { $0.exercise?.isCardio != true }
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
            .count
    }

    /// A workout's tonnage: the sum of `SetEntry.tonnage`.
    static func tonnage(of session: Session) -> Double {
        (session.exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .reduce(0) { $0 + $1.tonnage }
    }

    /// Workouts a week over four weeks, to two decimals at most with
    /// trailing zeros trimmed: one workout reads "0.25", two "0.5" and
    /// eight "2".
    static func perWeek(workoutsInFourWeeks count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        (Double(count) / 4).formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// A workout's length as History and Today show it: "52M", "1H 05M".
    static func duration(minutes: Int) -> String {
        minutes >= 60
            ? "\(minutes / 60)H \(String(format: "%02d", minutes % 60))M"
            : "\(minutes)M"
    }

    /// "4,610" below ten thousand, "71.2k" above.
    static func compactTonnage(_ total: Double) -> String {
        guard WorkoutCorrectionInput.isSupported(total) else { return "—" }
        if total >= 10_000 {
            return (total / 1000).formatted(.number.precision(.fractionLength(1))) + "k"
        }
        return roundedVolume(total)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SessionHistoryView (empty)") {
    NavigationStack {
        SessionHistoryView()
            .sessionHistoryDestinations()
    }
    .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("SessionHistoryView (populated)") {
    NavigationStack {
        SessionHistoryView()
            .sessionHistoryDestinations()
    }
    .modelContainer(PreviewModelContainer.make())
}
#endif
