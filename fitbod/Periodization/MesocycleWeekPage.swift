//
//  MesocycleWeekPage.swift
//  fitbod
//
//  One page in the active block swipe pager.
//  Phase 04.1 (BRU re-skin) — see 04.1-PATTERNS.md File #8
//

import SwiftUI

public struct MesocycleWeekPage: View {
    public let block: Block
    public let weekIndex: Int

    public init(block: Block, weekIndex: Int) {
        self.block = block
        self.weekIndex = weekIndex
    }

    public var body: some View {
        if let weekContext = PeriodizationEngine.weekContext(for: block, weekIndex: weekIndex, on: .now) {
            VStack(alignment: .leading, spacing: 8) {
                // Phase chip — BRUChip replaces Capsule + Color.white text
                BRUChip(
                    BlockPhaseColors.phaseLabel(weekContext.phaseKind).uppercased(),
                    color: phaseChipColor(for: weekContext.phaseKind),
                    fill: shouldFillChip(for: weekContext.phaseKind)
                )
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)

                // Week badge — BRUChip replaces .headline + Capsule + systemGray6
                BRUChip(Self.weekBadgeText(for: block, weekIndex: weekIndex).uppercased(), color: .bruInk)

                // Days remaining + multiplier captions
                Text(Self.daysRemainingText(for: weekContext))
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)

                Text(Self.multiplierPreviewText(for: weekContext))
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)

                // Hair divider — replaces Divider()
                Rectangle()
                    .fill(Color.bruHair)
                    .frame(height: 1)

                let routines = Self.scheduledRoutines(for: block)
                if !routines.isEmpty {
                    Text("Routines this week")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                    ForEach(routines) { routine in
                        HStack {
                            Text(routine.name)
                                .font(BRUFont.bodyEmphasis)
                                .foregroundStyle(Color.bruInk)
                            Spacer()
                            // Typographic chevron — replaces Image(systemName: "chevron.right")
                            Text("›")
                                .font(BRUFont.labelSmall)
                                .foregroundStyle(Color.bruMuted)
                        }
                    }
                } else {
                    Text("No routines linked to this block.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .padding(16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: weekContext))
        } else {
            Text("Block ended — review pending.")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
                .padding(16)
        }
    }

    // MARK: - Phase chip color helpers

    private func phaseChipColor(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .intensification, .deload:
            return Color.bruSignal
        default:
            return Color.bruInk
        }
    }

    private func shouldFillChip(for kind: BlockPhaseKind) -> Bool {
        kind == .intensification
    }

    // MARK: - Static helpers (preserved verbatim)

    public static func totalWeeks(of block: Block) -> Int {
        (block.phases ?? []).reduce(0) { $0 + $1.weeks }
    }

    public static func scheduledRoutines(for block: Block) -> [Routine] {
        (block.routines ?? []).sorted { $0.name < $1.name }
    }

    public static func weekBadgeText(for block: Block, weekIndex: Int) -> String {
        "Week \(weekIndex + 1) of \(totalWeeks(of: block))"
    }

    public static func daysRemainingText(for weekContext: MesocycleWeekContext, now: Date = .now) -> String {
        if weekContext.isCurrentWeek {
            return "\(weekContext.daysRemaining) days remaining"
        }
        if weekContext.weekEndDate < now {
            return "Completed"
        }
        let daysUntilStart = max(0, Int(floor(weekContext.weekStartDate.timeIntervalSince(now) / 86_400)))
        return "Starts in \(daysUntilStart) days"
    }

    public static func multiplierPreviewText(for weekContext: MesocycleWeekContext) -> String {
        String(
            format: "×%.2f vol · ×%.2f int",
            weekContext.phaseVolumeMultiplier,
            weekContext.phaseIntensityMultiplier
        )
    }

    private func accessibilityLabel(for weekContext: MesocycleWeekContext) -> String {
        let routinesCount = Self.scheduledRoutines(for: block).count
        return "Week \(weekIndex + 1) of \(Self.totalWeeks(of: block)), \(BlockPhaseColors.phaseLabel(weekContext.phaseKind)) phase, volume multiplier \(weekContext.phaseVolumeMultiplier), intensity multiplier \(weekContext.phaseIntensityMultiplier), \(routinesCount) routines this week."
    }
}
