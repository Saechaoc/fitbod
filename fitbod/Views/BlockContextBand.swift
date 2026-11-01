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

    /// The chip beside the block's name: its phase, or PLAN COMPLETE once
    /// its plan is over (tradeoffs.md "A block past its plan").
    static func chipLabel(for block: Block, on date: Date) -> String {
        if PlanWeek.of(block, on: date) == .complete {
            return PlanWeek.completeLabel
        }
        guard let phase = PeriodizationEngine.phase(for: block, on: date) else { return "Accumulation" }
        // Capitalize first letter of each word (BlockPhaseKind raw values are lowercase)
        return phase.kind.rawValue
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
            .capitalized
    }

    /// The ticker's current week, from 1: week 1 before the block starts,
    /// and past every week once its plan is over, so none is current.
    static func tickerWeek(for block: Block, on date: Date) -> Int {
        switch PlanWeek.of(block, on: date) {
        case .week(let index): return index + 1
        case .complete: return MesocycleWeekPage.totalWeeks(of: block) + 1
        case nil: return 1
        }
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

    // MARK: - Top row

    private var blockChip: some View {
        BRUChip("Block")
            .fixedSize()
    }

    private var nameText: some View {
        Text(block.name.uppercased())
            .font(.bru(.grotesk, size: 11))
            .tracking(1.2)
            .foregroundStyle(Color.bruInk)
    }

    /// The phase or PLAN COMPLETE chip, on one line: on its own row, when
    /// even that is narrower than the chip, it shrinks rather than breaking a
    /// word.
    private var phaseChip: some View {
        BRUChip(Self.chipLabel(for: block, on: .now), color: .bruSignal, fill: true)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Block chip + name + phase chip, on one line while
                // they fit. Otherwise, as at xxLarge and up on the 390pt
                // phone, the phase chip moves under the name, so neither the
                // phase ("ACCUMULA" over "TION") nor the name breaks a word.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        blockChip

                        Spacer()

                        nameText

                        Spacer()

                        phaseChip
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            blockChip
                            nameText
                        }
                        phaseChip
                    }
                }

                // Week ticker cells row
                if totalWeeks > 0 {
                    WeekTickerCells(
                        currentWeek: Self.tickerWeek(for: block, on: .now),
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
