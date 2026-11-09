import Foundation
import SwiftData
@testable import fitbod

/// Routines, sessions, slots, blocks and workouts for the suites that test
/// which slot a start credits. A suite conforms, supplies the four values
/// below, and gets the builders.
@MainActor
protocol ProgramFixtures {
    var ctx: ModelContext { get }
    /// The one exercise every session and workout uses.
    var bench: Exercise { get }
    /// The moment the suite treats as now.
    var now: Date { get }
    var calendar: Calendar { get }
}

extension ProgramFixtures {
    var day: TimeInterval { 86_400 }

    /// A Tuesday, 22:13 UTC.
    static var tuesdayEvening: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func makeBench(in ctx: ModelContext) -> Exercise {
        let bench = Exercise(name: "Bench Press", canonicalName: "bench press", equipmentRaw: "barbell", mechanicRaw: "compound")
        ctx.insert(bench)
        return bench
    }

    func makeRoutine(_ name: String = "Push Pull Legs") -> Split {
        let routine = Split()
        ctx.insert(routine)
        routine.name = name
        return routine
    }

    /// A session with one exercise, or none when `empty`, last edited at `updatedAt` (`now` when not given).
    func makeSession(_ name: String, empty: Bool = false, updatedAt: Date? = nil) -> SessionTemplate {
        let session = SessionTemplate()
        ctx.insert(session)
        session.name = name
        session.updatedAt = updatedAt ?? now
        if !empty {
            let row = SessionExerciseTemplate()
            ctx.insert(row)
            row.sessionTemplate = session
            row.exercise = bench
        }
        return session
    }

    /// One slot per session, in the order given.
    func addSlots(_ sessions: [SessionTemplate], to routine: Split) -> [SplitSessionSlot] {
        sessions.enumerated().map { position, session in
            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.split = routine
            slot.position = position
            slot.sessionTemplate = session
            return slot
        }
    }

    /// A routine with one session per name, each in its own slot; the names in `empty` have no exercises.
    func makeRoutine(
        _ name: String = "Push Pull Legs", sessions: [String], empty: Set<String> = []
    ) -> (Split, [SplitSessionSlot]) {
        let routine = makeRoutine(name)
        return (routine, addSlots(sessions.map { makeSession($0, empty: empty.contains($0)) }, to: routine))
    }

    /// A workout started `daysAgo` days before `now`: finished, with one logged work set, unless told otherwise.
    @discardableResult
    func makeWorkout(
        in slot: SplitSessionSlot?, daysAgo: Double, block: Block? = nil, finished: Bool = true, logged: Bool = true
    ) -> Session {
        let workout = Session()
        ctx.insert(workout)
        workout.startedAt = now.addingTimeInterval(-daysAgo * day)
        workout.completedAt = finished ? workout.startedAt.addingTimeInterval(3_600) : nil
        workout.slot = slot
        workout.block = block
        let exercise = SessionExercise()
        ctx.insert(exercise)
        exercise.session = workout
        exercise.exercise = bench
        let set = SetEntry()
        ctx.insert(set)
        set.sessionExercise = exercise
        set.setTypeRaw = SetType.working.rawValue
        set.weight = 100
        set.reps = 5
        set.isComplete = logged
        return workout
    }

    /// An active block on `routine`: weekly on `days` (1 is Sunday) when given, else rotation.
    func makeBlock(on routine: Split?, weekly days: [Int]? = nil) -> Block {
        let block = Block()
        ctx.insert(block)
        block.isActive = true
        block.split = routine
        if let days {
            block.schedulingMode = .fixedWeekly
            block.trainingDays = days
        }
        return block
    }

    /// Every finished workout in the store, as a caller fetches them.
    func finishedWorkouts() throws -> [Session] {
        try ctx.fetch(FetchDescriptor<Session>()).filter { $0.completedAt != nil }
    }

    /// The real resolver's answer for `block` on `date`; `.noBlock` without one.
    func resolution(for block: Block?, at date: Date) -> TodayResolution {
        block.map { TodayResolver.resolve(block: $0, context: ctx, today: date, calendar: calendar) } ?? .noBlock
    }
}
