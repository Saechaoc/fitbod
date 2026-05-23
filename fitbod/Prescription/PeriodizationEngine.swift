//
//  PeriodizationEngine.swift
//  fitbod
//
//  Pure date/phase math for periodization blocks. This namespace does not
//  read or write ModelContext; callers provide Block instances and receive
//  either an existing BlockPhase or a Sendable value snapshot.
//

import Foundation
import SwiftData

public enum PeriodizationEngine {
    private static let secondsPerDay: TimeInterval = 86_400

    public static func phase(for block: Block, on date: Date) -> BlockPhase? {
        let phases = sortedPhases(for: block)
        guard !phases.isEmpty else { return nil }

        let daysSinceStart = days(from: block.startDate, to: date)
        guard daysSinceStart >= 0 else { return phases.first }

        var cumulativeDays = 0
        for phase in phases {
            let phaseDays = phase.weeks * 7
            if daysSinceStart < cumulativeDays + phaseDays {
                return phase
            }
            cumulativeDays += phaseDays
        }
        return nil
    }

    public static func weekIndex(for block: Block, on date: Date) -> Int? {
        let totalWeeks = sortedPhases(for: block).reduce(0) { $0 + $1.weeks }
        guard totalWeeks > 0 else { return nil }

        let daysSinceStart = days(from: block.startDate, to: date)
        let totalDays = totalWeeks * 7
        guard daysSinceStart >= 0, daysSinceStart < totalDays else { return nil }

        return daysSinceStart / 7
    }

    public static func weekContext(
        for block: Block,
        weekIndex: Int,
        on date: Date = .now
    ) -> MesocycleWeekContext? {
        guard weekIndex >= 0 else { return nil }

        let weekStartDate = block.startDate.addingTimeInterval(Double(weekIndex * 7) * secondsPerDay)
        guard let phase = phase(for: block, on: weekStartDate) else { return nil }

        let phases = sortedPhases(for: block)
        var priorWeeks = 0
        for candidate in phases {
            if candidate.id == phase.id {
                break
            }
            priorWeeks += candidate.weeks
        }

        let weekInPhase = min(max((weekIndex - priorWeeks) + 1, 1), max(phase.weeks, 1))
        let currentWeekIndex = self.weekIndex(for: block, on: date)
        let isCurrentWeek = currentWeekIndex == weekIndex
        let daysRemaining: Int
        if isCurrentWeek {
            let daysSinceStart = days(from: block.startDate, to: date)
            daysRemaining = min(max(((weekIndex + 1) * 7) - daysSinceStart, 0), 7)
        } else {
            daysRemaining = 0
        }

        return MesocycleWeekContext(
            phaseKind: phase.kind,
            phaseOrder: phase.orderIndex,
            phaseWeeks: phase.weeks,
            weekInPhase: weekInPhase,
            phaseVolumeMultiplier: phase.volumeMultiplier,
            phaseIntensityMultiplier: phase.intensityMultiplier,
            weekStartDate: weekStartDate,
            weekEndDate: weekStartDate.addingTimeInterval((7 * secondsPerDay) - 1),
            daysRemaining: daysRemaining,
            isCurrentWeek: isCurrentWeek,
            isDeloadWeek: phase.kind == .deload
        )
    }

    public static func recommendedNextKind(after kind: BlockPhaseKind) -> BlockPhaseKind {
        switch kind {
        case .accumulation:
            return .intensification
        case .intensification:
            return .realization
        case .realization:
            return .deload
        case .deload:
            return .accumulation
        }
    }

    private static func sortedPhases(for block: Block) -> [BlockPhase] {
        (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private static func days(from startDate: Date, to date: Date) -> Int {
        Int(floor(date.timeIntervalSince(startDate) / secondsPerDay))
    }
}
