// WeeklyTonnageSparkCard.swift
// fitbod — Phase 2.1 Plan 10
//
// NEW — Weekly tonnage spark card with 8-bar BRUSpark chart.
// UI-SPEC v2 § Session history view (line 451-453) + § Component Inventory (line 592).
//
// Reference: bru-screens/session-history.jsx lines 31-48
//
// Layout:
//   VStack(alignment: .leading, spacing: 8) {
//     HStack { "WEEKLY TONNAGE · 8 WK"   "↑ 12.4%" in bruSignal }
//     BRUSpark(values: ..., highlightTrailing: true).frame(height: 60)
//   }
//   .background(Color.bruBg2)
//   .overlay(Rectangle().stroke(bruInk, 1.5))
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

// MARK: - WeeklyTonnageSparkCard

/// 8-week tonnage spark card for SessionHistoryView.
///
/// Shows the "WEEKLY TONNAGE · 8 WK" label, a delta percentage indicator,
/// and an 8-bar BRUSpark where the most-recent bar renders in bruSignal.
public struct WeeklyTonnageSparkCard: View {
    private let values: [Double]
    private let deltaPct: Double

    /// Creates a weekly tonnage spark card.
    /// - Parameters:
    ///   - values: Up to 8 weekly tonnage totals, oldest first. If fewer than 8 values
    ///             are provided, the card renders what's available.
    ///   - deltaPct: Week-over-week delta percentage. Positive = upward trend (bruSignal).
    ///               Negative = downward trend (bruInk).
    public init(values: [Double], deltaPct: Double) {
        self.values = values
        self.deltaPct = deltaPct
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: label + delta
            HStack {
                Text("WEEKLY TONNAGE · 8 WK")    // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                Spacer()

                // Delta percentage — positive in bruSignal, negative in bruInk
                Text(deltaLabel)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(deltaPct >= 0 ? Color.bruSignal : Color.bruInk)
            }

            // 8-bar spark chart — trailing (most-recent) bar in bruSignal
            BRUSpark(values: values, highlightTrailing: true)
                .frame(height: 60)
        }
        .padding(12)
        .background(Color.bruBg2)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        )
    }

    // MARK: - Private

    private var deltaLabel: String {
        let absVal = abs(deltaPct)
        let arrow = deltaPct >= 0 ? "↑" : "↓"
        return "\(arrow) \(String(format: "%.1f", absVal))%"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WeeklyTonnageSparkCard") {
    VStack(spacing: 16) {
        WeeklyTonnageSparkCard(
            values: [58, 62, 64, 61, 66, 68, 70, 71],
            deltaPct: 12.4
        )
        WeeklyTonnageSparkCard(
            values: [71, 70, 68, 66, 64, 62, 60, 58],
            deltaPct: -3.2
        )
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
