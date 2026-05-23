//
//  MesocycleWeekContext.swift
//  fitbod
//
//  This is a Sendable value-type snapshot, not an @Model wrapper.
//  SwiftData @Model classes do not conform to Sendable under Swift 6
//  strict concurrency, so PeriodizationEngine cannot return a context
//  that holds a BlockPhase reference. Consumers read scalar fields
//  directly; there is no `context.phase.x` accessor path.
//

import Foundation

public struct MesocycleWeekContext: Sendable {
    public let phaseKind: BlockPhaseKind
    public let phaseOrder: Int
    public let phaseWeeks: Int
    public let weekInPhase: Int
    public let phaseVolumeMultiplier: Double
    public let phaseIntensityMultiplier: Double
    public let weekStartDate: Date
    public let weekEndDate: Date
    public let daysRemaining: Int
    public let isCurrentWeek: Bool
    public let isDeloadWeek: Bool

    public init(
        phaseKind: BlockPhaseKind,
        phaseOrder: Int,
        phaseWeeks: Int,
        weekInPhase: Int,
        phaseVolumeMultiplier: Double,
        phaseIntensityMultiplier: Double,
        weekStartDate: Date,
        weekEndDate: Date,
        daysRemaining: Int,
        isCurrentWeek: Bool,
        isDeloadWeek: Bool
    ) {
        self.phaseKind = phaseKind
        self.phaseOrder = phaseOrder
        self.phaseWeeks = phaseWeeks
        self.weekInPhase = weekInPhase
        self.phaseVolumeMultiplier = phaseVolumeMultiplier
        self.phaseIntensityMultiplier = phaseIntensityMultiplier
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.daysRemaining = daysRemaining
        self.isCurrentWeek = isCurrentWeek
        self.isDeloadWeek = isDeloadWeek
    }
}
