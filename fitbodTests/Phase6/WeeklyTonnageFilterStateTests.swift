//
//  WeeklyTonnageFilterStateTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-06 — locks the default-state contract for the new
//  `ChartFilterState` and the `TimeRangeChoice.lowerBound(now:calendar:)`
//  math used by the inner @Query host of `WeeklyTonnageView`.
//
//  Determinism: every lowerBound assertion uses a fixed anchor
//  `Date(timeIntervalSince1970: 1_700_000_000)` so the test is
//  insensitive to host calendar / timezone drift.
//
//  T104: Last 8 wk and Last 26 wk start at the start of the week 7 and 25
//  weeks before the anchor's, so they hold 8 and 26 whole weeks.
//

import Foundation
import Testing
@testable import fitbod

@Suite("WeeklyTonnageFilterState (CONTEXT D-19 defaults + TimeRangeChoice math)")
struct WeeklyTonnageFilterStateTests {

    private static let anchor = Date(timeIntervalSince1970: 1_700_000_000)
    private static let calendar = WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: true)

    /// Local midnight starting the given day. The anchor falls in the week
    /// of Monday 13 November 2023 in every time zone.
    private static func midnight(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("defaults — timeRange == .last26wk; blockPhases + selectedMuscles empty")
    func defaults() {
        let state = ChartFilterState()
        #expect(state.timeRange == .last26wk)
        #expect(state.blockPhases.isEmpty)
        #expect(state.selectedMuscles.isEmpty)
    }

    @Test("lowerBound — .last8wk returns the start of the week 7 weeks before the anchor's")
    func lowerBound8wk() throws {
        let lower = try #require(TimeRangeChoice.last8wk.lowerBound(now: Self.anchor, calendar: Self.calendar))
        #expect(lower == Self.midnight(2023, 9, 25))
    }

    @Test("lowerBound — .last26wk returns the start of the week 25 weeks before the anchor's")
    func lowerBound26wk() throws {
        let lower = try #require(TimeRangeChoice.last26wk.lowerBound(now: Self.anchor, calendar: Self.calendar))
        #expect(lower == Self.midnight(2023, 5, 22))
    }

    @Test("lowerBound — .allTime returns nil")
    func lowerBoundAllTime() {
        #expect(TimeRangeChoice.allTime.lowerBound(now: Self.anchor, calendar: Self.calendar) == nil)
    }
}
