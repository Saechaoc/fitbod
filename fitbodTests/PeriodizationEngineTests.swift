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
            (BlockPhaseKind.intensification, BlockPhaseKind.peak),
            (BlockPhaseKind.peak, BlockPhaseKind.realization),
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

    // MARK: - Block weeks start at local midnight (T142, F359)

    /// Los Angeles, where the clocks went back an hour at 2 am on Sunday,
    /// Nov 1, 2026.
    private func losAngeles() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        return calendar
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
        in calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    /// Three weeks, one phase a week.
    private func makeThreeWeekBlock(startDate: Date) -> Block {
        makeBlock(startDate: startDate, phases: [
            (.accumulation, 1, 1.0, 0.75),
            (.intensification, 1, 0.85, 0.88),
            (.deload, 1, 0.5, 0.75),
        ])
    }

    @Test("a block week starts at local midnight, whatever time the block started")
    func blockWeekStartsAtLocalMidnight() throws {
        let losAngeles = try losAngeles()
        // Started on Monday, Oct 5, 2026 at 6:05 am.
        let block = makeThreeWeekBlock(startDate: try date(2026, 10, 5, 6, 5, in: losAngeles))
        let nextMondayMorning = try date(2026, 10, 12, 6, 0, in: losAngeles)

        #expect(PeriodizationEngine.weekIndex(for: block, on: nextMondayMorning, calendar: losAngeles) == 1)
        #expect(PeriodizationEngine.phase(for: block, on: nextMondayMorning, calendar: losAngeles)?.kind == .intensification)
    }

    @Test("a daylight-saving change does not move a block week")
    func daylightSavingChangeKeepsTheWeek() throws {
        let losAngeles = try losAngeles()
        // Started at local midnight on Monday, Oct 26, 2026, a week that
        // is an hour longer than 7 × 86,400 s.
        let block = makeThreeWeekBlock(startDate: try date(2026, 10, 26, in: losAngeles))
        let sundayNight = try date(2026, 11, 1, 23, 30, in: losAngeles)

        #expect(PeriodizationEngine.weekIndex(for: block, on: sundayNight, calendar: losAngeles) == 0)
        #expect(PeriodizationEngine.phase(for: block, on: sundayNight, calendar: losAngeles)?.kind == .accumulation)
    }

    @Test("a week context runs from local midnight to local midnight")
    func weekContextRunsMidnightToMidnight() throws {
        let losAngeles = try losAngeles()
        let block = makeThreeWeekBlock(startDate: try date(2026, 10, 26, 18, 30, in: losAngeles))
        let mondayMorning = try date(2026, 11, 2, 7, 0, in: losAngeles)

        let context = try #require(
            PeriodizationEngine.weekContext(for: block, weekIndex: 1, on: mondayMorning, calendar: losAngeles)
        )

        #expect(context.weekStartDate == (try date(2026, 11, 2, in: losAngeles)))
        #expect(context.weekEndDate == (try date(2026, 11, 9, in: losAngeles)).addingTimeInterval(-1))
        #expect(context.isCurrentWeek)
        #expect(context.daysRemaining == 7)
    }

    @Test("a day that starts at 1 am is still one block day")
    func dayWithoutMidnightIsOneDay() throws {
        var saoPaulo = Calendar(identifier: .gregorian)
        saoPaulo.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        // The clocks went from midnight to 1 am on Sunday, Nov 4, 2018.
        let block = makeThreeWeekBlock(startDate: try date(2018, 11, 4, 10, 0, in: saoPaulo))
        let nextSunday = try date(2018, 11, 11, 10, 30, in: saoPaulo)

        #expect(PeriodizationEngine.weekIndex(for: block, on: nextSunday, calendar: saoPaulo) == 1)
    }
}
