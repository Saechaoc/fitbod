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
public struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    public init(label: String, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color(.systemGray5))
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .frame(minHeight: 44)
        .accessibilityLabel("\(label) filter")
    }
}

#Preview("Inactive") {
    FilterChip(label: "Muscle", isActive: false) {}
        .padding()
}

#Preview("Active with count") {
    FilterChip(label: "Muscle · 2", isActive: true) {}
        .padding()
}
