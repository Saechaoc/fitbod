//
//  TodayWeekTests.swift
//  fitbodTests
//
//  Today's week board (RM-010): seven days from the week start, each with
//  that day's counted workouts and their working sets. Open and empty
//  workouts, warm-ups and incomplete sets never count, and workouts outside
//  the week stay out.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct TodayWeekTests {
    private let ctx: ModelContext
    private let bench: Exercise
    private let calendar: Calendar
    /// Monday 9 November 2026, local midnight.
    private let monday: Date

    init() throws {
        ctx = try LoggerFixtures.makeContext()
        bench = LoggerFixtures.exercise("Bench", in: ctx)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar = cal
        monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 9))!
    }

    private func at(day: Int, hour: Int) -> Date {
        calendar.date(byAdding: DateComponents(day: day, hour: hour), to: monday)!
    }

    @discardableResult
    private func workout(day: Int, hour: Int = 9, name: String, sets: [Bool], finished: Bool = true) throws -> Session {
        let start = at(day: day, hour: hour)
        let session = try LoggerFixtures.session(
            exercise: bench, startedAt: start, completedAt: finished ? start.addingTimeInterval(3_600) : nil,
            sets: sets.map { (weight: 100, reps: 5, complete: $0) }, in: ctx)
        session.templateName = name
        try ctx.save()
        return session
    }

    private func week(now: Date) throws -> TodayWeek {
        TodayWeek.make(finished: try ctx.fetch(FetchDescriptor<Session>()), weekStart: monday, now: now, calendar: calendar)
    }

    @Test("days run Monday to Sunday with finished workouts, their working sets and the week's totals")
    func countsFinishedWorkoutsByDay() throws {
        try workout(day: 0, name: "Push", sets: [true, true, true])
        try workout(day: 1, name: "Legs", sets: [true, true, false])
        let week = try week(now: at(day: 2, hour: 8))

        #expect(week.days.map(\.label) == ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"])
        #expect(week.days.map(\.workoutName) == ["Push", "Legs", nil, nil, nil, nil, nil])
        #expect(week.days.map(\.workingSets) == [3, 2, 0, 0, 0, 0, 0])
        #expect(week.days.map(\.isToday) == [false, false, true, false, false, false, false])
        #expect(week.workingSets == 5 && week.workouts == 2)
        #expect(week.rangeLabel == "NOV 9–15")
    }

    @Test("open and empty workouts, warm-ups and other weeks never count")
    func excludesWhatVolumeExcludes() throws {
        try workout(day: 2, name: "Pull", sets: [true, true], finished: false)
        try workout(day: 1, name: "Empty", sets: [false])
        let warm = try workout(day: 0, name: "Push", sets: [true, true])
        let first = try #require(warm.exercises?.first?.sets?.min { $0.orderIndex < $1.orderIndex })
        first.isWarmup = true
        try workout(day: -1, name: "Last week", sets: [true])
        try workout(day: 7, name: "Next week", sets: [true])
        try ctx.save()

        let week = try week(now: at(day: 2, hour: 12))
        #expect(week.days.map(\.workoutName) == ["Push", nil, nil, nil, nil, nil, nil])
        #expect(week.workingSets == 1 && week.workouts == 1)
    }

    @Test("two workouts on one day sum their sets and show the newest name")
    func sameDayWorkouts() throws {
        try workout(day: 3, hour: 7, name: "Push", sets: [true, true])
        try workout(day: 3, hour: 18, name: "Arms", sets: [true])
        let day = try week(now: at(day: 3, hour: 20)).days[3]
        #expect(day.workoutName == "Arms" && day.workouts == 2 && day.workingSets == 3)
    }

    @Test("a week across a month boundary names both months")
    func rangeAcrossMonths() throws {
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let week = TodayWeek.make(finished: [], weekStart: start, now: start, calendar: calendar)
        #expect(week.rangeLabel == "OCT 26–NOV 1")
    }

    @Test("today's tile notes a rest day and an open workout")
    func todayNotes() throws {
        let block = Block()
        ctx.insert(block)
        let open = try workout(day: 2, name: "Pull", sets: [true], finished: false)
        #expect(TodayView.todayNote(.rest(block)) == "Rest" && TodayView.isRestDay(.rest(block)))
        #expect(TodayView.todayNote(.resume(open)) == "Live" && !TodayView.isRestDay(.resume(open)))
        #expect(TodayView.todayNote(.first) == nil && !TodayView.isRestDay(.first))
    }
}
