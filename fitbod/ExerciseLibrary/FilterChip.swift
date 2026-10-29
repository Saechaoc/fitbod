//
//  FilterChip.swift
//  fitbod
//
//  Single chip in the `ExerciseFilterBar`: a square-cornered BRU chip
//  with an uppercase `BRUFont.labelSmall` label and a tap action. The
//  44pt minimum touch target is the load-bearing accessibility contract
//  on this view.
//
//  ## Visual states
//
//  | State    | Fill               | 1.5pt stroke       | Label             |
//  |----------|--------------------|--------------------|-------------------|
//  | Inactive | clear              | `Color.bruInk`     | `Color.bruInk`    |
//  | Active   | `Color.bruSignal`  | `Color.bruInk`     | `Color.bruOnSignal` |
//
//  Colors come from the BRU tokens only. Nothing here reads
//  `Color.accentColor`.
//
//  ## Accessibility
//
//  - `accessibilityLabel` is the facet name plus selection count when
//    active ("Muscle filter, 2 selected"). VoiceOver users get the same
//    information the sighted label conveys via the "· {N}" suffix.
//  - The visible chip is 36pt tall. The label sits in a 44pt-tall frame
//    with a rectangular content shape, so the tappable area meets the
//    44pt minimum while the chip itself stays compact.
//

import SwiftUI

/// A single filter chip in the library's filter bar.
///
/// The chip is a square-cornered button with an uppercase label and an
/// active/inactive visual state. Selection count, when present, is
/// already baked into `label` (e.g. `"Muscle · 2"`).
///
/// `accessibilityName` is decoupled from `label` so the VoiceOver
/// readout follows the UI-SPEC § Accessibility Contract exactly
/// (e.g. `"Muscle filter, 2 selected"`) rather than reading the
/// visual mid-dot separator as "dot" (review WR-03).
public struct FilterChip: View {
    let label: String
    let accessibilityName: String
    let isActive: Bool
    let action: () -> Void

    public init(
        label: String,
        accessibilityName: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.accessibilityName = accessibilityName
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(isActive ? Color.bruOnSignal : Color.bruInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(isActive ? Color.bruSignal : Color.clear)
                .overlay(
                    Rectangle().strokeBorder(Color.bruInk, lineWidth: 1.5)
                )
                // The frame and content shape live inside the label: a
                // frame outside the Button grows its layout but not its
                // hit area.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
