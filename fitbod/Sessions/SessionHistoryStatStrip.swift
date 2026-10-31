// SessionHistoryStatStrip.swift
// fitbod
//
// 3-cell stat strip at the top of SessionHistoryView.
//
// Layout:
//   ┌──────────────┬──────────────┬──────────────┐
//   │ Sessions     │ Tonnage · lb │ Per week     │
//   │ 14           │ 71.2k        │ 3.5          │
//   │ 30 days      │ 30 days      │ 4-week avg   │
//   └──────────────┴──────────────┴──────────────┘
//   1pt bruHair vertical separators between cells. Tonnage covers the
//   same 30 days as the session count. "Per week" averages the last
//   4 weeks. The period sits in each cell's caption so every label fits
//   on one line, even on a 390pt-wide phone; if large text still wraps a
//   label, the cells bottom-align so the values stay level. At
//   accessibility sizes the cells stack, one under another with 1pt
//   bruHair rules between them, as TodayStatStrip's do, so no label or
//   value breaks inside itself.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

// MARK: - SessionHistoryStatStrip

public struct SessionHistoryStatStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let sessions: Int
    private let tonnageLabel: String
    private let perWeekLabel: String
    private let unit: WeightUnit

    /// - Parameters:
    ///   - sessions: Finished sessions in the last 30 days.
    ///   - tonnageLabel: Their total tonnage, formatted (e.g. "71.2k").
    ///   - perWeekLabel: Average sessions per week over 4 weeks (e.g. "3.5").
    ///   - unit: The weight unit the tonnage is in.
    public init(sessions: Int, tonnageLabel: String, perWeekLabel: String, unit: WeightUnit) {
        self.sessions = sessions
        self.tonnageLabel = tonnageLabel
        self.perWeekLabel = perWeekLabel
        self.unit = unit
    }

    public var body: some View {
        statLayout {
            cell(BRUReadout(
                label: "Sessions",
                value: "\(sessions)",
                caption: "30 days",
                accessibilityLabel: "Sessions in the last 30 days"
            ))

            divider

            cell(BRUReadout(
                label: "Tonnage · \(unit.rawValue)",
                value: tonnageLabel,
                valueColor: .bruSignal,
                caption: "30 days",
                accessibilityLabel: "Tonnage in the last 30 days, \(unit == .kg ? "kilograms" : "pounds")"
            ))

            divider

            cell(BRUReadout(
                label: "Per week",
                value: perWeekLabel,
                caption: "4-week avg",
                accessibilityLabel: "Sessions per week, last 4 weeks"
            ))
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.bruPaper)
    }

    /// Equal-width cell. Bottom alignment keeps the values level when
    /// large text wraps one label onto two lines.
    private func cell(_ readout: BRUReadout) -> some View {
        readout
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// 1pt bruHair rule between cells: upright beside them, flat once they stack.
    private var divider: some View {
        Rectangle()
            .fill(Color.bruHair)
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
#Preview("SessionHistoryStatStrip") {
    VStack(spacing: 0) {
        SessionHistoryStatStrip(sessions: 14, tonnageLabel: "71.2k", perWeekLabel: "3.5", unit: .lb)
        BRUDivider(.ink)
    }
    .background(Color.bruPaper)
}
#endif
