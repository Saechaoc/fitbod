// BlockContextBand.swift
// fitbod — Phase 2.1 Plan 04
//
// Block context band: Block chip + uppercased block name + phase chip + WeekTickerCells.
// Reference: bru-screens/today.jsx lines 22-57
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - BlockContextBand

/// Renders the block-context row with chip + name + phase + WeekTickerCells.
///
/// Layout (top to bottom):
/// ```
/// ┌─────────────────────────────────────────────┐
/// │  [Block]  UPPER HYPERTROPHY  [Intensification] │  14px v-pad
/// │  W1  W2  W3  W4  W5                         │  12px below, 28px tall cells
/// └─────────────────────────────────────────────┘
/// ══════════════════════════════════════════════  2pt bruInk
/// ```
///
/// Reference: bru-screens/today.jsx lines 22-57.
public struct BlockContextBand: View {

    // MARK: - Properties

    let block: Block
    /// Optional tap closure — wired from TodayView to push BlockOverviewRoute.summary(blockID:).
    /// When nil the band is display-only (backward-compatible default, CONTEXT D-11).
    var onTap: (() -> Void)? = nil

    // MARK: - Computed

    /// Phase display name — derived from BlockPhaseKind raw value, title-cased.
    private var currentPhase: BlockPhase? {
        PeriodizationEngine.phase(for: block, on: .now)
    }

    private var phaseDisplayName: String {
        guard let phase = currentPhase else { return "Accumulation" }
        // Capitalize first letter of each word (BlockPhaseKind raw values are lowercase)
        return phase.kind.rawValue
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
            .capitalized
    }

    /// 1-based current week in the block (0 when before start, nil when complete)
    private var currentWeekNumber: Int {
        guard let idx = PeriodizationEngine.weekIndex(for: block, on: .now) else { return 1 }
        return idx + 1  // weekIndex is 0-based
    }

    /// Total weeks in the block across all phases
    private var totalWeeks: Int {
        (block.phases ?? []).reduce(0) { $0 + $1.weeks }
    }

    /// Which 1-based week numbers are deload weeks
    private var deloadWeeks: Set<Int> {
        var result = Set<Int>()
        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        var cumulativeWeeks = 0
        for phase in phases {
            if phase.kind == .deload {
                for w in 1...max(phase.weeks, 1) {
                    result.insert(cumulativeWeeks + w)
                }
            }
            cumulativeWeeks += phase.weeks
        }
        return result
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Block chip + name + phase chip
                HStack(spacing: 8) {
                    BRUChip("Block")

                    Spacer()

                    Text(block.name.uppercased())
                        .font(.custom("SpaceGrotesk-Bold", size: 11))
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)

                    Spacer()

                    BRUChip(phaseDisplayName, color: .bruSignal, fill: true)
                }

                // Week ticker cells row
                if totalWeeks > 0 {
                    WeekTickerCells(
                        currentWeek: currentWeekNumber,
                        totalWeeks: min(totalWeeks, 5),  // display up to 5 cells per today.jsx
                        deloadWeeks: deloadWeeks
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // 2pt bruInk bottom rule — section boundary
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct BlockContextBandPreviewContainer: View {
    let container: ModelContainer
    let block: Block

    var body: some View {
        BlockContextBand(block: block)
            .modelContainer(container)
            .background(Color.bruPaper)
    }

    static func make() -> BlockContextBandPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Block.self, BlockPhase.self, configurations: config)

        let block = Block()
        block.name = "Upper Hypertrophy"
        block.isActive = true
        block.startDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now) ?? .now

        let accum = BlockPhase()
        accum.nameRaw = "accumulation"
        accum.weeks = 3
        accum.orderIndex = 0
        accum.block = block

        let intens = BlockPhase()
        intens.nameRaw = "intensification"
        intens.weeks = 2
        intens.orderIndex = 1
        intens.block = block

        container.mainContext.insert(block)
        container.mainContext.insert(accum)
        container.mainContext.insert(intens)
        return BlockContextBandPreviewContainer(container: container, block: block)
    }
}

#Preview("BlockContextBand") {
    BlockContextBandPreviewContainer.make()
}
#endif
