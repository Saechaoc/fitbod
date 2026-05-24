//
//  WeekDetailView.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — BRUHeaderBar + BRU session list replaces
//  .navigationTitle + List scaffolding. Drill-down destination for the
//  Weekly Tonnage bar tap (CONTEXT D-21).
//
//  ## BRU chrome
//
//  - BRUHeaderBar(left: "‹", center: "Week of {date}") at top.
//  - ScrollView → LazyVStack(spacing: 0) of session rows separated by
//    BRUDivider(.hair).
//  - Each row: routineName in BRUFont.bodyEmphasis bruInk + metadata
//    in BRUFont.labelSmall bruMuted + "›" disclosure glyph.
//  - Empty state: BRUFont.bodyEmphasis bruInk + BRUFont.bodyDefault bruMuted.
//  - Background: Color.bruPaper.ignoresSafeArea().
//
//  ## Predicate-narrowed @Query (RESEARCH Pitfall 3)
//
//  The @Query for sessions uses local-let captures of the lower/upper
//  bounds before the #Predicate so the macro expansion sees value-
//  typed immutables. The bounds straddle 7 days from weekStart.
//
//  [CITED: CONTEXT D-21 + UI-SPEC v2 §Design Pivot BRU chrome]
//

import SwiftData
import SwiftUI

public struct WeekDetailView: View {
    @Environment(\.dismiss) private var dismiss
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
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹") { dismiss() },
                center: navTitle
            )

            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { session in
                            sessionRow(session)
                            BRUDivider(.hair)
                        }
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Session row

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.routineSnapshotName.isEmpty ? "Unnamed session" : session.routineSnapshotName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Text(sessionMeta(session))
                    .font(BRUFont.labelSmall)
                    .tracking(0.8)
                    .foregroundStyle(Color.bruMuted)
            }
            Spacer()
            Text("›")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No sessions in this week")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private var navTitle: String {
        "Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func sessionMeta(_ session: Session) -> String {
        session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
