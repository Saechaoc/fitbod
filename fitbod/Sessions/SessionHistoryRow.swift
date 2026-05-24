// SessionHistoryRow.swift
// fitbod — Phase 2.1 Plan 10
//
// NEW — 3-column row for SessionHistoryView.
// UI-SPEC v2 § Session history view (line 455-457) + § Component Inventory (line 593).
//
// Reference: bru-screens/session-history.jsx lines 53-85
//
// Layout (3-column HStack):
//   ┌──────────┬─────────────────────────┬────────────┐
//   │  TODAY   │  Push A                 │  4,610 lb  │
//   │  WED 22  │  21 SETS · 52M          │  PR · e1RM │
//   └──────────┴─────────────────────────┴────────────┘
//   64pt leading date column with 1pt hair right-border
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

// MARK: - SessionHistoryRow

/// 3-column row representing a completed session in SessionHistoryView.
///
/// - Leading 64pt column: date ("TODAY" or "MON 20") + optional day-of-week sub-line.
///   Separated from middle column by a 1pt hair right-border.
/// - Middle column: routine name (bodyEmphasis 14pt) + set/duration sub-line (labelSmall).
/// - Trailing column: tonnage (displayMedium 18pt, monospaced) + optional PR badge.
public struct SessionHistoryRow: View {
    public let session: Session
    public let prBadges: [String]

    public init(session: Session, prBadges: [String] = []) {
        self.session = session
        self.prBadges = prBadges
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Leading date column (64pt, hair right-border)
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(BRUFont.displayMedium)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruInk)

                if !dayOfWeekLabel.isEmpty {
                    Text(dayOfWeekLabel)
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .frame(width: 64, alignment: .leading)
            .overlay(
                Rectangle()
                    .fill(Color.bruHair)
                    .frame(width: 1),
                alignment: .trailing
            )

            // Middle column: routine name + set/duration sub-line
            VStack(alignment: .leading, spacing: 4) {
                Text(session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .lineLimit(1)

                Text(setDurationLabel)
                    .font(BRUFont.labelSmall)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }

            Spacer()

            // Trailing column: tonnage + PR badges
            VStack(alignment: .trailing, spacing: 4) {
                Text(tonnageLabel)
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)

                if !prBadges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(prBadges, id: \.self) { badge in
                            BRUCornerBadge(badge, fill: .bruSignal, textColor: .bruPaper)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Computed

    /// "TODAY" if today; "{WEEKDAY} {day}" otherwise (e.g. "MON 20").
    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(session.startedAt) {
            return "TODAY"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: session.startedAt).uppercased()
    }

    /// Day-of-week sub-line (empty when date label is "TODAY").
    private var dayOfWeekLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(session.startedAt) { return "" }
        // When date is not today, show full weekday abbreviation
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.startedAt).uppercased()
    }

    /// "{N} SETS · {duration}" e.g. "21 SETS · 52M"
    private var setDurationLabel: String {
        let allSets = (session.exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
        let setCount = allSets.count

        let duration: String
        if let completedAt = session.completedAt {
            let minutes = Int(completedAt.timeIntervalSince(session.startedAt) / 60)
            if minutes >= 60 {
                let h = minutes / 60
                let m = minutes % 60
                duration = m > 0 ? "\(h)H\(m)M" : "\(h)H"
            } else {
                duration = "\(minutes)M"
            }
        } else {
            duration = "—"
        }

        return "\(setCount) SETS · \(duration)"
    }

    /// Total session tonnage (weight × reps for completed working sets).
    private var tonnageLabel: String {
        let total = (session.exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
            .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        }
        return "\(Int(total))"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SessionHistoryRow") {
    SessionHistoryRowPreviewHost()
        .modelContainer(PreviewModelContainer.make())
}

private struct SessionHistoryRowPreviewHost: View {
    @Query(sort: \Session.startedAt, order: .reverse)
    private var sessions: [Session]

    var body: some View {
        VStack(spacing: 0) {
            if let session = sessions.first {
                SessionHistoryRow(session: session, prBadges: ["PR · e1RM"])
                BRUDivider(.hair)
                SessionHistoryRow(session: session, prBadges: [])
            } else {
                Text("No sessions")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding()
            }
        }
        .background(Color.bruPaper)
    }
}
#endif
