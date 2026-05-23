//
//  PeriodizationEngineTests.swift
//  fitbodTests
//
//  Phase 4 Wave 0 coverage for block phase/date math. These tests are
//  pure-function checks: they construct Block/BlockPhase model instances
//  directly, then exercise PeriodizationEngine without querying SwiftData.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("PeriodizationEngine", .serialized)
struct PeriodizationEngineTests {
    private let day: TimeInterval = 86_400

    private func makeBlock(
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        phases specs: [(kind: BlockPhaseKind, weeks: Int, volume: Double, intensity: Double)] = [
            (.accumulation, 3, 1.0, 0.75),
            (.intensification, 2, 0.85, 0.88),
            (.deload, 1, 0.5, 0.75),
        ]
    ) -> Block {
        let block = Block()
        block.name = "Test Block"
        block.startDate = startDate
        block.phases = specs.enumerated().map { index, spec in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = spec.kind.rawValue
            phase.weeks = spec.weeks
            phase.volumeMultiplier = spec.volume
            phase.intensityMultiplier = spec.intensity
            return phase
        }
        return block
    }

    @Test("phase resolves accumulation on day zero")
    func phaseOneInAccumulationOnDayZero() {
        let block = makeBlock()

        #expect(PeriodizationEngine.phase(for: block, on: block.startDate)?.kind == .accumulation)
    }

    @Test("phase resolves intensification on day 21")
    func phaseTwoInIntensificationOnDay21() {
        let block = makeBlock()

        let date = block.startDate.addingTimeInterval(21 * day)

        #expect(PeriodizationEngine.phase(for: block, on: date)?.kind == .intensification)
    }

    @Test("phase resolves deload on day 35")
    func phaseDeloadOnDay35() {
        let block = makeBlock()

        let date = block.startDate.addingTimeInterval(35 * day)

        #expect(PeriodizationEngine.phase(for: block, on: date)?.kind == .deload)
    }

    @Test("phase returns nil past total block duration")
    func phasePastEndReturnsNil() {
        let block = makeBlock()

        let date = block.startDate.addingTimeInterval(42 * day)

        #expect(PeriodizationEngine.phase(for: block, on: date) == nil)
    }

    @Test("phase before block start returns first phase")
    func phaseBeforeStartReturnsFirstPhase() {
        let block = makeBlock()

        let date = block.startDate.addingTimeInterval(-day)

        #expect(PeriodizationEngine.phase(for: block, on: date)?.kind == .accumulation)
    }

    @Test("week index resolves day zero")
    func weekIndexOnDayZero() {
        let block = makeBlock()

        #expect(PeriodizationEngine.weekIndex(for: block, on: block.startDate) == 0)
    }

    @Test("week index resolves day 14")
    func weekIndexOnDay14() {
        let block = makeBlock()

        let date = block.startDate.addingTimeInterval(14 * day)

        #expect(PeriodizationEngine.weekIndex(for: block, on: date) == 2)
    }

    @Test("week index before start returns nil")
    func weekIndexBeforeStartReturnsNil() {
        let block = makeBlock()

        #expect(PeriodizationEngine.weekIndex(for: block, on: block.startDate.addingTimeInterval(-day)) == nil)
    }

    @Test("week index at total days returns nil")
    func weekIndexAtTotalDaysReturnsNil() {
        let block = makeBlock()

        #expect(PeriodizationEngine.weekIndex(for: block, on: block.startDate.addingTimeInterval(42 * day)) == nil)
    }

    @Test(
        "recommended next kind map is deterministic",
        arguments: [
            (BlockPhaseKind.accumulation, BlockPhaseKind.intensification),
            (BlockPhaseKind.intensification, BlockPhaseKind.realization),
            (BlockPhaseKind.realization, BlockPhaseKind.deload),
            (BlockPhaseKind.deload, BlockPhaseKind.accumulation),
        ]
    )
    func recommendedNextDeterministicMap(input: BlockPhaseKind, expected: BlockPhaseKind) {
        #expect(PeriodizationEngine.recommendedNextKind(after: input) == expected)
    }

    @Test("phase returns nil when block has no phases")
    func phaseEmptyPhasesReturnsNil() {
        let block = makeBlock(phases: [])

        #expect(PeriodizationEngine.phase(for: block, on: block.startDate) == nil)
    }

    @Test("week context exposes scalar snapshot fields for the phase")
    func weekContextSnapshotFieldsMatchPhase() throws {
        let block = makeBlock()

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 0, on: block.startDate))

        #expect(context.phaseKind == .accumulation)
        #expect(context.phaseOrder == 0)
        #expect(context.phaseWeeks == 3)
        #expect(context.weekInPhase == 1)
        #expect(context.phaseVolumeMultiplier == 1.0)
        #expect(context.phaseIntensityMultiplier == 0.75)
        #expect(context.isCurrentWeek == true)
        #expect(context.isDeloadWeek == false)
    }

    @Test("week context flags deload week")
    func weekContextDeloadWeekFlag() throws {
        let block = makeBlock()

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 5, on: block.startDate))

        #expect(context.phaseKind == .deload)
        #expect(context.isDeloadWeek == true)
    }

    @Test("week context days remaining is computed for the current week")
    func weekContextDaysRemainingForCurrentWeek() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now.addingTimeInterval(-3 * day))

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 0, on: now))

        #expect(context.isCurrentWeek == true)
        #expect(context.daysRemaining == 4)
    }

    @Test("week context days remaining is zero for non-current weeks")
    func weekContextDaysRemainingForFutureWeekIsZero() throws {
        let block = makeBlock()

        let context = try #require(PeriodizationEngine.weekContext(for: block, weekIndex: 3, on: block.startDate))

        #expect(context.isCurrentWeek == false)
        #expect(context.daysRemaining == 0)
    }
}
