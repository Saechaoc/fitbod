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
//      one narrow bar. Last 8 wk and Last 26 wk span their 8 and 26 whole
//      weeks through the current week (T104), and All time spans from the
//      oldest week but never less than Last 8 wk.
//
//  Ticket T104:
//
//    - Last 8 wk and Last 26 wk start at a week start, on every weekday and
//      with either week-start setting, so the chart shows exactly 8 or 26
//      week slots, and Last 8 wk never holds a ninth week of data.
//    - A workout that starts on a week's last evening and finishes after
//      midnight counts in the same week in the week detail as on its bar,
//      and the detail totals the bar.
//    - The chart works out its weeks itself and hands Swift Charts plain
//      dates, never a unit or calendar to bin by: each bar sits inside its
//      week with a gap to the next, and the values it plots are finite and
//      the same on every build, with bar ids that never change.
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
        arguments: [(TimeRangeChoice.last8wk, 8), (.last26wk, 26), (.allTime, 8)]
    )
    func oneWeekTakesOneOfTheRangesWeeks(range: TimeRangeChoice, expectedWeeks: Int) throws {
        let context = try makeContext()
        for weekStartsMonday in [true, false] {
            let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
            let bars = bars(loggedAt: [Self.wednesday], weekStartsMonday: weekStartsMonday, in: context)
            let domain = WeeklyTonnageChartWeeks.domain(for: range, bars: bars, now: Self.wednesday, calendar: calendar)
            let weeks = WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar).count - 1

            #expect(weeks == expectedWeeks, "\(range), week starts Monday \(weekStartsMonday): \(weeks) weeks")
            let firstWeek = range.lowerBound(now: Self.wednesday, calendar: calendar)
                ?? TimeRangeChoice.last8wk.lowerBound(now: Self.wednesday, calendar: calendar)
            let currentWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: Self.wednesday))
            #expect(domain.lowerBound == firstWeek)
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

    // MARK: - Last 8 wk and Last 26 wk hold whole weeks (T104)

    /// 00:30, noon and 23:30 on each day from Monday 4 to Sunday 10 May
    /// 2026, so "now" falls on every weekday at both ends of the day.
    private static let nowsAcrossAWeek: [Date] = (4...10).flatMap { day in
        [
            date(2026, 5, day).addingTimeInterval(30 * 60),
            date(2026, 5, day, hour: 12),
            date(2026, 5, day, hour: 23).addingTimeInterval(30 * 60),
        ]
    }

    @Test(
        "Last 8 wk and Last 26 wk span exactly 8 and 26 week slots from a week start, on every weekday",
        arguments: [true, false]
    )
    func rangesSpanWholeWeeks(weekStartsMonday: Bool) throws {
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        let weekday = weekStartsMonday ? 2 : 1
        for (range, slots) in [(TimeRangeChoice.last8wk, 8), (.last26wk, 26)] {
            for now in Self.nowsAcrossAWeek {
                let domain = WeeklyTonnageChartWeeks.domain(for: range, bars: [], now: now, calendar: calendar)
                let drawn = WeeklyTonnageChartWeeks.weekStarts(in: domain, calendar: calendar).count - 1
                let thisWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
                #expect(drawn == slots, "\(range) at \(now), week starts Monday \(weekStartsMonday): \(drawn) week slots")
                #expect(
                    Self.local.component(.weekday, from: domain.lowerBound) == weekday
                        && Self.local.startOfDay(for: domain.lowerBound) == domain.lowerBound,
                    "\(range) at \(now) starts at \(domain.lowerBound), not at a week start"
                )
                #expect(domain.upperBound == thisWeek.end, "\(range) at \(now) must end with this week")
                #expect(
                    range.lowerBound(now: now, calendar: calendar) == domain.lowerBound,
                    "\(range) at \(now) must query its sets from the week the chart starts at"
                )
            }
        }
    }

    @Test("Last 8 wk holds at most 8 weeks of data, so its label never reads 9", arguments: [true, false])
    func lastEightWeeksHoldsEightWeeksOfData(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        for now in Self.nowsAcrossAWeek {
            // A workout every day for ten weeks, through today. The chart's
            // query keeps the sets from the range's lower bound on.
            let lowerBound = try #require(TimeRangeChoice.last8wk.lowerBound(now: now, calendar: calendar))
            let days = (0..<70).compactMap { Self.local.date(byAdding: .day, value: -$0, to: now) }
            let bars = bars(loggedAt: days.filter { $0 >= lowerBound }, weekStartsMonday: weekStartsMonday, in: context)
            #expect(bars.count == 8, "Last 8 wk at \(now), week starts Monday \(weekStartsMonday), holds \(bars.count) weeks")
        }
    }

    // MARK: - The week detail counts what its bar counts (T104)

    /// A "Late Push" workout that starts at 23:00 on `start` with three
    /// working sets of 100 x 5 completed at `completions`.
    private func lateWorkout(startingAt start: Date, completedAt completions: [Date], in context: ModelContext) -> [SetEntry] {
        let session = Session()
        context.insert(session)
        session.startedAt = start
        session.completedAt = completions.max()
        session.routineSnapshotName = "Late Push"
        let exercise = SessionExercise()
        context.insert(exercise)
        exercise.session = session
        return completions.map { completedAt in
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = exercise
            set.weight = 100
            set.reps = 5
            set.setTypeRaw = SetType.working.rawValue
            set.isWarmup = false
            set.isComplete = true
            set.completedAt = completedAt
            return set
        }
    }

    @Test(
        "A workout that starts on a week's last evening and finishes after midnight counts in one week, on its bar and in its detail",
        arguments: [true, false]
    )
    func workoutAcrossMidnightCountsInOneWeek(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        // The last evening of a week: Sunday 3 May 2026 when weeks start on
        // Monday, Saturday 2 May when they start on Sunday.
        let lastEvening = Self.date(2026, 5, weekStartsMonday ? 3 : 2, hour: 23)
        let afterMidnight = [70.0, 73, 76].map { lastEvening.addingTimeInterval($0 * 60) }
        let sets = lateWorkout(startingAt: lastEvening, completedAt: afterMidnight, in: context)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: sets,
            weekStartsMonday: weekStartsMonday,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )
        let bar = try #require(bars.first)
        #expect(bars.count == 1)
        #expect(bar.weekStart == Self.date(2026, 5, weekStartsMonday ? 4 : 3), "The bar counts the sets in the new week")

        let detail = WeekDetailGrouping.workouts(counting: sets, inWeekStarting: bar.weekStart, weekStartsMonday: weekStartsMonday)
        #expect(detail.map(\.name) == ["Late Push"], "The bar's week must list the workout whose sets it counts")
        #expect(detail.map(\.tonnage).reduce(0, +) == bar.totalTonnage, "The week detail must total the bar")
        let weekBefore = try #require(Self.local.date(byAdding: .day, value: -7, to: bar.weekStart))
        let before = WeekDetailGrouping.workouts(counting: sets, inWeekStarting: weekBefore, weekStartsMonday: weekStartsMonday)
        #expect(before.isEmpty, "The week the workout started in has no bar for it, so its detail must not list it")
    }

    @Test("A workout split by midnight at a week's end counts each set in the week it was completed in", arguments: [true, false])
    func workoutSplitAtMidnightCountsEachPartInItsWeek(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        let lastEvening = Self.date(2026, 5, weekStartsMonday ? 3 : 2, hour: 23)
        let completions = [40.0, 70, 73].map { lastEvening.addingTimeInterval($0 * 60) }
        let sets = lateWorkout(startingAt: lastEvening, completedAt: completions, in: context)

        let bars = WeeklyTonnageAggregator.aggregate(
            sets: sets,
            weekStartsMonday: weekStartsMonday,
            selectedMuscleIDs: [],
            provider: UnweightedMuscleVolumeProvider()
        )
        #expect(bars.map(\.totalTonnage) == [500, 1000])
        for bar in bars {
            let detail = WeekDetailGrouping.workouts(counting: sets, inWeekStarting: bar.weekStart, weekStartsMonday: weekStartsMonday)
            #expect(detail.map(\.name) == ["Late Push"], "The week of \(bar.weekStart) must list the workout")
            #expect(detail.map(\.tonnage).reduce(0, +) == bar.totalTonnage, "The week of \(bar.weekStart) must total its bar")
        }
    }

    // MARK: - The chart works out its own weeks (T104)

    @Test("Swift Charts gets plain dates: no week value names a unit or a calendar to bin by")
    func chartHandsSwiftChartsPlainDates() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("fitbod/Progress/WeeklyTonnageView.swift"),
            encoding: .utf8
        )
        let plottedValues = source.components(separatedBy: "\n").filter { $0.contains(".value(") }
        #expect(plottedValues.contains { $0.contains("barSpan") || $0.contains("span.lowerBound") }, "The bars must be drawn over their week spans")
        let binned = plottedValues.filter { $0.contains("unit:") || $0.contains("calendar:") }
        #expect(binned.isEmpty, "Swift Charts must not bin weeks itself, but these values ask it to:\n\(binned.joined(separator: "\n"))")
        #expect(!source.contains(".stride(by: .weekOfYear)"), "The x axis marks the device calendar's weeks")
    }

    @Test("Each bar is drawn inside its own week, with a gap to the next", arguments: [true, false])
    func barsSitInsideTheirWeeks(weekStartsMonday: Bool) throws {
        let context = try makeContext()
        let calendar = WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday)
        // Ten weeks of Sunday and Wednesday workouts, across the end of
        // daylight saving time on 1 November 2026.
        let firstSunday = Self.date(2026, 9, 6, hour: 9)
        let days = try (0..<10).flatMap { week -> [Date] in
            let sunday = try #require(Self.local.date(byAdding: .day, value: 7 * week, to: firstSunday))
            return [sunday, try #require(Self.local.date(byAdding: .hour, value: 81, to: sunday))]
        }
        let bars = bars(loggedAt: days, weekStartsMonday: weekStartsMonday, in: context)
        let spans = bars.map { WeeklyTonnageChartWeeks.barSpan(of: $0.weekStart, calendar: calendar) }
        for (bar, span) in zip(bars, spans) {
            let week = try #require(calendar.dateInterval(of: .weekOfYear, for: bar.weekStart))
            #expect(week.start == bar.weekStart)
            #expect(span.lowerBound > week.start && span.upperBound < week.end, "The bar of \(bar.weekStart) leaves its week: \(span)")
            #expect(calendar.dateInterval(of: .weekOfYear, for: span.lowerBound)?.start == bar.weekStart)
        }
        for (earlier, later) in zip(spans, spans.dropFirst()) {
            #expect(earlier.upperBound < later.lowerBound, "Two bars touch: \(earlier) and \(later)")
        }
    }

    @Test("The chart's values are finite and its bar ids the same on every build")
    func chartValuesAreFiniteAndStable() throws {
        let context = try makeContext()
        // Sets completed at fractions of a second, as the clock logs them.
        let now = Self.wednesday.addingTimeInterval(0.123_456)
        let days = (0..<30).map { now.addingTimeInterval(-Double($0) * 86_400 * 1.3 - Double($0) * 0.017) }
        for weekStartsMonday in [true, false] {
            let first = bars(loggedAt: days, weekStartsMonday: weekStartsMonday, in: context)
            let second = bars(loggedAt: days, weekStartsMonday: weekStartsMonday, in: context)
            #expect(first.map(\.weekStart) == second.map(\.weekStart), "The bars' ids must not change between builds")
            #expect(Set(first.map(\.weekStart)).count == first.count, "Two bars share an id")

            // Two calendars made apart, as two renders make them.
            let calendars = [
                WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday),
                WeeklyTonnageChartWeeks.calendar(weekStartsMonday: weekStartsMonday),
            ]
            let plotted = [
                WeeklyTonnageChartWeeks.plotted(first, calendar: calendars[0]),
                WeeklyTonnageChartWeeks.plotted(second, calendar: calendars[1]),
            ]
            #expect(plotted[0].map(\.id) == plotted[1].map(\.id), "The plotted bars' ids must not change between renders")
            #expect(plotted[0].map(\.span) == plotted[1].map(\.span), "The bars' spans must not change between renders")
            let domains = calendars.map { WeeklyTonnageChartWeeks.domain(for: .last26wk, bars: first, now: now, calendar: $0) }
            #expect(domains[0] == domains[1])
            let weeks = WeeklyTonnageChartWeeks.weekStarts(in: domains[0], calendar: calendars[0])

            let values = plotted[0].map(\.bar.totalTonnage)
                + plotted[0].flatMap { [$0.span.lowerBound.timeIntervalSinceReferenceDate, $0.span.upperBound.timeIntervalSinceReferenceDate] }
                + weeks.map(\.timeIntervalSinceReferenceDate)
                + [domains[0].lowerBound.timeIntervalSinceReferenceDate, domains[0].upperBound.timeIntervalSinceReferenceDate]
            let nonFinite = values.filter { !$0.isFinite }
            #expect(nonFinite.isEmpty, "Every value the chart plots must be finite, not \(nonFinite)")
            for week in plotted[0] {
                #expect(weeks.contains(week.id), "The bar of \(week.id) starts off the axis's weeks")
            }
        }
    }

    @Test("A muscle-stacked bar's slices sit one on another, in their order")
    func stackedSlicesSitOneOnAnother() {
        let slices = [
            MuscleSlice(muscleID: UUID(), muscleName: "Chest", tonnage: 900),
            MuscleSlice(muscleID: UUID(), muscleName: "Triceps", tonnage: 450),
            MuscleSlice(muscleID: UUID(), muscleName: "Shoulders", tonnage: 150),
        ]
        let stacked = WeeklyTonnageChartWeeks.stacked(slices)
        #expect(stacked.map(\.slice.muscleName) == ["Chest", "Triceps", "Shoulders"])
        #expect(stacked.map(\.base) == [0, 900, 1350])
        #expect(Set(stacked.map(\.id)).count == slices.count)
    }
}
