import Foundation
import SwiftData
import Testing
@testable import fitbod

/// Program's This week (RM-015, O-9): each counted workout once, on the day it
/// started; the open workout read-only; TODAY ▸ and NEXT ▸ only in T-TODAY;
/// empty sessions repair. The week is Monday 13 to Sunday 19 November 2023,
/// and now is Tuesday evening.
@MainActor
@Suite("Program's This week")
struct ThisWeekTests: ProgramFixtures {
    let ctx: ModelContext
    let bench: Exercise
    let now = Self.tuesdayEvening
    let calendar = Self.utcCalendar

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Self.makeBench(in: ctx)
    }

    // MARK: - Weekday block

    @Test("T-TODAY: today's planned session starts; the others plan from the block's start day, or rest")
    func weekdayToday() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let block = weekly(routine, on: [2, 3, 5], startedDaysAgo: 0.5) // Monday, Tuesday, Thursday; started this morning

        let days = try groups(for: block)

        #expect(days.map(\.label) == (0..<7).map { ThisWeek.Label.day(monday + Double($0) * day) })
        #expect(days[0].rows == [.rest])                          // planned, but before the block started
        #expect(days[1].rows == [.planned(slots[1], .start)])     // today: TODAY ▸
        #expect(days[2].rows == [.rest])
        #expect(days[3].rows == [.planned(slots[2], .plain)])
        #expect(days[4...].allSatisfy { $0.rows == [.rest] })
    }

    @Test("Off-plan and two-workout days list every counted workout once, oldest first, on the day it started")
    func offPlanAndTwoWorkoutDays() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5]) // Tuesday, Thursday
        let arms = makeWorkout(in: nil, daysAgo: 1.2, block: block)          // off-plan, on Monday's rest day
        makeWorkout(in: nil, daysAgo: 1.1, block: block, logged: false)      // empty: not counted
        let pull = makeWorkout(in: slots[1], daysAgo: 1, block: block)       // Thursday's session, on Monday
        makeWorkout(in: slots[0], daysAgo: 7, block: block)                  // last week

        let days = try groups(for: block)

        #expect(days[0].rows == [.logged(arms), .logged(pull)])
        #expect(days[1].rows == [.planned(slots[0], .start)])                // Monday's workouts leave Today on T-TODAY
        #expect(days[3].rows == [.planned(slots[1], .plain)])                // Monday's Pull A does not hold Thursday
        #expect(days.flatMap(\.rows).filter { if case .logged = $0 { true } else { false } }.count == 2)
    }

    @Test("Week start setting: a Sunday-first week groups from Sunday")
    func sundayFirstWeek() throws {
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let block = weekly(routine, on: [3])
        let sunday = makeWorkout(in: nil, daysAgo: 2, block: block)

        let days = try groups(for: block, weekStartsMonday: false)

        #expect(days[0].label == .day(monday - day))
        #expect(days[0].rows == [.logged(sunday)])
        #expect(days[2].label == .day(monday + day))
    }

    @Test("T-DONE: today's session done leaves out its planned row and hides TODAY ▸")
    func weekdayDone() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5])
        let push = makeWorkout(in: slots[0], daysAgo: 0, block: block)

        let days = try groups(for: block)

        #expect(days[1].rows == [.logged(push)])
        #expect(!days.flatMap(\.rows).contains { if case .planned(_, .start) = $0 { true } else { false } })
    }

    @Test("T-DONE on a swapped day: the planned session stays a plain row under the one trained instead")
    func weekdaySwapped() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5])
        let pull = makeWorkout(in: slots[1], daysAgo: 0, block: block)

        let days = try groups(for: block)

        #expect(days[1].rows == [.logged(pull), .planned(slots[0], .plain)])
        #expect(days[3].rows == [.planned(slots[1], .plain)])
    }

    @Test("T-REST: today reads Rest and nothing starts")
    func weekdayRest() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [2, 4]) // Monday, Wednesday

        let days = try groups(for: block)

        #expect(days[0].rows == [.planned(slots[0], .plain)])
        #expect(days[1].rows == [.rest])
        #expect(days[2].rows == [.planned(slots[1], .plain)])
    }

    @Test("T-RESUME: the open workout reads in progress on its day, read-only, in place of the slot it holds")
    func weekdayResume() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5])
        let open = makeWorkout(in: slots[0], daysAgo: 0, block: block, finished: false)

        let days = try groups(for: block)

        #expect(days[1].rows == [.inProgress(open)])
        #expect(days[3].rows == [.planned(slots[1], .plain)])
    }

    @Test("T-RESUME with another session open: today's planned session stays, plain, under it")
    func weekdayResumeAnotherSession() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5])
        let open = makeWorkout(in: nil, daysAgo: 0, block: block, finished: false)

        let days = try groups(for: block)

        #expect(days[1].rows == [.inProgress(open), .planned(slots[0], .plain)])
    }

    @Test("T-FIX: a planned session with no exercises repairs, today's and a later day's")
    func weekdayFix() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"], empty: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5])

        let days = try groups(for: block)

        #expect(days[1].rows == [.planned(slots[0], .repair)])
        #expect(days[3].rows == [.planned(slots[1], .repair)])
    }

    // MARK: - Rotation block

    @Test("Rotation T-TODAY: each slot shows its latest workout in the block, and NEXT starts")
    func rotationToday() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let block = makeBlock(on: routine)
        let push = makeWorkout(in: slots[0], daysAgo: 2, block: block) // last week
        let pull = makeWorkout(in: slots[1], daysAgo: 1, block: block)

        let strip = try groups(for: block)

        #expect(strip == [
            .init(label: .slot(slots[0]), rows: [.logged(push)]),
            .init(label: .slot(slots[1]), rows: [.logged(pull)]),
            .init(label: .slot(slots[2]), rows: [.planned(slots[2], .start)]),
        ])
    }

    @Test("Rotation: Also this week lists the week's other workouts, so each shows once")
    func rotationAlsoThisWeek() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let block = makeBlock(on: routine)
        let earlier = makeWorkout(in: slots[0], daysAgo: 1.4, block: block)
        let arms = makeWorkout(in: nil, daysAgo: 1.2, block: block)
        let latest = makeWorkout(in: slots[0], daysAgo: 1, block: block)
        let otherBlock = makeWorkout(in: slots[2], daysAgo: 1.1)                // no block: not Legs A's latest here
        makeWorkout(in: slots[1], daysAgo: 1.3, block: block, logged: false) // empty: not counted

        let strip = try groups(for: block)

        #expect(strip.map(\.rows) == [
            [.logged(latest)],
            [.planned(slots[1], .start)],
            [.planned(slots[2], .plain)],
            [.logged(earlier), .logged(arms), .logged(otherBlock)],
        ])
        #expect(strip.last?.label == .also)
    }

    @Test("Rotation T-RESUME: the open workout reads in progress on its slot, else under Also; NEXT does not start")
    func rotationResume() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine)
        let open = makeWorkout(in: slots[0], daysAgo: 0, block: block, finished: false)
        #expect(try groups(for: block).map(\.rows) == [[.inProgress(open)], [.planned(slots[1], .plain)]])

        open.slot = nil
        #expect(try groups(for: block).map(\.rows) == [
            [.planned(slots[0], .plain)], [.planned(slots[1], .plain)], [.inProgress(open)],
        ])
    }

    @Test("Rotation T-DONE: NEXT no longer starts, and today's workout shows on its slot")
    func rotationDone() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine)
        let push = makeWorkout(in: slots[0], daysAgo: 0, block: block)

        #expect(try groups(for: block).map(\.rows) == [[.logged(push)], [.planned(slots[1], .plain)]])
    }

    @Test("Rotation T-FIX: an empty NEXT repairs ahead of its last workout, which lists under Also")
    func rotationFix() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"], empty: ["Pull A"])
        let block = makeBlock(on: routine)
        let pull = makeWorkout(in: slots[1], daysAgo: 1.5, block: block) // logged before Pull A was emptied
        let push = makeWorkout(in: slots[0], daysAgo: 1, block: block)

        #expect(try groups(for: block).map(\.rows) == [
            [.logged(push)], [.planned(slots[1], .repair)], [.logged(pull)],
        ])
    }

    // MARK: - Helpers

    /// Monday 13 November 2023, midnight UTC.
    private var monday: Date { calendar.startOfDay(for: now - day) }

    /// An active weekly block on `days` (1 is Sunday), started `startedDaysAgo` days before now.
    private func weekly(_ routine: Split, on days: [Int], startedDaysAgo: Double = 8) -> Block {
        let block = makeBlock(on: routine, weekly: days)
        block.startDate = now.addingTimeInterval(-startedDaysAgo * day)
        return block
    }

    /// This week as Program shows it now: Today's state from Today's inputs, then the groups.
    private func groups(for block: Block, weekStartsMonday: Bool = true) throws -> [ThisWeek.Group] {
        let workouts = try ctx.fetch(FetchDescriptor<Session>())
        let resolution = resolution(for: block, at: now)
        let state = TodayState.resolve(
            openWorkouts: workouts.filter { $0.completedAt == nil }, activeBlock: block, resolution: resolution,
            finishedWorkouts: workouts.filter { $0.completedAt != nil }, readyBlocks: [], liveRoutines: [],
            sessions: [], now: now, calendar: calendar)
        return ThisWeek.groups(
            block: block, state: state, resolution: resolution, workouts: workouts,
            weekStart: now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday, calendar: calendar),
            now: now, calendar: calendar)
    }
}
