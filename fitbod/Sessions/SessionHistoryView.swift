// SessionHistoryView.swift
// fitbod — Phase 2.1 Plan 10
//
// NEW — Root of the session history flow.
// UI-SPEC v2 § Session history view (lines 441-458, 590).
//
// ## Composition
//
//   BRUHeaderBar (safeAreaInset .top, navigationBarHidden)
//   SessionHistoryStatStrip
//   BRUDivider(.ink)
//   WeeklyTonnageSparkCard (padded 16pt)
//   BRUSectionHead("Past sessions", right: "{N} sessions")
//   SessionHistoryRow per session (BRUDivider(.hair) between)
//
// ## Data source
//   @Query<Session> filtered to completedAt != nil, sorted by startedAt descending.
//
// ## Empty state (UI-SPEC line 458)
//   "No sessions yet" / "Finish a workout to see it here."
//
// ## Reachability (v1)
//   Wired via RoutinesListView confirmation dialog "History" option (Task 3).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

// MARK: - SessionHistoryView

/// Root of the session history flow — lists all completed sessions with tonnage,
/// a weekly spark chart, and per-row PR badges.
public struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    // T-02.1-10-04 mitigation: simple predicate (completedAt != nil) avoids
    // multi-level optional chain issues. Swift-level filter below if needed.
    @Query(sort: \Session.startedAt, order: .reverse)
    private var allSessions: [Session]

    @State private var presentingFilter = false

    public init() {}

    // Completed sessions only (filter in Swift per T-02.1-10-04 pattern)
    private var sessions: [Session] {
        allSessions.filter { $0.completedAt != nil }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 3-cell stat strip
                    SessionHistoryStatStrip(
                        sessions: sessions30d,
                        tonnageLabel: totalTonnageLabel,
                        adherence: adherencePct
                    )
                    BRUDivider(.ink)

                    // Weekly tonnage spark card
                    WeeklyTonnageSparkCard(
                        values: tonnageByWeek,
                        deltaPct: tonnageDeltaPct
                    )
                    .padding(16)

                    BRUSectionHead("Past sessions", right: "\(sessions.count) sessions")

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessions) { session in
                            SessionHistoryRow(
                                session: session,
                                prBadges: prBadges(for: session)
                            )
                            BRUDivider(.hair)
                        }
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: HeaderAction("‹", action: { dismiss() }),
                    center: "History",
                    right: HeaderAction("FILTER", isSignal: true, action: { presentingFilter = true })
                )
            }
        }
    }

    // MARK: - Computed: stat strip

    private var sessions30d: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return sessions.filter { $0.startedAt >= cutoff }.count
    }

    private var totalTonnageLabel: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        // Break up chained expression to avoid Swift type-checker timeout
        let recentSessions = sessions.filter { $0.startedAt >= cutoff }
        var total: Double = 0
        for session in recentSessions {
            let sets = (session.exercises ?? []).flatMap { $0.sets ?? [] }
            let workingSets = sets.filter { $0.isComplete && !$0.isWarmup }
            total += workingSets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        }
        return "\(Int(total))"
    }

    /// Adherence = (sessions completed this month / target 4/week × weeks).
    /// Simplified: sessions30d / 16 (4/week × 4 weeks) clamped to 0–100.
    private var adherencePct: Int {
        guard sessions30d > 0 else { return 0 }
        return min(100, sessions30d * 100 / 16)
    }

    // MARK: - Computed: spark card

    /// Last 8 weeks of total tonnage. Most-recent week last.
    private var tonnageByWeek: [Double] {
        var weeks = [Double](repeating: 0, count: 8)
        let now = Date.now
        let cal = Calendar.current
        for session in sessions {
            guard let completedAt = session.completedAt else { continue }
            let daysAgo = cal.dateComponents([.day], from: completedAt, to: now).day ?? 0
            let weekIndex = daysAgo / 7
            guard weekIndex < 8 else { continue }
            let reverseIndex = 7 - weekIndex // oldest = index 0, most-recent = index 7
            let tonnage = (session.exercises ?? [])
                .flatMap { $0.sets ?? [] }
                .filter { $0.isComplete && !$0.isWarmup }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            weeks[reverseIndex] += tonnage
        }
        return weeks
    }

    private var tonnageDeltaPct: Double {
        let w = tonnageByWeek
        let current = w.last ?? 0
        let prior = w.count >= 2 ? w[w.count - 2] : 0
        guard prior > 0 else { return 0 }
        return ((current / prior) - 1) * 100
    }

    // MARK: - PR badges (Phase 6 wiring placeholder)

    /// PR badges for a session — full PR detection (PROG-01) deferred to Phase 6.
    /// Returns empty array as safe placeholder.
    private func prBadges(for session: Session) -> [String] {
        [] // Phase 6 plan 06-05 (PROG-01) will wire actual PR detection
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)
            Text("No sessions yet")                    // UI-SPEC verbatim
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            Text("Finish a workout to see it here.")   // UI-SPEC verbatim
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SessionHistoryView (empty)") {
    SessionHistoryView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("SessionHistoryView (populated)") {
    SessionHistoryView()
        .modelContainer(PreviewModelContainer.make())
}
#endif
