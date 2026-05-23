//
//  WeekDetailView.swift
//  fitbod
//
//  Wave-4 plan 06-06 — drill-down destination for the Weekly Tonnage
//  bar tap (CONTEXT D-21). Lists all `Session` rows that started
//  within the tapped week's ISO 7-day window. Reuses Phase 2's
//  session-row formatting (routineSnapshotName + startedAt) but
//  collapsed into a minimal one-row-per-session List.
//
//  ## Predicate-narrowed @Query (RESEARCH Pitfall 3)
//
//  The @Query for sessions uses local-let captures of the lower/upper
//  bounds before the #Predicate so the macro expansion sees value-
//  typed immutables. The bounds straddle 7 days from weekStart.
//
//  ## Empty state
//
//  When the week contains no sessions (defensive — the user reached
//  this view only via a non-empty bar), the view shows a single-row
//  "No sessions in this week" placeholder. UI-SPEC § Week-detail
//  navigation row implicitly authorizes this fallback.
//
//  [CITED: CONTEXT D-21 + UI-SPEC § Week-detail navigation row]
//

import SwiftData
import SwiftUI

public struct WeekDetailView: View {
    public let weekStart: Date
    @Query private var sessions: [Session]

    public init(weekStart: Date) {
        let lower = weekStart
        let upper = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        self.weekStart = weekStart
        _sessions = Query(
            filter: #Predicate<Session> { s in
                s.startedAt >= lower && s.startedAt < upper
            },
            sort: \Session.startedAt,
            order: .reverse
        )
    }

    public var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                List(sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.routineSnapshotName.isEmpty ? "Unnamed session" : session.routineSnapshotName)
                .font(.body)
            Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("No sessions in this week")
                .font(.headline)
            Text("Pick another week from the chart.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var navTitle: String {
        "Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))"
    }
}
