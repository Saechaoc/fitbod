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
//  One chip per `BlockPhaseKind` case (accumulation / intensification /
//  peak / realization / deload), multi-select bound to a `Set<String>`
//  Binding of raw values. The chart keeps the sets of workouts that ran in
//  a chosen phase (`WeeklyTonnageAggregator.sets(_:inPhases:)`); none
//  chosen keeps every set (RM-023). The row is disabled until a block has
//  started, since only a started block's workouts have a phase: the chips
//  fade, and a caption, kept readable, sends the lifter to the Program tab:
//
//      "No block data yet. Start a block in Program."
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
        // Only a started block's workouts have a phase.
        let disabled = !blocks.contains { $0.isActive || $0.endDate != nil }
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BlockPhaseKind.allCases, id: \.self) { chip(kind: $0) }
                }
                .padding(.horizontal, 16)
            }
            // The chips fade; the caption stays readable muted text (D-183).
            .opacity(disabled ? 0.5 : 1.0)
            if disabled {
                Text("No block data yet. Start a block in Program.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
            }
        }
        .disabled(disabled)
    }

    @ViewBuilder
    private func chip(kind: BlockPhaseKind) -> some View {
        let raw = kind.rawValue
        let label = BlockPhaseColors.phaseLabel(kind)
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
