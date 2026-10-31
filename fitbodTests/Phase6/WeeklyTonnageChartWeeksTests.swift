//
//  WeeklyTonnageChartWeeksTests.swift
//  fitbodTests
//
//  Ticket T23, review item 38: the weeks the Weekly Tonnage chart draws.
//
//    - The chart and WeeklyTonnageAggregator put a Sunday workout in the
//      same week, with the week-start setting at Monday and at Sunday: the
//      chart's calendar bins the Sunday into the week the aggregator totals
//      it in, and draws that week's bar over exactly that week. The device
//      calendar starts weeks on Sunday in the US, so it must not decide.
//    - The axis marks a gridline at every one of the setting's week starts.
//    - The axis covers the whole selected range, so one week of data draws
//      one narrow bar. Last 8 wk and Last 26 wk span from the week that holds
//      their rolling lower bound through the current week, 9 and 27 weeks
//      here, and All time spans from the oldest week but never less than
//      Last 8 wk.
//    - Every week value in the chart names the chart's calendar.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WeeklyTonnageChartWeeks (T23, review item 38)", .serialized)
struct WeeklyTonnageChartWeeksTests {

    // MARK: - Fixtures

    /// The local Gregorian calendar the fixture dates are written in. The
    /// aggregator and the chart use the same time zone.
    private static let local = Calendar(identifier: .gregorian)

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        local.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Sunday 3 May 2026, 09:00.
    private static let sunday = date(2026, 5, 3, hour: 9)
    /// Wednesday 6 May 2026, noon: "now" for the axis checks.
    private static let wednesday = date(2026, 5, 6, hour: 12)

    private func bars(
        loggedAt dates: [Date],
        weekStartsMonday: Bool,
        in context: ModelContext
    ) -> [WeeklyTonnageBar] {
        let sets = dates.map { completedAt in
            let set = SetEntry()
            context.insert(set)
            set.weight = 100
            set.reps = 5
            set.setTypeRaw = SetType.working.rawValue
            set.isWarmup = false
            set.isComplete = true
            set.completedAt = completedAt
            return set
        }
        return WeeklyTonnageAggregator.aggregate(
            sets: sets,
            weekStartsMonday: weekStartsMonday,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    // MARK: - A Sunday workout's week

    @Test("A Sunday workout sits in the same week in the chart as in the totals", arguments: [true, false])
    func sundayWorkoutSharesItsWeek(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        let bar = try #require(bars(loggedAt: [Self.sunday], weekStartsMonday: weekStartsMonday, in: context).first)
        let expectedStart = Self.date(2026, weekStartsMonday ? 4 : 5, weekStartsMonday ? 27 : 3)
        #expect(bar.weekStart == expectedStart, "The totals count the Sunday in the week of \(expectedStart)")

        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        let chartWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: Self.sunday))
        #expect(
            chartWeek.start == bar.weekStart,
            "The chart puts the Sunday in the week of \(chartWeek.start), the totals in the week of \(bar.weekStart)"
        )
        // A bar spans the chart week its x value falls in, so the totals'
        // week must be one of the chart's weeks, not straddle two.
        let drawnWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: bar.weekStart))
        #expect(drawnWeek == chartWeek, "The chart draws the Sunday's bar over \(drawnWeek), not \(chartWeek)")
    }

    @Test("The axis marks every one of the setting's week starts", arguments: [true, false])
    func axisMarksTheSettingsWeekStarts(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        let bars = bars(loggedAt: [Self.sunday], weekStartsMonday: weekStartsMonday, in: context)
        let domain = WeeklyTonnageChartWeeks.domain(for: .last8wk, bars: bars, now: Self.wednesday, calendar: calendar)
        let marks = WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar)

        let weekday = weekStartsMonday ? 2 : 1
        #expect(marks.count > 1)
        for mark in marks {
            #expect(Self.local.component(.weekday, from: mark) == weekday, "\(mark) is not a week start")
            #expect(Self.local.startOfDay(for: mark) == mark, "\(mark) is not midnight")
        }
        #expect(marks.contains(try #require(bars.first).weekStart), "No gridline starts the Sunday's week")
    }

    // MARK: - The axis covers the selected range

    @Test(
        "One week of data takes one of the range's weeks",
        arguments: [(TimeRangeChoice.last8wk, 9), (.last26wk, 27), (.allTime, 9)]
    )
    func oneWeekTakesOneOfTheRangesWeeks(range: TimeRangeChoice, expectedWeeks: Int) throws {
        let context = try makeContext()
        for weekStartsMonday in [true, false] {
            let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
            let bars = bars(loggedAt: [Self.wednesday], weekStartsMonday: weekStartsMonday, in: context)
            let domain = WeeklyTonnageChartWeeks.domain(for: range, bars: bars, now: Self.wednesday, calendar: calendar)
            let weeks = WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar).count - 1

            #expect(weeks == expectedWeeks, "\(range), week starts Monday \(weekStartsMonday): \(weeks) weeks")
            let rollingStart = range.lowerBound(now: Self.wednesday) ?? TimeRangeChoice.last8wk.lowerBound(now: Self.wednesday)
            let firstWeek = try #require(rollingStart.flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) })
            let currentWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: Self.wednesday))
            #expect(domain.lowerBound == firstWeek.start)
            #expect(domain.upperBound == currentWeek.end)
        }
    }

    @Test("All time starts at the oldest week of data")
    func allTimeStartsAtTheOldestWeek() throws {
        let context = try makeContext()
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: true)
        let old = try #require(Self.local.date(byAdding: .weekOfYear, value: -20, to: Self.wednesday))
        let bars = bars(loggedAt: [old, Self.wednesday], weekStartsMonday: true, in: context)
        let domain = WeeklyTonnageChartWeeks.domain(for: .allTime, bars: bars, now: Self.wednesday, calendar: calendar)

        #expect(domain.lowerBound == bars.first?.weekStart)
        #expect(WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar).count - 1 == 21)
    }

    // MARK: - The chart uses its calendar

    @Test("Every week value in the chart names the chart's calendar")
    func weekValuesNameTheChartsCalendar() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("fitbod/Progress/WeeklyTonnageView.swift"),
            encoding: .utf8
        )
        let weekValues = source.components(separatedBy: "unit: .weekOfYear").count - 1
        let calendarWeekValues = source.components(separatedBy: "unit: .weekOfYear, calendar: calendar)").count - 1
        #expect(weekValues > 0)
        #expect(calendarWeekValues == weekValues, "A BarMark bins weeks with the device calendar")
        #expect(!source.contains(".stride(by: .weekOfYear)"), "The x axis marks the device calendar's weeks")
    }
}
