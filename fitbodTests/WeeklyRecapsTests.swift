//
//  WeeklyRecapsTests.swift
//  fitbodTests
//
//  RM-020: past weekly recaps. The week list holds every past week with a
//  workout that counts as a session, newest first, and a row shows the
//  numbers its recap shows. Both read the sets as they are now, so a History
//  correction moves the week it touches. The records are History's, and a
//  Progress row's e1RM change is labelled in the exercise's own unit.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// @MainActor because each fixture's context is the main actor's, as a
// view's is. Each test builds its own in-memory container on a pinned
// calendar.
@MainActor
@Suite("Weekly recaps")
struct WeeklyRecapsTests {

    /// Monday weeks in GMT, so the weeks do not depend on the phone's region.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Wednesday 11 November 2026, in the week of Monday 9 November.
    private var now: Date { day(11, month: 11, hour: 12) }

    // MARK: - The week list

    @Test("Every past week with a counted workout has a row, newest first, with its recap's numbers")
    func weekListReadsEachPastWeek() throws {
        let fixture = try Fixture(calendar: calendar)
        try fixture.seedThreeWeeks(day: day)

        let weeks = fixture.weeks(now: now)

        // Week of 26 October holds only an empty workout; this week's is not over.
        #expect(weeks.map(\.weekStart) == [day(2, month: 11), day(19, month: 10)])
        let november = try #require(weeks.first)
        #expect(november.sessions == 1)
        #expect(november.workingSets == 4)
        #expect(november.tonnage == 2_000)
        #expect(november.averageRPE == nil)
        #expect(november.underTrained == ["triceps": 4])
        #expect(november.records == 4)

        let october = try #require(weeks.last)
        #expect(october.sessions == 2)
        #expect(october.target == nil)
        #expect(october.workingSets == 6)
        #expect(october.tonnage == 3_037.5)
        #expect(october.averageRPE == 8.25)
        // Chest has 6 direct sets of its 8, triceps 6 × 0.3 indirect of its 6.
        #expect(october.underTrained == ["chest": 6, "triceps": 2])
        // Monday's first bench set sets all four records; Thursday's heavier
        // first set beats weight, volume and e1RM, at the same reps.
        #expect(october.records == 7)
    }

    @Test("A row shows the numbers its recap shows, and History's count of records")
    func rowsMatchTheirRecaps() throws {
        let fixture = try Fixture(calendar: calendar)
        try fixture.seedThreeWeeks(day: day)

        for week in fixture.weeks(now: now) {
            let recap = fixture.content(coveringWeekStarting: week.weekStart).recap
            #expect(recap == week)
            let history = SessionSummary.prsBySession(try fixture.sessions())
            let weekEnd = FatigueModel.date(byAddingWeeks: 1, to: week.weekStart, calendar: calendar)
            let historyCount = try fixture.sessions()
                .filter { $0.startedAt >= week.weekStart && $0.startedAt < weekEnd }
                .reduce(0) { $0 + (history[$1.id]?.count ?? 0) }
            #expect(week.records == historyCount)
        }
    }

