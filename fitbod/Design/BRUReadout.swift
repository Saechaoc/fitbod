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
    private let size: BRUDisplaySize
    private let caption: String?
    private let spokenLabel: String?
    private let spokenValue: String?

    // MARK: - Init

    /// Creates a BRU stat-strip cell.
    /// - Parameters:
    ///   - label: Small uppercase descriptor shown above the value (e.g. "Day streak", "Sessions").
    ///            Rendered uppercase at the view layer — source string is as-typed for VoiceOver.
    ///   - value: The large display-weight value (e.g. "14", "↑", "42").
    ///   - valueColor: Foreground color for the value text. Defaults to `Color.bruInk`.
    ///                 Use `Color.bruSignal` for upward-trend arrows and highlight values.
    ///   - size: Display size tier for the value. Defaults to `.medium` (18pt) per UI-SPEC stat-strip
    ///           contract. Use `BRUDisplay.Size` or `BRUDisplaySize` to reference the enum.
    ///   - caption: Optional small line under the value that qualifies it (e.g. "30 days"),
    ///           so the label itself can stay short enough for one line.
    ///   - accessibilityLabel: What VoiceOver says for the label when the visible
    ///           text is abbreviated (e.g. "Sessions in the last 30 days"). Defaults to
    ///           `label`, followed by `caption` when there is one.
    ///   - accessibilityValue: What VoiceOver says for a glyph value (e.g. "Up" for "↑").
    ///           Defaults to `value`.
    public init(
        label: String,
        value: String,
        valueColor: Color = .bruInk,
        size: BRUDisplaySize = .medium,
        caption: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor.bruTextOnPaper
        self.size = size
        self.caption = caption
        self.spokenLabel = accessibilityLabel
        self.spokenValue = accessibilityValue
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
                .font(.bru(.grotesk, size: size.pointSize))
                .tracking(size.tracking)
                .foregroundStyle(valueColor)

            if let caption {
                Text(caption)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        // One VoiceOver stop per cell: "Day streak, 14".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel ?? [label, caption].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(spokenValue ?? value)
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
