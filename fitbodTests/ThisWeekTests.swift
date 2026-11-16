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
        let settings = UserSettings()
        ctx.insert(settings)
        settings.weekStartsMonday = false

        let days = try groups(for: block)

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

    @Test("Rotation: a NEXT slot logged this week offers NEXT ▸, and that workout lists once under Also")
    func rotationNextLoggedThisWeek() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine)
        let pull = makeWorkout(in: slots[1], daysAgo: 1.5, block: block)
        let push = makeWorkout(in: slots[0], daysAgo: 1, block: block)

        let strip = try groups(for: block)

        #expect(strip.map(\.rows) == [[.logged(push)], [.planned(slots[1], .start)], [.logged(pull)]])
        #expect(strip.last?.label == .also)
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

    // MARK: - Edges

    @Test("A workout from 23:30 past midnight stays on the day it started, the week's last day included")
    func overnightWorkouts() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = weekly(routine, on: [3, 5]) // Tuesday, Thursday
        let lastSunday = overnight(from: monday - day, block: block) // last week's last day, into Monday
        let mondayNight = overnight(from: monday, block: block)      // into today

        let days = try groups(for: block)

        #expect(days[0].rows == [.logged(mondayNight)])
        #expect(days[1].rows == [.planned(slots[0], .start)])         // nothing started today: still T-TODAY
        #expect(!days.flatMap(\.rows).contains(.logged(lastSunday)))
    }

    @Test("In New York's clock-change week the days and the week's end fall on local midnight")
    func daylightSavingWeek() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        func local(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) throws -> Date {
            try #require(newYork.date(from: DateComponents(year: 2023, month: month, day: day, hour: hour, minute: minute)))
        }
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let block = makeBlock(on: routine, weekly: [2])
        func workout(at start: Date) -> Session {
            let workout = makeWorkout(in: nil, daysAgo: 0, block: block)
            workout.startedAt = start
            workout.completedAt = start.addingTimeInterval(1_800)
            return workout
        }
        let lastWeek = workout(at: try local(10, 29, 23, 30))
        let first = workout(at: try local(10, 30, 0, 30))
        // The clocks went back at 2:00 that Sunday, so seven times 24 hours from the week start ends at 23:00.
        let last = workout(at: try local(11, 5, 23, 30))

        let days = try groups(for: block, at: try local(11, 5, 23, 45), calendar: newYork)

        let weekStart = try local(10, 30)
        let midnights = (0..<7).compactMap { newYork.date(byAdding: .day, value: $0, to: weekStart) }
        #expect(days.map(\.label) == midnights.map(ThisWeek.Label.day))
        #expect(logged(days.first) == [first])
        #expect(logged(days.last) == [last])
        #expect(!days.flatMap(\.rows).contains(.logged(lastWeek)))
    }

    @Test("No routine, or a routine with no sessions, plans nothing: only the week's workouts show, and none hides it")
    func nothingPlanned() throws {
        let block = weekly(makeRoutine("No Sessions"), on: [2, 3])
        #expect(try groups(for: block).isEmpty)

        let arms = makeWorkout(in: nil, daysAgo: 1, block: block)
        let onItsDay = [ThisWeek.Group(label: .day(monday), rows: [.logged(arms)])]
        #expect(try groups(for: block) == onItsDay)
        block.split = nil // T-ATTACH
        #expect(try groups(for: block) == onItsDay)

        block.schedulingMode = .rotation
        #expect(try week(for: block) == ThisWeek(range: nil, groups: [.init(label: .also, rows: [.logged(arms)])]))
    }

    @Test("A slot whose session is gone reads Untitled session, plain, on rotation and on its weekday")
    func slotWithoutSession() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        slots[1].sessionTemplate = nil
        let rotation = makeBlock(on: routine)
        makeWorkout(in: slots[0], daysAgo: 1, block: rotation) // so NEXT is the slot without a session
        let weekBlock = weekly(routine, on: [2, 3])             // Monday, Tuesday: today is that slot's day

        let strip = try groups(for: rotation)
        let days = try groups(for: weekBlock)

        #expect(strip[1].rows == [.planned(slots[1], .plain)])
        #expect(days[1].rows == [.planned(slots[1], .plain)])
        #expect(strip[1].rows.first?.name == "Untitled session")
    }

    @Test("An open workout from an earlier week shows nowhere: the resume banner is its route")
    func openFromAnEarlierWeek() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let rotation = makeBlock(on: routine)
        let open = makeWorkout(in: slots[0], daysAgo: 8, block: rotation, finished: false)
        let weekBlock = weekly(routine, on: [3, 5])

        #expect(try groups(for: rotation).map(\.rows) == [[.planned(slots[0], .plain)], [.planned(slots[1], .plain)]])
        #expect(!(try groups(for: weekBlock)).flatMap(\.rows).contains(.inProgress(open)))
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

    /// A finished workout from 23:30 on `day` to 00:30 the day after.
    private func overnight(from day: Date, block: Block) -> Session {
        let workout = makeWorkout(in: nil, daysAgo: 0, block: block)
        workout.startedAt = day.addingTimeInterval(23.5 * 3_600)
        workout.completedAt = workout.startedAt.addingTimeInterval(3_600)
        return workout
    }

    /// This week as Program shows it at `date`, from the store as Program's queries read it.
    private func week(for block: Block, at date: Date? = nil, calendar: Calendar? = nil) throws -> ThisWeek {
        ThisWeek.make(
            block: block,
            workouts: try ctx.fetch(FetchDescriptor<Session>()),
            templates: try ctx.fetch(FetchDescriptor<SessionTemplate>()).filter { !$0.isArchived },
            settings: try ctx.fetch(FetchDescriptor<UserSettings>()),
            liveRoutines: try ctx.fetch(FetchDescriptor<Split>()).filter { !$0.isArchived },
            readyBlocks: try ctx.fetch(FetchDescriptor<Block>()).filter { $0.derivedStatus == .ready },
            context: ctx, now: date ?? now, calendar: calendar ?? self.calendar)
    }

    private func groups(for block: Block, at date: Date? = nil, calendar: Calendar? = nil) throws -> [ThisWeek.Group] {
        try week(for: block, at: date, calendar: calendar).groups
    }

    /// The workouts a group lists as logged.
    private func logged(_ group: ThisWeek.Group?) -> [Session] {
        (group?.rows ?? []).compactMap { if case .logged(let workout) = $0 { workout } else { nil } }
    }
}
