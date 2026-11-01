//
//  WeekWindowCalendarTests.swift
//  fitbodTests
//
//  T139, findings F333 and F334. The weekly recap found last week by
//  taking 7 × 86,400 seconds off the new week's start, and the Fatigue
//  week, its week-over-week delta and the deload advisor's windows did
//  the same. A week that holds a daylight-saving change is an hour
//  shorter or longer than that, so after the spring change the recap's
//  week began at 23:00 the Sunday before and read "MAR 1 → MAR 8", and
//  after the autumn change it began at 01:00 and missed its Monday's first
//  hour. Week boundaries now come from the calendar: local midnight on
//  each week's first day. The recap's Muscles Hit rows with the same count
//  also go by muscle name, so they keep one order between launches.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// @MainActor because the recap's rules are members of a SwiftUI view, and
// FatigueModel and DeloadAdvisor read the store on the main actor. Each
// test builds its own in-memory container and calendar.
@MainActor
@Suite("Week windows follow the calendar")
struct WeekWindowCalendarTests {

    // MARK: - Repro (F333): the recap's last week

    /// A new week that starts just after a daylight-saving change, under
    /// one week start setting, and the week before it that its recap covers.
    struct NewWeek: Sendable, CustomTestStringConvertible {
        let testDescription: String
        /// The new week's first day, when the recap opens.
        let starts: DateComponents
        /// Last week's first day.
        let lastWeekStarts: DateComponents
        let caption: String

        static let all = [
            NewWeek(testDescription: "Monday weeks, after the spring change",
                    starts: DateComponents(year: 2026, month: 3, day: 9),
                    lastWeekStarts: DateComponents(year: 2026, month: 3, day: 2),
                    caption: "MAR 2 → MAR 8"),
            NewWeek(testDescription: "Sunday weeks, after the spring change",
                    starts: DateComponents(year: 2026, month: 3, day: 15),
                    lastWeekStarts: DateComponents(year: 2026, month: 3, day: 8),
                    caption: "MAR 8 → MAR 14"),
            NewWeek(testDescription: "Monday weeks, after the autumn change",
                    starts: DateComponents(year: 2026, month: 11, day: 2),
                    lastWeekStarts: DateComponents(year: 2026, month: 10, day: 26),
                    caption: "OCT 26 → NOV 1"),
            NewWeek(testDescription: "Sunday weeks, after the autumn change",
                    starts: DateComponents(year: 2026, month: 11, day: 8),
                    lastWeekStarts: DateComponents(year: 2026, month: 11, day: 1),
                    caption: "NOV 1 → NOV 7"),
        ]
    }

    @Test("The recap's last week starts at local midnight seven calendar days before the new week",
          arguments: NewWeek.all)
    func recapLastWeekStartsAtMidnight(_ week: NewWeek) throws {
        let calendar = try Self.pacific()
        let weekStart = try Self.date(week.starts, in: calendar)
        let lastWeekStart = try Self.date(week.lastWeekStarts, in: calendar)

        #expect(WeeklyRecapSheet.priorWeekStart(before: weekStart, calendar: calendar) == lastWeekStart)
        #expect(WeeklyRecapSheet.dateRangeCaption(weekStart: weekStart, calendar: calendar) == week.caption)
    }

    // MARK: - Repro (F334): Muscles Hit order

    @Test("Muscles Hit rows with the same count go by muscle name on every call")
    func musclesHitTiesGoByName() throws {
        let context = try makeContext()
        let calendar = try Self.pacific()
        // The recap opening Monday 19 October 2026 covers 12 to 18
        // October, a week with no clock change.
        let weekStart = try Self.date(DateComponents(year: 2026, month: 10, day: 19), in: calendar)
        let chest = muscle("chest", "Chest", in: context)
        let shoulders = muscle("shoulders", "Shoulders", in: context)
        let triceps = muscle("triceps", "Triceps", in: context)
        // Tuesday's workout hits all three; Thursday's hits triceps again.
        try workout(exercise(working: [chest, shoulders, triceps], in: context), sets: 2,
                    at: DateComponents(year: 2026, month: 10, day: 13, hour: 18), in: context, calendar: calendar)
        try workout(exercise(working: [triceps], in: context), sets: 2,
                    at: DateComponents(year: 2026, month: 10, day: 15, hour: 18), in: context, calendar: calendar)

        // The muscles come from a query in no set order.
        for muscles in [[chest, shoulders, triceps], [triceps, shoulders, chest]] {
            let rows = WeeklyRecapSheet.musclesHit(
                weekStart: weekStart, muscles: muscles, minSets: 2, in: context, calendar: calendar
            )
            #expect(rows.map { "\($0.displayName) \($0.count)" } == ["Triceps 2", "Chest 1", "Shoulders 1"])
        }
    }

