//
//  ProgressFilterChip.swift
//  fitbod
//
//  Wave-3 plan 06-05 — accent-tinted sibling of
//  `ExerciseLibrary/FilterChip.swift`. The library chip uses a SOLID
//  accent fill when active (UI-SPEC § Color contract item 1) — Phase
//  6's progress surfaces want a softer accent-tint background so the
//  chips read as "filter modifiers on a chart" rather than primary
//  affordances (UI-SPEC § Color contract item 24).
//
//  Per PATTERNS adjudication #2: we ship a new sibling rather than
//  modify the existing FilterChip — keeps the library surface stable
//  and lets Phase 6 evolve its own visual language without regressing
//  Phase 1.
//
//  ## Visual states
//
//  | State    | Background fill              | Foreground         |
//  |----------|------------------------------|--------------------|
//  | Inactive | `Color(.systemGray5)`        | `.secondaryLabel`  |
//  | Active   | accent at 15% opacity        | `Color.accentColor`|
//
//  ## Haptics
//
//  `.selectionChanged()` on tap (UI-SPEC item 627 haptics anchor).
//
//  ## Accessibility
//
//  - `accessibilityLabel` is the explicit accessibility-name string
//    (e.g. "Top set series").
//  - `accessibilityValue` is "selected" or "hidden" so VoiceOver
//    users hear the toggle state.
//  - `.frame(minHeight: 44)` gives the HIG-mandated touch target.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Accent-tinted filter chip used by Phase 6 chart surfaces.
public struct ProgressFilterChip: View {
    public let label: String
    public let accessibilityName: String
    public let isActive: Bool
    public let action: () -> Void

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
        Button {
            #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
            action()
        } label: {
            Text(label)
                .font(.caption)
                .foregroundStyle(isActive ? Color.accentColor : Color(.secondaryLabel))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isActive ? "selected" : "hidden")
    }
}

#Preview("Inactive") {
    ProgressFilterChip(label: "Top set", accessibilityName: "Top set series", isActive: false) {}
        .padding()
}

#Preview("Active") {
    ProgressFilterChip(label: "All-set avg", accessibilityName: "All-set average series", isActive: true) {}
        .padding()
}
