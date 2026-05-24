// SessionHistoryStatStrip.swift
// fitbod — Phase 2.1 Plan 10
//
// NEW — 3-cell BRUReadout stat strip for SessionHistoryView.
// UI-SPEC v2 § Session history view (line 448-450) + § Component Inventory (line 591).
//
// Layout:
//   ┌──────────────┬──────────────┬──────────────┐
//   │Sessions · 30d│   Tonnage    │  Adherence   │
//   │     14       │   71.2k ↑   │    93%       │
//   └──────────────┴──────────────┴──────────────┘
//   1pt bruHair vertical separators between cells
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

// MARK: - SessionHistoryStatStrip

/// 3-cell stat strip at the top of SessionHistoryView.
///
/// - sessions: Count of completed sessions in the last 30 days.
/// - tonnageLabel: Formatted total tonnage string (e.g. "71.2k"). Rendered in bruSignal.
/// - adherence: Adherence percentage (0–100).
public struct SessionHistoryStatStrip: View {
    private let sessions: Int
    private let tonnageLabel: String
    private let adherence: Int

    public init(sessions: Int, tonnageLabel: String, adherence: Int) {
        self.sessions = sessions
        self.tonnageLabel = tonnageLabel
        self.adherence = adherence
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Sessions · 30d
            BRUReadout(label: "Sessions · 30d", value: "\(sessions)")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Color.bruHair).frame(width: 1)

            // Tonnage — bruSignal value per UI-SPEC line 449
            BRUReadout(label: "Tonnage", value: tonnageLabel, valueColor: .bruSignal)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Color.bruHair).frame(width: 1)

            // Adherence
            BRUReadout(label: "Adherence", value: "\(adherence)%")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SessionHistoryStatStrip") {
    VStack(spacing: 0) {
        SessionHistoryStatStrip(sessions: 14, tonnageLabel: "71.2k", adherence: 93)
        BRUDivider(.ink)
    }
    .background(Color.bruPaper)
}
#endif
