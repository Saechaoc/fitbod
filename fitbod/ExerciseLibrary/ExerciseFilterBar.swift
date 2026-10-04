//
//  ExerciseFilterBar.swift
//  fitbod
//
//  Library filter chips (Chalkline redesign of plan 03-02):
//
//    [MUSCLE ▾] [EQUIPMENT ▾] [CUSTOM] CLEAR
//
//  A selected multi-select chip turns iron and shows its first value plus
//  "+N" (e.g. "CHEST +1"); VoiceOver reads "Muscle filter, Chest and 1
//  more selected". Muscle and Equipment open `FilterPickerSheet`; Custom
//  toggles in place. Mechanic and Pattern remain in `FilterState` but are
//  not offered as chips in milestone 1 (patterns are not curated yet, so a
//  pattern chip could only ever return zero results).
//

import SwiftUI

public struct ExerciseFilterBar: View {
    @Bindable var filterState: FilterState
    @Binding var presentingSheet: FilterFacet?

    public init(filterState: FilterState, presentingSheet: Binding<FilterFacet?>) {
        self.filterState = filterState
        self._presentingSheet = presentingSheet
    }

    /// Facet identifier so one `.sheet(item:)` can present any picker.
    public enum FilterFacet: String, Identifiable, Sendable {
        case muscle
        case equipment
        case mechanic
        case pattern

        public var id: String { rawValue }
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Chalk.Space.sm) {
                ChalkChip(
                    muscleTitle,
                    isSelected: !filterState.selectedMuscleSlugs.isEmpty,
                    extraCount: max(0, filterState.selectedMuscleSlugs.count - 1),
                    showsMenuIndicator: true,
                    accessibilityLabel: a11y("Muscle", values: sortedMuscleNames)
                ) {
                    presentingSheet = .muscle
                }
                .accessibilityIdentifier("filter.muscle")

                ChalkChip(
                    equipmentTitle,
                    isSelected: !filterState.selectedEquipmentRaw.isEmpty,
                    extraCount: max(0, filterState.selectedEquipmentRaw.count - 1),
                    showsMenuIndicator: true,
                    accessibilityLabel: a11y("Equipment", values: sortedEquipmentNames)
                ) {
                    presentingSheet = .equipment
                }
                .accessibilityIdentifier("filter.equipment")

                ChalkChip(
                    "Custom",
                    isSelected: filterState.customOnly,
                    accessibilityLabel: filterState.customOnly ? "Custom exercises only, on" : "Custom exercises only, off"
                ) {
                    filterState.customOnly.toggle()
                }
                .accessibilityIdentifier("filter.custom")

                if !filterState.isEmpty {
                    Button("Clear") {
                        filterState.clear()
                    }
                    .buttonStyle(.chalk(.ghost, size: .compact))
                    .accessibilityLabel("Clear all filters")
                    .accessibilityIdentifier("filter.clear")
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Titles

    private var sortedMuscleNames: [String] {
        filterState.selectedMuscleSlugs.sorted().map { MuscleRegionMap.displayName(for: $0) }
    }

    private var sortedEquipmentNames: [String] {
        filterState.selectedEquipmentRaw.sorted().map { ExerciseRow.equipmentName($0) }
    }

    private var muscleTitle: String {
        sortedMuscleNames.first ?? "Muscle"
    }

    private var equipmentTitle: String {
        sortedEquipmentNames.first ?? "Equipment"
    }

    private func a11y(_ facet: String, values: [String]) -> String {
        guard let first = values.first else { return "\(facet) filter" }
        if values.count == 1 { return "\(facet) filter, \(first) selected" }
        return "\(facet) filter, \(first) and \(values.count - 1) more selected"
    }
}
