//
//  PeriodizationEngine.swift
//  fitbod
//
//  Pure date/phase math for periodization blocks. This namespace does not
//  read or write ModelContext; callers provide Block instances and receive
//  either an existing BlockPhase or a Sendable value snapshot.
//
//  A block counts calendar days from the day it started, so each block week
//  starts at local midnight, whatever time the block started and across a
//  daylight-saving change (tradeoffs.md "Block weeks"). `startDate` keeps
//  the instant the block started. Each function takes a calendar,
//  `.current` by default as in `TrainingDaysWriter`, so a test can pick the
//  time zone.
//

import Foundation
import SwiftData

public enum PeriodizationEngine {
    public static func phase(for block: Block, on date: Date, calendar: Calendar = .current) -> BlockPhase? {
        let phases = sortedPhases(for: block)
        guard !phases.isEmpty else { return nil }

        let daysSinceStart = days(from: block.startDate, to: date, calendar: calendar)
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

    public static func weekIndex(for block: Block, on date: Date, calendar: Calendar = .current) -> Int? {
        let totalWeeks = sortedPhases(for: block).reduce(0) { $0 + $1.weeks }
        guard totalWeeks > 0 else { return nil }

        let daysSinceStart = days(from: block.startDate, to: date, calendar: calendar)
        let totalDays = totalWeeks * 7
        guard daysSinceStart >= 0, daysSinceStart < totalDays else { return nil }

        return daysSinceStart / 7
    }

    public static func weekContext(
        for block: Block,
        weekIndex: Int,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> MesocycleWeekContext? {
        guard weekIndex >= 0 else { return nil }

        let weekStartDate = startOfDay(weekIndex * 7, from: block.startDate, calendar: calendar)
        guard let phase = phase(for: block, on: weekStartDate, calendar: calendar) else { return nil }

        let phases = sortedPhases(for: block)
        var priorWeeks = 0
        for candidate in phases {
            if candidate.id == phase.id {
                break
            }
            priorWeeks += candidate.weeks
        }

        let weekInPhase = min(max((weekIndex - priorWeeks) + 1, 1), max(phase.weeks, 1))
        let currentWeekIndex = self.weekIndex(for: block, on: date, calendar: calendar)
        let isCurrentWeek = currentWeekIndex == weekIndex
        let daysRemaining: Int
        if isCurrentWeek {
            let daysSinceStart = days(from: block.startDate, to: date, calendar: calendar)
            daysRemaining = min(max(((weekIndex + 1) * 7) - daysSinceStart, 0), 7)
        } else {
            daysRemaining = 0
        }
        let nextWeekStartDate = startOfDay((weekIndex + 1) * 7, from: block.startDate, calendar: calendar)

        return MesocycleWeekContext(
            phaseKind: phase.kind,
            phaseOrder: phase.orderIndex,
            phaseWeeks: phase.weeks,
            weekInPhase: weekInPhase,
            phaseVolumeMultiplier: phase.volumeMultiplier,
            phaseIntensityMultiplier: phase.intensityMultiplier,
            weekStartDate: weekStartDate,
            weekEndDate: nextWeekStartDate.addingTimeInterval(-1),
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
            return .peak
        case .peak:
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

    /// Calendar days from the day `startDate` falls on to the day `date`
    /// falls on: 0 all through the block's first day and negative before
    /// it. Both days are read at noon, which every day has, because a
    /// daylight-saving change at midnight starts its day at 1 am.
    static func days(from startDate: Date, to date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: noon(of: startDate, calendar), to: noon(of: date, calendar)).day ?? 0
    }

    /// The first moment of the day `day` calendar days after the day
    /// `startDate` falls on: local midnight, or 1 am on a day that a
    /// daylight-saving change starts then.
    static func startOfDay(_ day: Int, from startDate: Date, calendar: Calendar = .current) -> Date {
        let noonThatDay = calendar.date(byAdding: .day, value: day, to: noon(of: startDate, calendar)) ?? startDate
        return calendar.startOfDay(for: noonThatDay)
    }

    private static func noon(of date: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }
}
