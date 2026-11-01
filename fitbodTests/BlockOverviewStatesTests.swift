//
//  BlockOverviewStatesTests.swift
//  fitbodTests
//
//  Ticket T12, review items 28 and 25: the rules behind the block
//  overview's states. A completed block shows each phase as DONE, CUT SHORT
//  or NOT REACHED from the day it ended, and a session as Completed only
//  when a logged workout of that session exists. An active block's week
//  strip shows NEXT on the next training day only.
//

import Foundation
import Testing
@testable import fitbod

@Suite("BlockOverviewStates")
struct BlockOverviewStatesTests {

    /// Monday, Oct 26, 2026, 00:00 UTC.
    private static let monday = Date(timeIntervalSinceReferenceDate: 814_665_600)

    // MARK: - Completed phase states

    struct PhaseEnding: Sendable, CustomTestStringConvertible {
        let day: Int
        let states: [CompletedPhaseState]
        var testDescription: String { "ended on day \(day)" }
    }

    /// Accumulation 2 weeks (days 0 to 13), intensification 1 week (days 14
    /// to 20) and deload 1 week (days 21 to 27).
    @Test("a completed block's phases are DONE, CUT SHORT or NOT REACHED by the day it ended", arguments: [
        PhaseEnding(day: 3, states: [.cutShort(week: 1), .notReached, .notReached]),
        PhaseEnding(day: 12, states: [.cutShort(week: 2), .notReached, .notReached]),
        PhaseEnding(day: 13, states: [.done, .notReached, .notReached]),
        PhaseEnding(day: 14, states: [.done, .cutShort(week: 1), .notReached]),
        PhaseEnding(day: 27, states: [.done, .done, .done]),
        PhaseEnding(day: 40, states: [.done, .done, .done]),
    ])
    func completedPhaseStates(_ ending: PhaseEnding) {
        // Midday, so the end falls inside its day. Days count in UTC, where
        // the fixture's Monday starts.
        let endedAt = Self.monday.addingTimeInterval((Double(ending.day) + 0.5) * 86_400)
        let states = CompletedPhaseState.states(
            phaseWeeks: [2, 1, 1], startedAt: Self.monday, endedAt: endedAt, calendar: Self.utc
        )
        #expect(states == ending.states)
    }

    // MARK: - Next training day

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// Monday to Sunday, with Wednesday noon as today.
    private static let week = (0..<7).map { monday.addingTimeInterval(Double($0) * 86_400) }
    private static let wednesdayNoon = monday.addingTimeInterval(2.5 * 86_400)

    @MainActor
    @Test("on rotation every day trains, so tomorrow is the next training day")
    func rotationTrainsTomorrow() {
        let next = BlockOverviewScreen.nextTrainingDay(
            after: Self.wednesdayNoon, in: Self.week, mode: .rotation, trainingDays: [], calendar: Self.utc
        )
        #expect(next == Self.week[3])
    }

    @MainActor
    @Test("on fixed weekly the next training day is this week's next training weekday, if any")
    func fixedWeeklyTrainsOnItsDays() {
        // Calendar weekdays: 2 is Monday, 4 Wednesday and 6 Friday.
        let friday = BlockOverviewScreen.nextTrainingDay(
            after: Self.wednesdayNoon, in: Self.week, mode: .fixedWeekly, trainingDays: [2, 4, 6], calendar: Self.utc
        )
        #expect(friday == Self.week[4])
        let none = BlockOverviewScreen.nextTrainingDay(
            after: Self.wednesdayNoon, in: Self.week, mode: .fixedWeekly, trainingDays: [2, 4], calendar: Self.utc
        )
        #expect(none == nil)
    }

    // MARK: - Logged sessions

    @MainActor
    @Test("a session is Completed only by a logged workout of its name, one workout each")
    func loggedSessionsNeedAWorkoutEach() {
        let sessions = ["Upper A", "Upper B", "Upper A"]
        #expect(BlockOverviewScreen.loggedSessions(sessions, workoutNames: ["Upper A", "Lower A"]) == [true, false, false])
        #expect(BlockOverviewScreen.loggedSessions(sessions, workoutNames: ["Upper A", "Upper B", "Upper A"]) == [true, true, true])
        #expect(BlockOverviewScreen.loggedSessions(sessions, workoutNames: []) == [false, false, false])
    }
}
