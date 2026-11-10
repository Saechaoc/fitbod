// DoneTodaySlab.swift
// fitbod
//
// Today's counted finished workouts, newest first, on paper in both
// appearances. Each row opens its own saved workout. PRs use History's
// chronological replay and refresh after a history correction.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

public struct DoneTodaySlab: View {
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    let sessions: [Session]
    let history: [Session]
    let upNext: String?
    let onView: @MainActor (Session) -> Void

    @State private var prs: [UUID: SessionPRs] = [:]

    private struct RecordsKey: Equatable {
        let sessionIDs: [UUID]
        let edits: Int
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sessions.count == 1 ? "Done" : "Done · \(BRUCountLabel.text(sessions.count, "workout"))")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            ForEach(sessions) { session in
                Button { onView(session) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            BRUDisplay(session.displayName, size: .large)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("›")
                                .font(BRUFont.displayMedium)
                                .foregroundStyle(Color.bruMuted)
                                .accessibilityHidden(true)
                        }
                        Text(Self.caption(for: session, prCount: prs[session.id]?.count ?? 0))
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
                }
                .buttonStyle(.bruRow)
                .accessibilityIdentifier("doneToday.view.\(session.id)")
            }

            if let upNext {
                Text(upNext)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityIdentifier("doneToday.upNext")
            }

        }
        .padding(16)
        .background(Color.bruPaper)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { Rectangle().strokeBorder(Color.bruInk, lineWidth: 2) }
        .padding(16)
        .task(id: RecordsKey(sessionIDs: history.map(\.id), edits: historyEdits?.version ?? 0)) {
            prs = SessionSummary.prsBySession(history)
        }
    }

    static func caption(for session: Session, prCount: Int) -> String {
        var parts: [String] = []
        if let seconds = session.totalDurationSeconds {
            parts.append(SessionHistoryFormat.duration(minutes: seconds / 60))
        }
        parts.append(BRUCountLabel.text(session.loggedSetCount, "set"))
        if prCount > 0 {
            parts.append(BRUCountLabel.text(prCount, "PR"))
        }
        return parts.joined(separator: " · ")
    }
}
