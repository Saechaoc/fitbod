//
//  ExerciseFilterBar.swift
//  fitbod
//
//  Horizontal scrolling row of `FilterChip`s for the library view.
//  Hosted via `.safeAreaInset(edge: .top)` on the `List` so the bar
//  stays visually pinned above the rows during scroll (UI-SPEC § Library
//  screen — "sticky chip-row at the top").
//
//  ## Facet identification
//
//  `FilterFacet` is a public enum (Identifiable) so the parent view can
//  drive a single `.sheet(item:)` against the same selection. Tapping
//  any chip writes its facet into the parent's `presentingSheet`
//  binding; the parent presents the appropriate `FilterPickerSheet`.
//
//  ## Chip labels
//
//  Each chip label combines a verbatim UI-SPEC token with a count or
//  capitalised value when the facet has a selection:
//
//  | Facet     | Empty label  | Active label                       |
//  |-----------|--------------|------------------------------------|
//  | muscle    | "Muscle"     | "Muscle · {N}" (count)             |
//  | equipment | "Equipment"  | "Equipment · {N}" (count)          |
//  | mechanic  | "Mechanic"   | "Mechanic · {Value}" (capitalised) |
//  | pattern   | "Pattern"    | "Pattern · {N}" (count)            |
//
//  The "· " separator is the locked UI-SPEC token (mid-dot + non-breaking
//  space) so VoiceOver and Larger Text scale it sanely.
//
//  ## Clear-filters action
//
//  When any facet has at least one selection (`!filterState.isEmpty`) a
//  trailing "Clear filters" text button appears, calling `filterState.clear()`.
//  Per UI-SPEC § Library screen the copy is verbatim "Clear filters"
//  (no exclamation) and the foreground is the accent colour.
//

import SwiftUI

/// Sticky horizontal chip row at the top of the library list.
public struct ExerciseFilterBar: View {
    /// `@Bindable` because mutating the filter state from the picker
    /// sheets must propagate back through the same instance.
    @Bindable var filterState: FilterState
    @Binding var presentingSheet: FilterFacet?

    public init(filterState: FilterState, presentingSheet: Binding<FilterFacet?>) {
        self.filterState = filterState
        self._presentingSheet = presentingSheet
    }

    /// Public identifier enum so a single `.sheet(item:)` modifier can
    /// dispatch to the correct `FilterPickerSheet` configuration.
    public enum FilterFacet: String, Identifiable, Sendable {
        case muscle
        case equipment
        case mechanic
        case pattern

        public var id: String { rawValue }
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: muscleLabel,
                    isActive: !filterState.selectedMuscleSlugs.isEmpty
                ) { presentingSheet = .muscle }

                FilterChip(
                    label: equipmentLabel,
                    isActive: !filterState.selectedEquipmentRaw.isEmpty
                ) { presentingSheet = .equipment }

                FilterChip(
                    label: mechanicLabel,
                    isActive: filterState.selectedMechanicRaw != nil
                ) { presentingSheet = .mechanic }

                FilterChip(
                    label: patternLabel,
                    isActive: !filterState.selectedPatternRaw.isEmpty
                ) { presentingSheet = .pattern }

                if !filterState.isEmpty {
                    Button("Clear filters") {
                        filterState.clear()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Clear filters")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }

    // MARK: - Chip-label composition

    private var muscleLabel: String {
        filterState.selectedMuscleSlugs.isEmpty
            ? "Muscle"
            : "Muscle · \(filterState.selectedMuscleSlugs.count)"
    }

    private var equipmentLabel: String {
        filterState.selectedEquipmentRaw.isEmpty
            ? "Equipment"
            : "Equipment · \(filterState.selectedEquipmentRaw.count)"
    }

    private var mechanicLabel: String {
        guard let raw = filterState.selectedMechanicRaw else { return "Mechanic" }
        return "Mechanic · \(raw.capitalized)"
    }

    private var patternLabel: String {
        filterState.selectedPatternRaw.isEmpty
            ? "Pattern"
            : "Pattern · \(filterState.selectedPatternRaw.count)"
    }
}
