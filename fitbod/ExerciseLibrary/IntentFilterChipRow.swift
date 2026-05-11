//
//  IntentFilterChipRow.swift
//  fitbod
//
//  Wave-5 plan 05-01 — the horizontal filter chip row that drives the
//  intent-split predicate on `ExerciseHistoryView`. Six chips total:
//  "All" + the five `Intent` cases (Strength / Hypertrophy / Power /
//  Endurance / Technique).
//
//  Drives a `@Binding<Intent?>` where `nil` represents the "All" state
//  (no intent filter applied — every logged set visible). Tapping the
//  selected chip is a no-op visually but the closure still fires; the
//  parent view's `FilteredHistoryList` re-runs its `@Query` predicate
//  on any change.
//
//  ## Visual contract (UI-SPEC § Exercise history view § Color)
//
//  - Selected chip: `Color.accentColor` fill + `Color.white` label
//    (UI-SPEC accent-reserved-for item #8).
//  - Unselected chip: `Color(.systemGray5)` fill + `Color.primary`
//    label.
//  - Spacing: 8pt between chips (UI-SPEC `sm` token).
//  - Padding: horizontal 12pt + vertical 6pt inside each capsule.
//  - Touch target: 44pt × 44pt minimum (UI-SPEC HIG exception) —
//    achieved by `.frame(minWidth: 44, minHeight: 44)` so the visual
//    capsule stays compact while the hit area extends.
//
//  ## Accessibility contract (UI-SPEC § Accessibility Contract)
//
//  - `accessibilityLabel` format: "{name} filter, {selected|unselected}"
//    — verbatim per UI-SPEC.
//  - `accessibilityAddTraits`: `.isButton` always, plus `.isSelected`
//    when the chip is the currently active filter.
//
//  ## Why a flat `Button` row instead of a `Picker(.segmented)`?
//
//  A segmented picker would visually collapse the 6 options into a
//  bounded segmented control — but Apple's segmented picker is a poor
//  fit for 6+ items (it crowds), and the UI-SPEC explicitly calls for
//  a horizontal scrolling chip row (matches the Phase 1 facet-picker
//  pattern in `ExerciseFilterBar.swift`).
//

import SwiftUI

public struct IntentFilterChipRow: View {
    @Binding public var selected: Intent?

    public init(selected: Binding<Intent?>) {
        self._selected = selected
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {                                              // UI-SPEC sm
                chip(label: "All", isSelected: selected == nil) {              // UI-SPEC verbatim
                    selected = nil
                }
                ForEach(Intent.allCases, id: \.rawValue) { intent in
                    chip(
                        label: intent.rawValue.capitalized,
                        isSelected: selected == intent
                    ) {
                        selected = intent
                    }
                }
            }
        }
    }

    /// One chip — capsule with text label, accent-fill when selected,
    /// `.systemGray5` fill when not. The min-44pt frame extends the
    /// hit area without affecting the compact visual padding.
    private func chip(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))    // UI-SPEC #8
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)                                   // UI-SPEC HIG
        .accessibilityLabel("\(label) filter, \(isSelected ? "selected" : "unselected")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("All selected") {
    StatefulIntentFilterPreview(initial: nil)
}

#Preview("Strength selected") {
    StatefulIntentFilterPreview(initial: .strength)
}

private struct StatefulIntentFilterPreview: View {
    @State var selected: Intent?

    init(initial: Intent?) {
        self._selected = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IntentFilterChipRow(selected: $selected)
                .padding(.horizontal, 16)
            Text("Selected: \(selected?.rawValue.capitalized ?? "All")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
}
