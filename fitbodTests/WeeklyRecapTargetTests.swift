//
//  WeeklyRecapTargetTests.swift
//  fitbodTests
//
//  T114, finding F242. The weekly recap's sessions target was the number
//  of sessions logged, so its chip read "N / N sessions" and its headline
//  always read "A strong week.". The target is now the training days the
//  blocks that ran last week planned for it (tradeoffs, "Weekly recap
//  target"): the days a fixed weekly block trains on, while it ran, each
//  day once. Rotation plans no weekdays, so it sets no target, and nor
//  does a week without a block; then the chip reads "N sessions" and the
//  headline follows the sessions and PRs alone.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// @MainActor because WeeklyRecapSheet is a view, so its rules run on the
// main actor, and sessionsTarget reads the store there as the sheet does.
// Each test builds its own in-memory container.
@MainActor
@Suite("Weekly recap target")
struct WeeklyRecapTargetTests {

    /// Calendar weekdays, 1 = Sunday.
    private static let monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7

    /// Pinned, so the weekdays do not depend on the phone's region.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    // MARK: - Repro (F242)

    @Test("A block that planned four training days last week sets the target to 4, and one workout is no strong week")
    func fourPlannedDaysAreTheTarget() throws {
        let context = try makeContext()
        try insertBlock(trainingDays: [Self.monday, Self.tuesday, Self.thursday, Self.friday],
                        started: lastWeek(day: -7), in: context)
        try insertFinishedWorkout(startedAt: lastWeek(day: 1, hour: 18), in: context)

        let target = try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar)
        #expect(target == 4)
        #expect(WeeklyRecapSheet.sessionsChipLabel(sessions: 1, target: target) == "1 / 4 sessions")
        let headline = oneLine(WeeklyRecapSheet.coverHeadline(sessions: 1, target: target, prs: 0))
        #expect(headline != "A strong week.")
        #expect(headline == "Light week.")
    }

    @Test("With no block last week the chip reads 1 session and names no target")
    func noBlockNamesNoTarget() throws {
        let context = try makeContext()
        try insertFinishedWorkout(startedAt: lastWeek(day: 1, hour: 18), in: context)

        let target = try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar)
        #expect(target == nil)
        #expect(WeeklyRecapSheet.sessionsChipLabel(sessions: 1, target: target) == "1 session")
        #expect(oneLine(WeeklyRecapSheet.coverHeadline(sessions: 1, target: target, prs: 0)) == "Light week.")
    }

    // MARK: - What a plan counts

    @Test("A block started midweek plans only its days after the start")
    func midweekStartCountsItsOwnDays() throws {
        let context = try makeContext()
        // Started on Wednesday morning, after Monday and Tuesday.
        try insertBlock(trainingDays: [Self.monday, Self.tuesday, Self.thursday, Self.friday],
                        started: lastWeek(day: 2, hour: 9), in: context)

        #expect(try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar) == 2)
    }

    @Test("A midweek swap counts each block's days while it ran, and a day both ran on once")
    func midweekSwapCountsADayOnce() throws {
        let context = try makeContext()
        let swap = try lastWeek(day: 2, hour: 18)
        // Monday, Wednesday and Friday until Wednesday evening's swap.
        try insertBlock(trainingDays: [Self.monday, Self.wednesday, Self.friday],
                        started: lastWeek(day: -14), ended: swap, in: context)
        // Wednesday and Saturday from the swap on.
        insertBlock(trainingDays: [Self.wednesday, Self.saturday], started: swap, in: context)

        // Monday, Wednesday once, and Saturday; Friday came after the
        // first block ended.
        #expect(try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar) == 3)
    }

    @Test("A rotation block plans no weekdays, even with days kept from fixed weekly")
    func rotationSetsNoTarget() throws {
        let context = try makeContext()
        try insertBlock(.rotation, trainingDays: [Self.monday, Self.tuesday, Self.thursday, Self.friday],
                        started: lastWeek(day: -7), in: context)

        #expect(try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar) == nil)
    }

    /// A fixed weekly block that did not run last week.
    enum IdleBlock: String, CaseIterable, Sendable {
        /// Saved ready to start on Monday, but never started.
        case neverStarted
        /// Ended the moment last week began.
        case endedBefore
        /// Started the moment this week began.
        case startedAfter
    }

    @Test("A block that did not run last week plans nothing", arguments: IdleBlock.allCases)
    func idleBlockSetsNoTarget(_ idle: IdleBlock) throws {
        let context = try makeContext()
        let days = [Self.monday, Self.tuesday, Self.thursday, Self.friday]
        switch idle {
        case .neverStarted:
            let block = try insertBlock(trainingDays: days, started: lastWeek(day: 0), in: context)
            block.isActive = false
        case .endedBefore:
            try insertBlock(trainingDays: days, started: lastWeek(day: -14), ended: lastWeek(day: 0), in: context)
        case .startedAfter:
            try insertBlock(trainingDays: days, started: thisWeek(), in: context)
        }

        #expect(try WeeklyRecapSheet.sessionsTarget(weekStart: thisWeek(), in: context, calendar: calendar) == nil)
    }

    // MARK: - Headline without a target

    @Test("With no target the headline follows the sessions and PRs alone", arguments: [
        (1, 0, "Light week."),
        (6, 0, "Solid week."),
        (1, 3, "A strong week."),
    ])
    func headlineWithoutTarget(sessions: Int, prs: Int, headline: String) {
        #expect(oneLine(WeeklyRecapSheet.coverHeadline(sessions: sessions, target: nil, prs: prs)) == headline)
    }

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        ModelContext(try FitbodModelContainer.make(inMemory: true))
    }

    /// Midnight on Monday 26 October 2026, when the recap opens. It covers
    /// the week before, Monday 19 to Sunday 25 October.
    private func thisWeek() throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)))
    }

    /// `hour` o'clock on day `day` of last week: 0 is its Monday, 7 this
    /// Monday, and -7 the Monday before.
    private func lastWeek(day: Int, hour: Int = 0) throws -> Date {
        let midnight = try #require(calendar.date(byAdding: .day, value: day - 7, to: thisWeek()))
        return try #require(calendar.date(byAdding: .hour, value: hour, to: midnight))
    }

    /// A block that ran from `started` until `ended`, or still runs when
    /// `ended` is nil: the fields BlockLifecycleService.start and end set.
    @discardableResult
    private func insertBlock(
        _ mode: SchedulingMode = .fixedWeekly,
        trainingDays: [Int],
        started: Date,
        ended: Date? = nil,
        in context: ModelContext
    ) -> Block {
        let block = Block()
        context.insert(block)
        block.schedulingMode = mode
        block.trainingDays = trainingDays
        block.startDate = started
        block.endDate = ended
        block.isActive = ended == nil
        return block
    }

    /// A finished workout with one logged work set, so it counts as a
    /// session (decision 6).
    private func insertFinishedWorkout(startedAt start: Date, in context: ModelContext) throws {
        let workout = Session()
        context.insert(workout)
        workout.startedAt = start
        workout.completedAt = start.addingTimeInterval(45 * 60)
        let exercise = SessionExercise()
        context.insert(exercise)
        exercise.session = workout
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = exercise
        set.weight = 100
        set.reps = 5
        set.isComplete = true
        try context.save()
    }

    /// The headline as one line: it breaks after its first word.
    private func oneLine(_ headline: String) -> String {
        headline.replacingOccurrences(of: "\n", with: " ")
    }
}