    @Test("The recap lists each record its count holds")
    func recapListsItsRecords() throws {
        let fixture = try Fixture(calendar: calendar)
        try fixture.seedThreeWeeks(day: day)

        let content = fixture.content(coveringWeekStarting: day(19, month: 10))
        #expect(content.records.count == content.recap.records)
        #expect(content.records.map(\.kindLabel) == [
            "Weight PR", "Rep PR", "Volume PR", "e1RM PR",
            "Weight PR", "Volume PR", "e1RM PR",
        ])
        // Thursday's records hold its heaviest set; volume is that one set's.
        #expect(content.records[4].value == "102.5 lb")
        #expect(content.records[5].value == "513 lb")
    }

    // MARK: - History corrections

    @Test("A corrected set changes its past week in the list and in its recap")
    func correctedSetUpdatesItsWeek() async throws {
        let fixture = try Fixture(calendar: calendar)
        let workouts = try fixture.seedThreeWeeks(day: day)
        let thursday = workouts.thursday
        let bench = try #require(thursday.exercises?.first)
        let set = try #require(SessionSetActions.ordered(bench).first)

        var edit = WorkoutEdit(startedAt: thursday.startedAt)
        edit.changed[set.id] = .init(weight: 110, reps: 5, rpe: 8.5)
        try SessionEditService.save(edit, to: thursday, now: now, context: fixture.context)

        let october = try #require(fixture.weeks(now: now).last)
        #expect(october.tonnage == 3_075)
        #expect(fixture.content(coveringWeekStarting: day(19, month: 10)).recap == october)
        // The list reads the saved correction off the main actor too.
        let read = await WeeklyRecaps.weeks(
            weekStartsMonday: true, now: now, in: fixture.context.container, calendar: calendar
        )
        #expect(read.last == october)
    }

    @Test("A workout moved to another week leaves its old week and joins the new one")
    func movedWorkoutChangesWeeks() throws {
        let fixture = try Fixture(calendar: calendar)
        let workouts = try fixture.seedThreeWeeks(day: day)

        // The November pushdowns move to Tuesday 20 October.
        try SessionEditService.save(
            WorkoutEdit(startedAt: day(20, month: 10, hour: 18)), to: workouts.pushdowns, now: now, context: fixture.context
        )

        let weeks = fixture.weeks(now: now)
        #expect(weeks.map(\.weekStart) == [day(19, month: 10)])
        #expect(weeks.first?.sessions == 3)
        #expect(weeks.first?.tonnage == 5_037.5)
    }

    // MARK: - Off the main actor

    @Test("The list and a recap read off the main actor match the main context's reads")
    func offMainReadsMatch() async throws {
        let fixture = try Fixture(calendar: calendar)
        try fixture.seedThreeWeeks(day: day)
        let container = fixture.context.container

        let weeks = await WeeklyRecaps.weeks(weekStartsMonday: true, now: now, in: container, calendar: calendar)
        #expect(weeks == fixture.weeks(now: now))

        let october = day(19, month: 10)
        let content = await WeeklyRecaps.content(
            weekStart: FatigueModel.date(byAddingWeeks: 1, to: october, calendar: calendar),
            minSets: 2,
            unit: .lb,
            in: container,
            calendar: calendar
        )
        let onMain = fixture.content(coveringWeekStarting: october)
        #expect(content.recap == onMain.recap)
        #expect(content.records.map(\.value) == onMain.records.map(\.value))
        #expect(content.muscles == 2)
    }

    // MARK: - Units

    @Test("A Progress row's e1RM change reads in the exercise's own unit")
    func progressRowUsesTheExerciseUnit() throws {
        let fixture = try Fixture(calendar: calendar)
        let bench = fixture.exercise("Bench", working: [(fixture.chest, "primary", 1)])
        bench.unitOverride = .kg
        try fixture.workout(bench, sets: [(100, 5, 8)], at: day(13, month: 10, hour: 18))
        try fixture.workout(bench, sets: [(102.5, 5, 8)], at: day(20, month: 10, hour: 18))

        let content = fixture.content(coveringWeekStarting: day(19, month: 10), unit: .lb)
        #expect(content.progress.map(\.deltaCopy) == ["+2.8 kg e1RM"])
        #expect(content.records.allSatisfy { $0.value.hasSuffix(" kg") })
    }

    // MARK: - Week numbers and the eight weeks

    @Test("A week's number is its ISO week, read on its last day", arguments: [
        // Monday weeks: 19 to 25 October 2026 is week 43.
        (2026, 10, 19, 43),
        // A Sunday week, 18 to 24 October, is week 43 for its six weekdays.
        (2026, 10, 18, 43),
        // 28 December 2026 to 3 January 2027 is 2026's week 53.
        (2026, 12, 28, 53),
        (2026, 12, 27, 53),
    ])
    func weekNumberReadsTheLastDay(year: Int, month: Int, day: Int, number: Int) throws {
        let start = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        #expect(WeeklyRecapSheet.weekNumber(ofWeekStarting: start, calendar: calendar) == number)
    }

    @Test("The eight weeks before this one read empty where no recap is, and compare the last two")
    func lastEightWeeksFillGaps() throws {
        let fixture = try Fixture(calendar: calendar)
        try fixture.seedThreeWeeks(day: day)
        let thisWeek = day(9, month: 11)

        let recent = WeeklyRecapsView.lastEightWeeks(fixture.weeks(now: now), before: thisWeek, calendar: calendar)

        #expect(recent.map(\.weekStart) == (1...8).reversed().map {
            FatigueModel.date(byAddingWeeks: -$0, to: thisWeek, calendar: calendar)
        })
        #expect(recent.map(\.tonnage) == [0, 0, 0, 0, 0, 3_037.5, 0, 2_000])
        // The week before last had nothing to compare with.
        #expect(WeeklyRecapsView.deltaPct(recent) == nil)
        #expect(WeeklyRecapsView.deltaPct(Array(recent.prefix(6))) == nil)
    }

    // MARK: - Fixtures

    private func day(_ day: Int, month: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @MainActor
    private struct Fixture {
        let context: ModelContext
        let calendar: Calendar
        let chest: MuscleGroup
        let triceps: MuscleGroup
        let muscles: [MuscleGroup]
        let targets: [MuscleVolumeTarget]

        init(calendar: Calendar) throws {
            context = ModelContext(try FitbodModelContainer.make(inMemory: true))
            self.calendar = calendar
            chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
            triceps = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
            context.insert(chest)
            context.insert(triceps)
            var targets: [MuscleVolumeTarget] = []
            for (muscle, mev) in [(chest, 8), (triceps, 6)] {
                let target = MuscleVolumeTarget()
                context.insert(target)
                target.muscle = muscle
                target.mev = mev
                targets.append(target)
            }
            muscles = [chest, triceps]
            self.targets = targets
        }

        /// Bench (chest, and triceps at 0.3) on Monday 19 and Thursday 22
        /// October, an empty workout on Wednesday 28 October, pushdowns on
        /// Tuesday 3 November with no RPE, and bench again this week.
        @discardableResult
        func seedThreeWeeks(day: (Int, Int, Int) -> Date) throws -> (thursday: Session, pushdowns: Session) {
            let bench = exercise("Bench", working: [(chest, "primary", 1), (triceps, "secondary", 0.3)])
            let pushdown = exercise("Pushdown", working: [(triceps, "primary", 1)])
            try workout(bench, sets: Array(repeating: (100, 5, 8), count: 3), at: day(19, 10, 18))
            let thursday = try workout(bench, sets: Array(repeating: (102.5, 5, 8.5), count: 3), at: day(22, 10, 18))
            try workout(pushdown, sets: [], at: day(28, 10, 18))
            let pushdowns = try workout(pushdown, sets: Array(repeating: (50, 10, nil), count: 4), at: day(3, 11, 18))
            try workout(bench, sets: [(105, 5, 8)], at: day(10, 11, 18))
            return (thursday, pushdowns)
        }

        func exercise(_ name: String, working stimuli: [(MuscleGroup, String, Double)]) -> Exercise {
            let exercise = Exercise()
            context.insert(exercise)
            exercise.name = name
            for (muscle, role, weight) in stimuli {
                let stimulus = ExerciseMuscleStimulus()
                context.insert(stimulus)
                stimulus.role = role
                stimulus.weight = weight
                stimulus.muscle = muscle
                stimulus.exercise = exercise
            }
            return exercise
        }

        /// A finished strength workout of `exercise`, an hour long; no sets
        /// make it empty.
        @discardableResult
        func workout(
            _ exercise: Exercise,
            sets: [(weight: Double, reps: Int, rpe: Double?)],
            at start: Date
        ) throws -> Session {
            let session = Session()
            context.insert(session)
            session.startedAt = start
            session.completedAt = start.addingTimeInterval(3_600)
            session.intentRaw = Intent.strength.rawValue
            session.routineSnapshotName = exercise.name
            let log = SessionExercise()
            context.insert(log)
            log.session = session
            log.exercise = exercise
            log.exerciseNameSnapshot = exercise.name
            for (index, values) in sets.enumerated() {
                let set = SetEntry()
                context.insert(set)
                set.sessionExercise = log
                set.orderIndex = index
                set.weight = values.weight
                set.reps = values.reps
                set.rpe = values.rpe
                set.isWarmup = false
                set.setTypeRaw = SetType.working.rawValue
                set.isComplete = true
                set.completedAt = start.addingTimeInterval(Double(index + 1) * 180)
            }
            try context.save()
            return session
        }

        func sessions() throws -> [Session] {
            try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
        }

        func weeks(now: Date) -> [WeekRecap] {
            WeeklyRecaps.weeks(
                sessions: (try? sessions()) ?? [],
                muscles: muscles,
                targets: targets,
                weekStartsMonday: true,
                now: now,
                in: context,
                calendar: calendar
            )
        }

        /// The recap of the week that starts at `start`, as a row reopens it.
        func content(coveringWeekStarting start: Date, unit: WeightUnit = .lb) -> WeeklyRecapSheet.Content {
            WeeklyRecapSheet.content(
                weekStart: FatigueModel.date(byAddingWeeks: 1, to: start, calendar: calendar),
                muscles: muscles,
                targets: targets,
                minSets: 2,
                unit: unit,
                in: context,
                calendar: calendar
            )
        }
    }
}
