//
//  MesocycleWeekPage.swift
//  fitbod
//
//  One page in the active block swipe pager.
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
                Text(BlockPhaseColors.phaseLabel(weekContext.phaseKind))
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(BlockPhaseColors.color(for: weekContext.phaseKind))
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)

                Text(Self.weekBadgeText(for: block, weekIndex: weekIndex))
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())

                Text(Self.daysRemainingText(for: weekContext))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(Self.multiplierPreviewText(for: weekContext))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                let routines = Self.scheduledRoutines(for: block)
                if !routines.isEmpty {
                    Text("Routines this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(routines) { routine in
                        HStack {
                            Text(routine.name)
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No routines linked to this block.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: weekContext))
        } else {
            Text("Block ended — review pending.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(16)
        }
    }

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
