//
//  FilterPickerSheet.swift
//  fitbod
//
//  Per-facet multi-select picker presented as a sheet when the user
//  taps a chip in `ExerciseFilterBar`. Hosts a `NavigationStack` with
//  inline navigation title and `[.medium, .large]` presentation detents
//  per UI-SPEC § Library screen interaction patterns.
//
//  ## One sheet, four configurations
//
//  Rather than four separate sheet files, this view branches on the
//  `facet` initialiser argument and renders the appropriate section.
//  Reasons:
//
//  - Each facet's section is < 20 lines — splitting into four files
//    would yield more boilerplate than substance.
//  - The toolbar buttons ("Done" / "Clear") are identical across all
//    four facets; co-locating keeps the contract in one place.
//  - The picker sheet has no state of its own — it binds straight to
//    the parent's `FilterState` via `@Bindable` — so there's no
//    risk of per-facet state drift.
//
//  ## Selection semantics
//
//  - **muscle / equipment / pattern** — multi-select (`Set<String>`):
//    tapping a row toggles membership; the row shows a checkmark when
//    selected. Multiple rows can be selected; the predicate ORs them
//    within the facet.
//  - **mechanic** — single-select (`String?`): tapping a row sets the
//    raw value; tapping the same row again clears it (`nil`).
//
//  ## Pattern facet footer
//
//  Phase 1 Open Q #5 — `patternRaw` is nullable in the seed; the chip
//  is functionally empty until curation lands in a later phase. The
//  pattern sheet shows a footer explaining the no-results state so the
//  user isn't confused when selecting "Squat" returns zero rows.
//

import SwiftUI
import SwiftData

/// Multi-select (or single-select for mechanic) picker for one facet.
/// Bound to the parent's `FilterState` via `@Bindable` so selections
/// flow back through the same instance the library view's `@Query`
/// predicate consumes.
public struct FilterPickerSheet: View {
    let facet: ExerciseFilterBar.FilterFacet
    @Bindable var filterState: FilterState
    @Environment(\.dismiss) private var dismiss

    /// Pulls every `MuscleGroup` row from the seeded store so the muscle
    /// section reflects the actual taxonomy (not a hardcoded list).
    /// Sorted by slug so the order is stable across runs.
    @Query(sort: \MuscleGroup.slug) private var muscles: [MuscleGroup]

    public init(
        facet: ExerciseFilterBar.FilterFacet,
        filterState: FilterState
    ) {
        self.facet = facet
        self.filterState = filterState
    }

    public var body: some View {
        NavigationStack {
            List {
                switch facet {
                case .muscle:    muscleSection
                case .equipment: equipmentSection
                case .mechanic:  mechanicSection
                case .pattern:   patternSection
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", action: clearCurrentFacet)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var title: String {
        switch facet {
        case .muscle:    return "Muscle"
        case .equipment: return "Equipment"
        case .mechanic:  return "Mechanic"
        case .pattern:   return "Pattern"
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var muscleSection: some View {
        ForEach(muscles) { mg in
            selectableRow(
                title: mg.displayName,
                isSelected: filterState.selectedMuscleSlugs.contains(mg.slug)
            ) {
                toggle(mg.slug, in: &filterState.selectedMuscleSlugs)
            }
        }
    }

    @ViewBuilder
    private var equipmentSection: some View {
        ForEach(Equipment.allCases, id: \.rawValue) { eq in
            selectableRow(
                title: displayName(forEquipment: eq),
                isSelected: filterState.selectedEquipmentRaw.contains(eq.rawValue)
            ) {
                toggle(eq.rawValue, in: &filterState.selectedEquipmentRaw)
            }
        }
    }

    @ViewBuilder
    private var mechanicSection: some View {
        ForEach(Mechanic.allCases, id: \.rawValue) { mech in
            selectableRow(
                title: mech.rawValue.capitalized,
                isSelected: filterState.selectedMechanicRaw == mech.rawValue
            ) {
                // Single-select: toggling the same row clears the facet.
                if filterState.selectedMechanicRaw == mech.rawValue {
                    filterState.selectedMechanicRaw = nil
                } else {
                    filterState.selectedMechanicRaw = mech.rawValue
                }
            }
        }
    }

    @ViewBuilder
    private var patternSection: some View {
        // Phase 1 Open Q #5 — patternRaw is nullable at seed time, so
        // selecting any pattern will return zero rows until later-phase
        // curation populates it. The footer copy explains this so the
        // user isn't surprised by an empty result list.
        Section {
            ForEach(Pattern.allCases, id: \.rawValue) { p in
                selectableRow(
                    title: displayName(forPattern: p),
                    isSelected: filterState.selectedPatternRaw.contains(p.rawValue)
                ) {
                    toggle(p.rawValue, in: &filterState.selectedPatternRaw)
                }
            }
        } footer: {
            Text(
                "Patterns are not yet assigned to seeded exercises. " +
                "Selecting a pattern will return no results until " +
                "curation lands in a later phase."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    /// A single selectable row — title + checkmark when selected.
    /// The tap target is the whole row (default `Button` behaviour).
    @ViewBuilder
    private func selectableRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
    }

    /// Equipment display names — split the underscore raw values into
    /// human-readable text (e.g. `weighted_bodyweight` → "Weighted Bodyweight").
    private func displayName(forEquipment eq: Equipment) -> String {
        eq.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Pattern display names — handle the underscored cases like
    /// `horizontal_push` → "Horizontal Push".
    private func displayName(forPattern p: Pattern) -> String {
        p.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Multi-select toggle helper used by the muscle / equipment /
    /// pattern sections.
    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    /// Clears just the currently-presented facet's selection.
    /// Distinct from the bar's "Clear filters" which clears all four.
    private func clearCurrentFacet() {
        switch facet {
        case .muscle:    filterState.selectedMuscleSlugs.removeAll()
        case .equipment: filterState.selectedEquipmentRaw.removeAll()
        case .mechanic:  filterState.selectedMechanicRaw = nil
        case .pattern:   filterState.selectedPatternRaw.removeAll()
        }
    }
}

#Preview("Muscle picker") {
    FilterPickerSheet(facet: .muscle, filterState: FilterState())
        .modelContainer(PreviewModelContainer.make())
}

#Preview("Equipment picker") {
    FilterPickerSheet(facet: .equipment, filterState: FilterState())
        .modelContainer(PreviewModelContainer.make())
}
