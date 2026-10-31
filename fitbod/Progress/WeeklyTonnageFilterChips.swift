//
//  WeeklyTonnageFilterChips.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — three horizontal-scroll BRU chip rows that sit
//  above the WeeklyTonnageView chart. UI-SPEC v2 §Design Pivot #7 and the
//  WeeklyTonnageView entry in the §Reference mockup map govern chip visuals.
//
//  ## Row 1 — TimeRangeChipRow
//
//  Three chips bound to a `TimeRangeChoice` Binding, single-select.
//  Labels (UI-SPEC verbatim): "Last 8 wk" / "Last 26 wk" / "All time".
//
//  ## Row 2 — BlockPhaseChipRow
//
//  Four chips per `BlockPhaseKind` case (accumulation /
//  intensification / realization / deload), multi-select bound to a
//  `Set<String>` Binding. The entire row is visually disabled
//  (`.opacity(0.5)` + `.disabled(true)`) when no `Block` entities
//  exist (`@Query<Block>.isEmpty`) — i.e. until Phase 4 ships. A
//  footer caption sends the lifter to the Program tab, where blocks are
//  defined:
//
//      "No block data yet. Define a block in Program."
//
//  ## Row 3 — MuscleChipRow
//
//  One chip per `MuscleGroup` (sorted alphabetically by displayName).
//  Multi-select bound to a `Set<UUID>` Binding of MuscleGroup.id.
//  Footer reads (UI-SPEC verbatim) when selection is empty:
//
//      "Tap a muscle to break the bar by stimulus."
//
//  ## Visual contract (BRU reskin)
//
//  Each chip uses ProgressFilterChip — the BRU rectangular inverted-active chip:
//  - Selected:   bruInk fill / bruPaper text / 1pt bruInk outline
//  - Unselected: clear fill / bruInk text / 1pt bruInk outline
//
//  Footer captions: BRUFont.labelSmall + Color.bruMuted (per BRU type system).
//  Horizontal scroll; 16pt leading/trailing padding; 8pt chip spacing.
//
//  [CITED: UI-SPEC v2 §Design Pivot #7 + §Reference mockup map WeeklyTonnageView]
//

import SwiftData
import SwiftUI

// MARK: - TimeRangeChipRow

public struct TimeRangeChipRow: View {
    @Binding public var selection: TimeRangeChoice

    public init(selection: Binding<TimeRangeChoice>) {
        self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ProgressFilterChip(
                    label: "Last 8 wk",
                    accessibilityName: "Last 8 weeks",
                    isActive: selection == .last8wk
                ) {
                    selection = .last8wk
                }
                ProgressFilterChip(
                    label: "Last 26 wk",
                    accessibilityName: "Last 26 weeks",
                    isActive: selection == .last26wk
                ) {
                    selection = .last26wk
                }
                ProgressFilterChip(
                    label: "All time",
                    accessibilityName: "All time",
                    isActive: selection == .allTime
                ) {
                    selection = .allTime
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - BlockPhaseChipRow

public struct BlockPhaseChipRow: View {
    @Binding public var selection: Set<String>
    @Query private var blocks: [Block]

    public init(selection: Binding<Set<String>>) {
        self._selection = selection
    }

    public var body: some View {
        let disabled = blocks.isEmpty
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(kind: .accumulation, label: "Accumulation")
                    chip(kind: .intensification, label: "Intensification")
                    chip(kind: .realization, label: "Realization")
                    chip(kind: .deload, label: "Deload")
                }
                .padding(.horizontal, 16)
            }
            if disabled {
                Text("No block data yet. Define a block in Program.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
            }
        }
        .opacity(disabled ? 0.5 : 1.0)
        .disabled(disabled)
    }

    @ViewBuilder
    private func chip(kind: BlockPhaseKind, label: String) -> some View {
        let raw = kind.rawValue
        ProgressFilterChip(
            label: label,
            accessibilityName: label,
            isActive: selection.contains(raw)
        ) {
            if selection.contains(raw) {
                selection.remove(raw)
            } else {
                selection.insert(raw)
            }
        }
    }
}

// MARK: - MuscleChipRow

public struct MuscleChipRow: View {
    @Binding public var selection: Set<UUID>
    @Query(sort: \MuscleGroup.displayName, order: .forward) private var muscles: [MuscleGroup]

    public init(selection: Binding<Set<UUID>>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(muscles, id: \.id) { muscle in
                        ProgressFilterChip(
                            label: muscle.displayName,
                            accessibilityName: muscle.displayName,
                            isActive: selection.contains(muscle.id)
                        ) {
                            if selection.contains(muscle.id) {
                                selection.remove(muscle.id)
                            } else {
                                selection.insert(muscle.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            if selection.isEmpty {
                Text("Tap a muscle to break the bar by stimulus.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
            }
        }
    }
}
