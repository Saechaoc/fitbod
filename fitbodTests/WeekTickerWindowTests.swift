//
//  WeekTickerWindowTests.swift
//  fitbodTests
//
//  Today's week strip stopped at five weeks, so the 8-week presets never
//  showed weeks 6 to 8 or the deload week's DL mark (gap B6). It now shows
//  every week up to eight, and past that eight weeks that keep this week
//  in view.
//

import Testing
@testable import fitbod

struct WeekTickerWindowTests {

    @Test("A block of up to eight weeks shows every week, this week anywhere")
    func shortBlocksShowEveryWeek() {
        #expect(WeekTickerCells.visibleWeeks(current: 1, total: 4) == 1...4)
        #expect(WeekTickerCells.visibleWeeks(current: 6, total: 8) == 1...8)
        #expect(WeekTickerCells.visibleWeeks(current: 9, total: 8) == 1...8, "Past the plan, every week is past")
    }

    @Test("A longer block shows eight weeks with this week in view")
    func longBlocksKeepThisWeekInView() {
        #expect(WeekTickerCells.visibleWeeks(current: 1, total: 12) == 1...8)
        #expect(WeekTickerCells.visibleWeeks(current: 6, total: 12) == 3...10, "Three weeks before this one")
        #expect(WeekTickerCells.visibleWeeks(current: 10, total: 12) == 5...12)
        #expect(WeekTickerCells.visibleWeeks(current: 13, total: 12) == 5...12, "Past the plan, the last eight")
    }
}
