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

/// 3-cell BRU stat strip — Day streak / Sessions / W{N} / {M} trend.
///
/// Layout:
/// ```
/// ┌───────────────┬───────────────┬───────────────┐
/// │  Day streak   │   Sessions    │    W3 / 5     │
/// │      14       │      42       │       ↑       │
/// └───────────────┴───────────────┴───────────────┘
/// ══════════════════════════════════════════════════  2pt bruInk
/// ```
///
/// Vertical 1pt bruInk dividers between cells; 2pt bruInk bottom rule.
/// Reference: bru-screens/today.jsx lines 10-20.
public struct TodayStatStrip: View {

    // MARK: - Properties

    let streak: Int
    let totalSessions: Int
    let weekIndex: Int     // 1-based current week, e.g. 3
    let totalWeeks: Int    // total block weeks, e.g. 5
    let trend: TrendDirection

    // MARK: - Computed

    private var weekLabel: String { "W\(weekIndex) / \(totalWeeks)" }

    private var trendValue: String {
        switch trend {
        case .up:   return "↑"
        case .down: return "↓"
        case .flat: return "—"
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
            HStack(spacing: 0) {
                // Slot 1 — Day streak
                BRUReadout(label: "Day streak", value: "\(streak)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                // Vertical divider
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 1)

                // Slot 2 — Sessions
                BRUReadout(label: "Sessions", value: "\(totalSessions)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                // Vertical divider
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 1)

                // Slot 3 — W{N} / {M} + trend arrow
                BRUReadout(label: weekLabel, value: trendValue, valueColor: trendColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            // 2pt bruInk bottom rule — section boundary
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("TodayStatStrip") {
    VStack(spacing: 0) {
        TodayStatStrip(streak: 14, totalSessions: 42, weekIndex: 3, totalWeeks: 5, trend: .up)
        TodayStatStrip(streak: 0, totalSessions: 7, weekIndex: 1, totalWeeks: 4, trend: .flat)
        TodayStatStrip(streak: 3, totalSessions: 21, weekIndex: 5, totalWeeks: 5, trend: .down)
    }
    .background(Color.bruPaper)
}
#endif
