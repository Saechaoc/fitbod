//
//  BlockPastPlanTests.swift
//  fitbodTests
//
//  Ticket T78, T12 finding F71: an active block past its last planned week
//  read as week 1 on the block overview, Program's block row and Today's
//  band, because `PeriodizationEngine` has no week after the plan. It reads
//  PLAN COMPLETE instead, with every phase done and no current week
//  (tradeoffs.md "A block past its plan"). Inside its plan a block reads as
//  it did.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockPastPlan")
struct BlockPastPlanTests {

    /// Friday, Oct 30, 2026, noon UTC.
    private let now = Date(timeIntervalSinceReferenceDate: 815_054_400)

    /// An active four-week block, accumulation 2 weeks, intensification 1
    /// and deload 1, started `days` days before `now`.
    private func activeBlock(startedDaysAgo days: Int, in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = "Spring Block"
        block.isActive = true
        block.startDate = now.addingTimeInterval(-Double(days) * 86_400)
        let phases: [(BlockPhaseKind, Int)] = [(.accumulation, 2), (.intensification, 1), (.deload, 1)]
        for (index, (kind, weeks)) in phases.enumerated() {
            let phase = BlockPhase()
            context.insert(phase)
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = kind.rawValue
            phase.weeks = weeks
        }
        return block
    }

    private func phaseProgress(of block: Block) -> [PhaseProgress] {
        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return PhaseProgress.of(phaseWeeks: phases.map(\.weeks), at: PlanWeek.of(block, on: now))
    }

    /// Day 28 is the first day after the plan's 28 days; the ticket's block
    /// started five weeks ago.
    @Test("an active block past its four-week plan reads PLAN COMPLETE, not week 1", arguments: [28, 35])
    func pastItsPlan(startedDaysAgo days: Int) throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = activeBlock(startedDaysAgo: days, in: context)

        let planWeek = try #require(PlanWeek.of(block, on: now))
        #expect(planWeek == .complete)
        #expect(BlockOverviewScreen.heroHeadline(planWeek, of: block) == "PLAN COMPLETE")
        #expect(BlockOverviewScreen.stripHeader(planWeek, of: block) == "PLAN COMPLETE")

        let row = ProgramView.activeBlockWeek(of: block, on: now)
        #expect(row.badge == "PLAN COMPLETE")
        #expect(row.line == nil, "Program's row drops its week and phase line")
        #expect(row.spoken == "Plan complete")

        #expect(BlockContextBand.chipLabel(for: block, on: now) == "PLAN COMPLETE")
        // WeekTickerCells marks week n current when n is the ticker's week,
        // and past when n is below it.
        let tickerWeek = BlockContextBand.tickerWeek(for: block, on: now)
        #expect((1...4).allSatisfy { $0 < tickerWeek }, "Every week must be past and none current, not W\(tickerWeek)")

        #expect(phaseProgress(of: block) == [.done, .done, .done])
    }

    struct PlanDay: Sendable, CustomTestStringConvertible {
        let daysAgo: Int
        let week: Int
        let phase: String
        let progress: [PhaseProgress]
        var testDescription: String { "started \(daysAgo) days ago" }
    }

    @Test("inside its plan a block reads its week and phase as before", arguments: [
        PlanDay(daysAgo: 3, week: 1, phase: "Accumulation", progress: [.current, .upcoming, .upcoming]),
        PlanDay(daysAgo: 15, week: 3, phase: "Intensification", progress: [.done, .current, .upcoming]),
        PlanDay(daysAgo: 27, week: 4, phase: "Deload", progress: [.done, .done, .current]),
    ])
    func insideItsPlan(_ day: PlanDay) throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let block = activeBlock(startedDaysAgo: day.daysAgo, in: context)

        let planWeek = try #require(PlanWeek.of(block, on: now))
        #expect(planWeek == .week(day.week - 1))
        #expect(BlockOverviewScreen.heroHeadline(planWeek, of: block) == "\(day.phase) week")
        #expect(BlockOverviewScreen.stripHeader(planWeek, of: block) == "WEEK \(day.week) OF 4")

        let row = ProgramView.activeBlockWeek(of: block, on: now)
        #expect(row.badge == "W\(day.week) · \(day.phase.uppercased())")
        #expect(row.line == "Week \(day.week) of 4 · \(day.phase)")
        #expect(row.spoken == "Week \(day.week) of 4, \(day.phase)")

        #expect(BlockContextBand.chipLabel(for: block, on: now) == day.phase)
        #expect(BlockContextBand.tickerWeek(for: block, on: now) == day.week)
        #expect(phaseProgress(of: block) == day.progress)
    }
}
