// SessionHistoryRow.swift
// fitbod
//
// One finished workout in SessionHistoryView. SessionHistoryView wraps it
// in a NavigationLink to the workout's summary, styled `.bruRow`, so only a
// tap opens it.
//
// Layout (3 columns):
//   ┌──────────┬─────────────────────────┬────────────┐
//   │  TODAY   │  Push A                 │  4,610 LB  │
//   │  WED 22  │  21 SETS · 52M          │ PR · E1RM  │
//   └──────────┴─────────────────────────┴────────────┘
//   64pt date column with a 1pt hair rule on its right. Past days show
//   "MON 20" alone; today shows "TODAY" over the date. One record names
//   its kind ("PR · E1RM"); several show the count ("PR × 4"), and the
//   summary lists them. Rows without a PR show "›" instead of the badge.
//   At accessibility sizes the columns stack, date over workout over
//   total, so the date reads whole.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

// MARK: - SessionHistoryRow

public struct SessionHistoryRow: View {
    public let session: Session
    /// The records this workout set. Nil for none.
    public let prs: SessionPRs?
    public let unit: WeightUnit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(session: Session, prs: SessionPRs? = nil, unit: WeightUnit = .default) {
        self.session = session
        self.prs = prs
        self.unit = unit
    }

    public var body: some View {
        partsLayout {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(BRUFont.displayMedium)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruInk)
                if isToday {
                    Text(dayLabel)
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .frame(width: stacks ? nil : 64, alignment: .leading)
            .frame(maxHeight: stacks ? nil : .infinity)
            .overlay(alignment: .trailing) {
                if !stacks {
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(width: 1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .lineLimit(2)
                Text(setDurationLabel)
                    .font(BRUFont.labelSmall)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)
            }

            if !stacks {
                Spacer(minLength: 8)
            }

            VStack(alignment: stacks ? .leading : .trailing, spacing: 4) {
                Text("\(SessionHistoryFormat.compactTonnage(tonnage)) \(unit.rawValue.uppercased())")
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let prs, prs.count > 1 {
                    BRUChip("PR × \(prs.count)", color: .bruSignal, fill: true)
                } else if let kind = prs?.kinds.first {
                    BRUChip("PR · \(Self.shortLabel(kind))", color: .bruSignal, fill: true)
                } else {
                    Text("›")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens the workout summary")
    }

    /// The date, workout and total side by side, or stacked at
    /// accessibility sizes, where the 64pt date column broke the weekday,
    /// "WED" as "WE" over "D".
    private var partsLayout: AnyLayout {
        stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var stacks: Bool { dynamicTypeSize.isAccessibilitySize }

    // MARK: - Derived values

    private var isToday: Bool { Calendar.current.isDateInToday(session.startedAt) }

    private var tonnage: Double { SessionHistoryFormat.tonnage(of: session) }

    /// Completed, non-warm-up sets.
    private var workingSetCount: Int {
        (session.exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { $0.isComplete && !$0.isWarmup }
            .count
    }

    private var durationMinutes: Int? {
        if let stored = session.totalDurationSeconds { return stored / 60 }
        guard let completedAt = session.completedAt else { return nil }
        return max(0, Int(completedAt.timeIntervalSince(session.startedAt) / 60))
    }

    /// "TODAY", or "MON 20" for any other day.
    private var dateLabel: String {
        isToday ? "TODAY" : dayLabel
    }

    /// "MON 20".
    private var dayLabel: String {
        session.startedAt
            .formatted(.dateTime.weekday(.abbreviated).day())
            .replacingOccurrences(of: ",", with: "")
            .uppercased()
    }

    /// "21 SETS · 52M", "1 SET · 1H 05M".
    private var setDurationLabel: String {
        let sets = BRUCountLabel.text(workingSetCount, "SET")
        guard let minutes = durationMinutes else { return sets }
        let duration = minutes >= 60
            ? "\(minutes / 60)H \(String(format: "%02d", minutes % 60))M"
            : "\(minutes)M"
        return "\(sets) · \(duration)"
    }

    private var accessibilityText: String {
        var parts = [
            session.displayName,
            session.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()),
            BRUCountLabel.text(workingSetCount, "set"),
        ]
        if let minutes = durationMinutes {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        let unitName = unit == .kg ? "kilograms" : "pounds"
        parts.append("\(Int(tonnage.rounded()).formatted()) \(unitName) total")
        if let prs {
            // Same wording as the in-workout PR banner.
            let kinds = prs.kinds.map(\.spokenName).joined(separator: ", ")
            parts.append(prs.count == 1
                ? "Personal record, \(kinds)"
                : "\(prs.count) personal records: \(kinds)")
        }
        return parts.joined(separator: ", ")
    }

    static func shortLabel(_ kind: PRKind) -> String {
        switch kind {
        case .weight: return "Weight"
        case .reps:   return "Reps"
        case .volume: return "Vol"
        case .e1RM:   return "e1RM"
        }
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
                SessionHistoryRow(session: session, prs: SessionPRs(kinds: [.e1RM], count: 1))
                BRUDivider(.hair)
                SessionHistoryRow(
                    session: session,
                    prs: SessionPRs(kinds: [.weight, .reps, .volume, .e1RM], count: 4)
                )
                BRUDivider(.hair)
                SessionHistoryRow(session: session)
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
