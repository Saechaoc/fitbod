//
//  BlockCardWeekNavigationTests.swift
//  fitbodTests
//
//  Phase 4 coverage for BlockCard and MesocycleWeekPage helper paths.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("BlockCardWeekNavigation", .serialized)
struct BlockCardWeekNavigationTests {
    private let day: TimeInterval = 86_400

    private func makeBlock(
        startDate: Date,
        phases specs: [(BlockPhaseKind, Int, Double, Double)] = [
            (.accumulation, 4, 1.0, 0.75),
            (.intensification, 2, 0.85, 0.88),
            (.realization, 1, 0.6, 0.97),
            (.deload, 1, 0.5, 0.75),
        ]
    ) -> Block {
        let block = Block()
        block.name = "Test Block"
        block.startDate = startDate
        block.isActive = true
        block.phases = specs.enumerated().map { index, spec in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = spec.0.rawValue
            phase.weeks = spec.1
            phase.volumeMultiplier = spec.2
            phase.intensityMultiplier = spec.3
            return phase
        }
        return block
    }

    @Test("initial selected week index is current week")
    func initialSelectedWeekIndexIsCurrentWeek() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now.addingTimeInterval(-14 * day))

        #expect(PeriodizationEngine.weekIndex(for: block, on: now) == 2)
        #expect(BlockCard.initialSelectedWeekIndex(for: block, on: now) == 2)
    }

    @Test("days remaining for current week")
    func daysRemainingForCurrentWeek() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now.addingTimeInterval(-3 * day))

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 0, on: now))

        #expect(context.daysRemaining == 4)
        #expect(context.isCurrentWeek == true)
    }

    @Test("days remaining for future week is zero")
    func daysRemainingForFutureWeekIsZero() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now)

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 3, on: now))

        #expect(context.daysRemaining == 0)
        #expect(context.isCurrentWeek == false)
    }

    @Test("deload week detected")
    func deloadWeekDetected() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(
            startDate: now,
            phases: [
                (.accumulation, 3, 1.0, 0.75),
                (.deload, 1, 0.5, 0.75),
            ]
        )

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 3, on: now))

        #expect(context.isDeloadWeek == true)
        #expect(context.phaseKind == .deload)
    }

    @Test("week badge format is one indexed")
    func weekBadgeFormatIsOneIndexed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now)

        #expect(MesocycleWeekPage.weekBadgeText(for: block, weekIndex: 4) == "Week 5 of 8")
    }

    // NOTE (V7): scheduledRoutines(for:) was removed in V7 (Block.routines replaced
    // by Block→Split→SplitSessionSlot graph). The V6 sort-by-name logic is covered
    // by the new Split-slot ordering tests in 07-06. This test is retired in V7.
    // @Test("scheduled routines sorted by name")
    // func scheduledRoutinesSortedByName() { ... }
    func scheduledRoutinesSortedByName_v7Retired() {
        // V7: Block.routines and MesocycleWeekPage.scheduledRoutines removed.
        // Verified in V6 history; replaced by Split-slot order tests (07-06).
    }

    @Test("days remaining text current week format")
    func daysRemainingTextCurrentWeekFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let context = makeContext(now: now, daysRemaining: 4, isCurrentWeek: true)

        #expect(MesocycleWeekPage.daysRemainingText(for: context, now: now) == "4 days remaining")
    }

    @Test("days remaining text completed week format")
    func daysRemainingTextCompletedWeekFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let context = makeContext(
            now: now,
            weekStartOffsetDays: -14,
            weekEndOffsetDays: -7,
            daysRemaining: 0,
            isCurrentWeek: false
        )

        #expect(MesocycleWeekPage.daysRemainingText(for: context, now: now) == "Completed")
    }

    @Test("days remaining text future week format")
    func daysRemainingTextFutureWeekFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let context = makeContext(
            now: now,
            weekStartOffsetDays: 21,
            weekEndOffsetDays: 28,
            daysRemaining: 0,
            isCurrentWeek: false
        )

        #expect(MesocycleWeekPage.daysRemainingText(for: context, now: now) == "Starts in 21 days")
    }

    @Test("multiplier preview format uses scalar fields")
    func multiplierPreviewFormatUsesScalarFields() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let context = makeContext(
            now: now,
            phaseVolumeMultiplier: 0.85,
            phaseIntensityMultiplier: 0.88
        )

        #expect(MesocycleWeekPage.multiplierPreviewText(for: context) == "×0.85 vol · ×0.88 int")
    }

    private func makeContext(
        now: Date,
        phaseKind: BlockPhaseKind = .accumulation,
        phaseVolumeMultiplier: Double = 1.0,
        phaseIntensityMultiplier: Double = 0.75,
        weekStartOffsetDays: Int = 0,
        weekEndOffsetDays: Int = 7,
        daysRemaining: Int = 0,
        isCurrentWeek: Bool = false
    ) -> MesocycleWeekContext {
        MesocycleWeekContext(
            phaseKind: phaseKind,
            phaseOrder: 0,
            phaseWeeks: 4,
            weekInPhase: 1,
            phaseVolumeMultiplier: phaseVolumeMultiplier,
            phaseIntensityMultiplier: phaseIntensityMultiplier,
            weekStartDate: now.addingTimeInterval(Double(weekStartOffsetDays) * day),
            weekEndDate: now.addingTimeInterval(Double(weekEndOffsetDays) * day),
            daysRemaining: daysRemaining,
            isCurrentWeek: isCurrentWeek,
            isDeloadWeek: phaseKind == .deload
        )
    }
}