    // MARK: - Fatigue weeks

    /// A set logged in the hour next to one end of a week that holds a
    /// daylight-saving change, and whether that week holds it.
    struct EdgeSet: Sendable, CustomTestStringConvertible {
        let testDescription: String
        /// The first day of the week that holds the clock change.
        let weekStarts: DateComponents
        let loggedAt: DateComponents
        let inWeek: Bool

        static let all = [
            // Monday 2 to Monday 9 March 2026 is 167 hours long.
            EdgeSet(testDescription: "Spring: the next Monday's first hour",
                    weekStarts: DateComponents(year: 2026, month: 3, day: 2),
                    loggedAt: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30),
                    inWeek: false),
            EdgeSet(testDescription: "Spring: the Sunday before, at 23:30",
                    weekStarts: DateComponents(year: 2026, month: 3, day: 2),
                    loggedAt: DateComponents(year: 2026, month: 3, day: 1, hour: 23, minute: 30),
                    inWeek: false),
            // Monday 26 October to Monday 2 November 2026 is 169 hours long.
            EdgeSet(testDescription: "Autumn: the Monday's first hour",
                    weekStarts: DateComponents(year: 2026, month: 10, day: 26),
                    loggedAt: DateComponents(year: 2026, month: 10, day: 26, hour: 0, minute: 30),
                    inWeek: true),
            EdgeSet(testDescription: "Autumn: the Sunday's last hour",
                    weekStarts: DateComponents(year: 2026, month: 10, day: 26),
                    loggedAt: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 30),
                    inWeek: true),
        ]
    }

    @Test("A Fatigue week runs midnight to midnight, and the next week reads it as last week",
          arguments: EdgeSet.all)
    func fatigueWeekRunsMidnightToMidnight(_ edge: EdgeSet) throws {
        let context = try makeContext()
        let calendar = try Self.pacific()
        try workout(exercise(working: [muscle("chest", "Chest", in: context)], in: context),
                    at: edge.loggedAt, in: context, calendar: calendar)
        let weekStart = try Self.date(edge.weekStarts, in: calendar)
        let nextWeekStart = try #require(calendar.date(byAdding: .day, value: 7, to: weekStart))
        let sets: Double = edge.inWeek ? 1 : 0

        let week = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: weekStart, in: context, calendar: calendar)
        #expect(week.totalSets == sets)
        let delta = FatigueModel.weekOverWeekDelta(
            muscleSlug: "chest", weekStart: nextWeekStart, in: context, calendar: calendar
        )
        #expect(delta.previousWeekTotal == sets)
    }

    // MARK: - Deload advisor windows

    @Test("The deload advisor's three weeks start at local midnight 21 days back", arguments: [false, true])
    func rpeCreepWindowStartsAtMidnight(firstWorkoutInside: Bool) throws {
        let context = try makeContext()
        let calendar = try Self.pacific()
        // Monday 9 March 2026, after the spring change: its three weeks
        // start at midnight on Monday 16 February.
        let weekStart = try Self.date(DateComponents(year: 2026, month: 3, day: 9), in: calendar)
        let bench = exercise(working: [muscle("chest", "Chest", in: context)], in: context)
        let first = firstWorkoutInside
            ? DateComponents(year: 2026, month: 2, day: 16, hour: 0, minute: 30)
            : DateComponents(year: 2026, month: 2, day: 15, hour: 23, minute: 30)
        // One load, its RPE up a whole point over three workouts.
        try workout(bench, rpe: 7, at: first, in: context, calendar: calendar)
        try workout(bench, rpe: 7.5, at: DateComponents(year: 2026, month: 2, day: 25, hour: 18),
                    in: context, calendar: calendar)
        try workout(bench, rpe: 8, at: DateComponents(year: 2026, month: 3, day: 4, hour: 18),
                    in: context, calendar: calendar)

        let report = DeloadAdvisor.signalReport(
            weekStart: weekStart, in: context, settings: settings(in: context), now: weekStart, calendar: calendar
        )
        #expect(report.sig2_rpeCreep == (firstWorkoutInside ? 1.0 : nil))
    }

    @Test("The deload advisor's six weeks start at local midnight 42 days back", arguments: [false, true])
    func e1RMDropWindowStartsAtMidnight(oldestWorkoutInside: Bool) throws {
        let context = try makeContext()
        let calendar = try Self.pacific()
        // Monday 9 March 2026: its six weeks start at midnight on Monday
        // 26 January.
        let weekStart = try Self.date(DateComponents(year: 2026, month: 3, day: 9), in: calendar)
        let bench = exercise(working: [muscle("chest", "Chest", in: context)], in: context)
        let oldest = oldestWorkoutInside
            ? DateComponents(year: 2026, month: 1, day: 26, hour: 0, minute: 30)
            : DateComponents(year: 2026, month: 1, day: 25, hour: 23, minute: 30)
        // Three workouts at 100, then three at 94: a 6% drop in top-set
        // e1RM, which takes all six.
        try workout(bench, weight: 100, at: oldest, in: context, calendar: calendar)
        for (month, day, weight) in [(2, 2, 100.0), (2, 9, 100.0), (2, 16, 94.0), (2, 23, 94.0), (3, 2, 94.0)] {
            try workout(bench, weight: weight, at: DateComponents(year: 2026, month: month, day: day, hour: 18),
                        in: context, calendar: calendar)
        }

        let report = DeloadAdvisor.signalReport(
            weekStart: weekStart, in: context, settings: settings(in: context), now: weekStart, calendar: calendar
        )
        if oldestWorkoutInside {
            let drop = try #require(report.sig1_e1RMDrop)
            #expect(abs(drop - 0.06) < 0.000_1)
        } else {
            #expect(report.sig1_e1RMDrop == nil)
        }
    }

    // MARK: - Fixtures

    /// Pacific time, whose clocks moved on Sunday 8 March 2026 and Sunday
    /// 1 November 2026, with a fixed locale so the caption's month names
    /// do not depend on the phone's region.
    private static func pacific() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static func date(_ components: DateComponents, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: components))
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try FitbodModelContainer.make(inMemory: true))
    }

    private func muscle(_ slug: String, _ name: String, in context: ModelContext) -> MuscleGroup {
        let muscle = MuscleGroup(slug: slug, displayName: name, region: .upper)
        context.insert(muscle)
        return muscle
    }

    /// An exercise each set of which puts one direct set on every one of
    /// `muscles`.
    private func exercise(working muscles: [MuscleGroup], in context: ModelContext) -> Exercise {
        let exercise = Exercise()
        context.insert(exercise)
        for muscle in muscles {
            let stimulus = ExerciseMuscleStimulus()
            context.insert(stimulus)
            stimulus.role = "primary"
            stimulus.weight = 1
            stimulus.muscle = muscle
            stimulus.exercise = exercise
        }
        return exercise
    }

    /// A finished strength workout, started at `components` in `calendar`,
    /// that logs `sets` work sets of `exercise`, each `weight` × 5 at `rpe`.
    private func workout(
        _ exercise: Exercise,
        sets: Int = 1,
        weight: Double = 100,
        rpe: Double? = nil,
        at components: DateComponents,
        in context: ModelContext,
        calendar: Calendar
    ) throws {
        let start = try Self.date(components, in: calendar)
        let workout = Session()
        context.insert(workout)
        workout.startedAt = start
        workout.completedAt = start.addingTimeInterval(45 * 60)
        let logged = SessionExercise()
        context.insert(logged)
        logged.session = workout
        logged.exercise = exercise
        for index in 0..<sets {
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = logged
            set.orderIndex = index
            set.weight = weight
            set.reps = 5
            set.rpe = rpe
            set.isComplete = true
        }
        try context.save()
    }

    private func settings(in context: ModelContext) -> UserSettings {
        let settings = UserSettings.default()
        context.insert(settings)
        return settings
    }
}
