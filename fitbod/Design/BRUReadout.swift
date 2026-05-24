// BRUReadout.swift
// fitbod
//
// BRU stat-strip cell — a compact vertical stack of a small uppercase label
// above a large display-weight numeric value. Used in the Today, Session History,
// and Exercise History stat strips.
//
// Source of truth: UI-SPEC v2 § Component Inventory + bru-screens/today.jsx lines 12-19.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//
// USAGE:
//   BRUReadout(label: "Day streak", value: "14")
//   BRUReadout(label: "W3 / 5",     value: "↑", valueColor: .bruSignal)

import SwiftUI

// MARK: - BRUReadout

/// A single stat-strip cell — small uppercase label above a large display value.
///
/// Layout: `VStack(alignment: .leading, spacing: 4)` with:
/// - Top: label in `BRUFont.labelSmall` + `bruMuted` (tracking 1.2, uppercase)
/// - Bottom: value in `BRUFont.displayMedium` + `valueColor`
///
/// Reference: `bru-screens/today.jsx` lines 12–19.
public struct BRUReadout: View {

    // MARK: - Properties

    private let label: String
    private let value: String
    private let valueColor: Color

    // MARK: - Init

    /// Creates a BRU stat-strip cell.
    /// - Parameters:
    ///   - label: Small uppercase descriptor shown above the value (e.g. "Day streak", "Sessions").
    ///            Rendered uppercase at the view layer — source string is as-typed for VoiceOver.
    ///   - value: The large display-weight value (e.g. "14", "↑", "42").
    ///   - valueColor: Foreground color for the value text. Defaults to `Color.bruInk`. Pass `nil` to use default.
    ///                 Use `Color.bruSignal` for upward-trend arrows and highlight values.
    public init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor ?? .bruInk
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            Text(value)
                .font(BRUFont.displayMedium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUReadout") {
    VStack(alignment: .leading, spacing: 24) {
        Text("Stat strip — 3 cells")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        HStack(alignment: .top, spacing: 24) {
            BRUReadout(label: "Day streak", value: "14")
            BRUReadout(label: "Sessions", value: "42")
            BRUReadout(label: "W3 / 5", value: "↑", valueColor: .bruSignal)
        }

        BRUDivider(.hair)

        Text("Single cell variants")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        BRUReadout(label: "Tonnage", value: "71.2k", valueColor: .bruSignal)
        BRUReadout(label: "Top set", value: "225 lb")
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
