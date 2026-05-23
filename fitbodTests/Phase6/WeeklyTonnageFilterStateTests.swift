//
//  WeeklyTonnageFilterStateTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-06 — locks the default-state contract for the new
//  `ChartFilterState` and the `TimeRangeChoice.lowerBound(now:)` math
//  used by the inner @Query host of `WeeklyTonnageView`.
//
//  Determinism: every lowerBound assertion uses a fixed anchor
//  `Date(timeIntervalSince1970: 1_700_000_000)` so the test is
//  insensitive to host calendar / timezone drift.
//

import Foundation
import Testing
@testable import fitbod

@Suite("WeeklyTonnageFilterState (CONTEXT D-19 defaults + TimeRangeChoice math)")
struct WeeklyTonnageFilterStateTests {

    private static let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("defaults — timeRange == .last26wk; blockPhases + selectedMuscles empty")
    func defaults() {
        let state = ChartFilterState()
        #expect(state.timeRange == .last26wk)
        #expect(state.blockPhases.isEmpty)
        #expect(state.selectedMuscles.isEmpty)
    }

    @Test("lowerBound — .last8wk returns anchor - 8 weeks")
    func lowerBound8wk() throws {
        let lower = try #require(TimeRangeChoice.last8wk.lowerBound(now: Self.anchor))
        let expected = try #require(Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Self.anchor))
        #expect(lower == expected)
    }

    @Test("lowerBound — .last26wk returns anchor - 26 weeks")
    func lowerBound26wk() throws {
        let lower = try #require(TimeRangeChoice.last26wk.lowerBound(now: Self.anchor))
        let expected = try #require(Calendar.current.date(byAdding: .weekOfYear, value: -26, to: Self.anchor))
        #expect(lower == expected)
    }

    @Test("lowerBound — .allTime returns nil")
    func lowerBoundAllTime() {
        #expect(TimeRangeChoice.allTime.lowerBound(now: Self.anchor) == nil)
    }
}
