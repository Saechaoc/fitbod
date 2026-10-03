//
//  FilterChip.swift
//  fitbod
//
//  Single chip in the `ExerciseFilterBar` — capsule background, caption
//  label, tap action. UI-SPEC § Spacing Scale 44pt minimum touch target
//  is the load-bearing accessibility contract on this view.
//
//  ## Visual states
//
//  | State    | Background fill              | Foreground          |
//  |----------|------------------------------|---------------------|
//  | Inactive | `Color(.systemGray5)`        | `.primary`          |
//  | Active   | `Color.accentColor`          | `.white`            |
//
//  The active fill is the only place in the library surface where
//  accent appears as a fill (UI-SPEC § Color § Accent reserved for / item 1).
//
//  ## Accessibility
//
//  - `accessibilityLabel` is the facet name plus selection count when
//    active ("Muscle filter, 2 selected"). VoiceOver users get the same
//    information the sighted label conveys via the "· {N}" suffix.
//  - Touch target is padded to `44pt` minimum via
//    `.frame(minHeight: 44)` + `.contentShape(Capsule())` — the visible
//    capsule may be smaller, but the hit area is full HIG-mandated size.
//

import SwiftUI

/// A single filter chip in the library's filter bar.
///
/// The chip is a capsule-shaped button with a `.caption` label and an
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
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(isActive ? Color.bruSignal : Color.clear)
                .overlay(
                    Rectangle().strokeBorder(isActive ? Color.bruSignal : Color.bruInk, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
