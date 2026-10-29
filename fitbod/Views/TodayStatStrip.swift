// TodayStatStrip.swift
// fitbod — Phase 2.1 Plan 04
//
// 3-cell BRU stat strip for the Today tab.
// Reference: bru-screens/today.jsx lines 10-20
//
// Layout: HStack of 3 BRUReadout cells with 1pt bruInk vertical dividers
// between each cell, and a 2pt bruInk bottom rule via BRUDivider(.ink).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI

// MARK: - TrendDirection

/// Direction used by slot 3 of TodayStatStrip to set value + color.
public enum TrendDirection {
    /// Upward trend — renders "↑" in bruSignal.
    case up
    /// Downward trend — renders "↓" in bruInk.
    case down
    /// No clear trend — renders "—" in bruInk.
    case flat
}

// MARK: - TodayStatStrip

/// 3-cell BRU stat strip — Day streak / Sessions / block week or this week.
///
/// Layout:
/// ```
/// ┌───────────────┬───────────────┬───────────────┐
/// │  Day streak   │  Sessions   › │    W3 / 5     │
/// │      14       │      42       │       ↑       │
/// └───────────────┴───────────────┴───────────────┘
/// ══════════════════════════════════════════════════  2pt bruInk
/// ```
///
/// Slot 2 opens workout history when `onOpenHistory` is set; the "›" marks
/// it as tappable. Slot 3 shows the block week and the week-over-week trend
/// while a block is active, and "This week" (finished sessions this week)
/// otherwise, since a "W1 / 1" placeholder would mean nothing.
///
/// Vertical 1pt bruInk dividers between cells; 2pt bruInk bottom rule.
/// Reference: bru-screens/today.jsx lines 10-20.
public struct TodayStatStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Properties

    let streak: Int
    let totalSessions: Int
    let weekIndex: Int     // 1-based current week, e.g. 3
    let totalWeeks: Int    // total block weeks, e.g. 5
    let trend: TrendDirection
    /// False when no block is active: slot 3 shows `sessionsThisWeek`.
    let hasActiveBlock: Bool
    /// Finished sessions in the current week.
    let sessionsThisWeek: Int
    /// Opens workout history from the Sessions cell. Nil keeps it static.
    let onOpenHistory: (() -> Void)?

    public init(
        streak: Int,
        totalSessions: Int,
        weekIndex: Int,
        totalWeeks: Int,
        trend: TrendDirection,
        hasActiveBlock: Bool = true,
        sessionsThisWeek: Int = 0,
        onOpenHistory: (() -> Void)? = nil
    ) {
        self.streak = streak
        self.totalSessions = totalSessions
        self.weekIndex = weekIndex
        self.totalWeeks = totalWeeks
        self.trend = trend
        self.hasActiveBlock = hasActiveBlock
        self.sessionsThisWeek = sessionsThisWeek
        self.onOpenHistory = onOpenHistory
    }

    // MARK: - Computed

    private var weekLabel: String { "W\(weekIndex) / \(totalWeeks)" }

    private var trendValue: String {
        switch trend {
        case .up:   return "↑"
        case .down: return "↓"
        case .flat: return "—"
        }
    }

    private var trendSpoken: String {
        switch trend {
        case .up:   return "More sessions than last week"
        case .down: return "Fewer sessions than last week"
        case .flat: return "Same as last week"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .up:   return .bruSignal
        case .down, .flat: return .bruInk
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            statLayout {
                // Slot 1 — Day streak
                cell {
                    BRUReadout(
                        label: "Day streak",
                        value: "\(streak)",
                        accessibilityValue: streak == 1 ? "1 day" : "\(streak) days"
                    )
                }

                divider

                // Slot 2 — Sessions, opens history
                if let onOpenHistory {
                    Button(action: onOpenHistory) {
                        cell {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                BRUReadout(label: "Sessions", value: "\(totalSessions)")
                                Spacer(minLength: 4)
                                // Same font as the label it sits beside: a
                                // taller glyph would push this readout below
                                // its neighbours.
                                Text("›")
                                    .font(BRUFont.labelSmall)
                                    .foregroundStyle(Color.bruMuted)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sessions")
                    .accessibilityValue("\(totalSessions)")
                    .accessibilityHint("Opens workout history")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("today.sessions")
                } else {
                    cell {
                        BRUReadout(label: "Sessions", value: "\(totalSessions)")
                    }
                }

                divider

                // Slot 3 — W{N} / {M} + trend arrow, or this week's count
                cell {
                    if hasActiveBlock {
                        BRUReadout(
                            label: weekLabel,
                            value: trendValue,
                            valueColor: trendColor,
                            accessibilityLabel: "Block week \(weekIndex) of \(totalWeeks)",
                            accessibilityValue: trendSpoken
                        )
                    } else {
                        BRUReadout(
                            label: "This week",
                            value: "\(sessionsThisWeek)",
                            accessibilityLabel: "Sessions this week"
                        )
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // 2pt bruInk bottom rule — section boundary
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }

    private func cell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.bruInk)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 1,
                   height: dynamicTypeSize.isAccessibilitySize ? 1 : nil)
    }

    private var statLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("TodayStatStrip") {
    VStack(spacing: 0) {
        TodayStatStrip(streak: 14, totalSessions: 42, weekIndex: 3, totalWeeks: 5, trend: .up)
        TodayStatStrip(streak: 0, totalSessions: 7, weekIndex: 1, totalWeeks: 4, trend: .flat,
                       hasActiveBlock: false, sessionsThisWeek: 2, onOpenHistory: {})
        TodayStatStrip(streak: 3, totalSessions: 21, weekIndex: 5, totalWeeks: 5, trend: .down)
    }
    .background(Color.bruPaper)
}
#endif
