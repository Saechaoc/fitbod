import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("TodayState")
struct TodayStateTests {
    private let ctx: ModelContext
    private let bench: Exercise
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Exercise(name: "Bench Press", canonicalName: "bench press", equipmentRaw: "barbell", mechanicRaw: "compound")
        ctx.insert(bench)
    }

    // MARK: Fixtures

    private func block(name: String = "Spring Block", active: Bool = true, routine: Split? = nil, startDate: Date? = nil) -> Block {
        let block = Block()
        ctx.insert(block)
        block.name = name
        block.isActive = active
        if let startDate { block.startDate = startDate }
        block.split = routine
        return block
    }

    private func routine(name: String = "Push Pull Legs", createdAt: Date? = nil) -> Split {
        let split = Split()
        ctx.insert(split)
        split.name = name
        if let createdAt { split.createdAt = createdAt }
        return split
    }

    /// A template with `exerciseCount` exercises; with a routine, also a slot at the next position.
    private func session(name: String = "Push A", exerciseCount: Int, in routine: Split? = nil) -> (SessionTemplate, SplitSessionSlot?) {
        let template = SessionTemplate()
        ctx.insert(template)
        template.name = name
        for index in 0..<exerciseCount {
            let row = SessionExerciseTemplate()
            ctx.insert(row)
            row.sessionTemplate = template
            row.exercise = bench
            row.orderIndex = index
        }
        guard let routine else { return (template, nil) }
        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = routine
        slot.sessionTemplate = template
        slot.position = (routine.slots ?? []).count - 1
        return (template, slot)
    }

    private func workout(startedAt: Date, finished: Bool = true, logged: Bool = true) -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = finished ? startedAt.addingTimeInterval(3_600) : nil
        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = bench
        let set = SetEntry()
        ctx.insert(set)
        set.sessionExercise = se
        set.setTypeRaw = SetType.working.rawValue
        set.weight = 100
        set.reps = 5
        set.isComplete = logged
        set.completedAt = startedAt
        return session
    }

    private func resolve(
        open: [Session] = [], block: Block? = nil, resolution: TodayResolution = .noBlock,
        finished: [Session] = [], ready: [Block] = [], routines: [Split] = [],
        sessions: [SessionTemplate] = [], at date: Date? = nil
    ) -> TodayState {
        TodayState.resolve(
            openWorkouts: open, activeBlock: block, resolution: resolution, finishedWorkouts: finished,
            readyBlocks: ready, liveRoutines: routines, sessions: sessions, now: date ?? now, calendar: calendar)
    }

    /// An active block whose routine holds one session with exercises, scheduled today.
    private func scheduled() -> (Block, SplitSessionSlot, Split) {
        let routine = routine()
        let (_, slot) = session(exerciseCount: 2, in: routine)
        return (block(routine: routine), slot!, routine)
    }

    // MARK: Precedence

    @Test func resumeWinsOverEverything() {
        let (block, slot, routine) = scheduled()
        let open = workout(startedAt: now.addingTimeInterval(-2 * 86_400), finished: false)
        let older = workout(startedAt: now.addingTimeInterval(-3 * 86_400), finished: false)
        let done = workout(startedAt: now)
        let readyBlock = self.block(name: "Next", active: false)
        #expect(resolve(open: [older, open], block: block, resolution: .session(slot), finished: [done],
                        ready: [readyBlock], routines: [routine]) == .resume(open))
    }

    @Test func doneTodayOutranksTheBlock() {
        let (block, slot, _) = scheduled()
        let done = workout(startedAt: now)
        #expect(resolve(block: block, resolution: .session(slot), finished: [done]) == .done([done]))
    }

    @Test func doneListsNewestFirst() {
        let (block, slot, _) = scheduled()
        let earlier = workout(startedAt: now.addingTimeInterval(-600))
        let later = workout(startedAt: now)
        #expect(resolve(block: block, resolution: .session(slot), finished: [earlier, later]) == .done([later, earlier]))
    }

    @Test func doneOutranksReady() {
        let done = workout(startedAt: now)
        let readyBlock = block(active: false)
        #expect(resolve(finished: [done], ready: [readyBlock]) == .done([done]))
    }

    @Test func aWorkoutStartedYesterdayIsNotDoneToday() {
        let (block, slot, _) = scheduled()
        let startOfToday = calendar.startOfDay(for: now)
        let late = workout(startedAt: startOfToday.addingTimeInterval(-600))
        late.completedAt = startOfToday.addingTimeInterval(600)
        #expect(resolve(block: block, resolution: .session(slot), finished: [late]) == .today(block, slot))
    }

    @Test func anEmptyWorkoutTodayIsNotDone() {
        let (block, slot, _) = scheduled()
        let empty = workout(startedAt: now, logged: false)
        #expect(resolve(block: block, resolution: .session(slot), finished: [empty]) == .today(block, slot))
    }

    // MARK: Ready

    @Test func readyWhenNoBlock() {
        let readyBlock = block(active: false)
        #expect(resolve(ready: [readyBlock]) == .ready(readyBlock))
    }

    @Test func readyBlocksOrderByStartDateThenNameThenID() {
        let older = block(name: "Z", active: false, startDate: now.addingTimeInterval(-100))
        let newer = block(name: "A", active: false, startDate: now)
        #expect(resolve(ready: [newer, older]) == .ready(older))

        let b = block(name: "B", active: false, startDate: now)
        let a = block(name: "A", active: false, startDate: now)
        #expect(resolve(ready: [b, a]) == .ready(a))

        let first = block(name: "Same", active: false, startDate: now)
        let second = block(name: "Same", active: false, startDate: now)
        let smaller = first.id.uuidString < second.id.uuidString ? first : second
        #expect(resolve(ready: [first, second]) == .ready(smaller))
        #expect(resolve(ready: [second, first]) == .ready(smaller))
    }

    @Test func readyOutranksPick() {
        let routine = routine()
        _ = session(exerciseCount: 1, in: routine)
        let readyBlock = block(active: false)
        #expect(resolve(ready: [readyBlock], routines: [routine]) == .ready(readyBlock))
    }

    // MARK: Active block

    @Test func fixWhenTheRoutineHasNoSessions() {
        let routine = routine()
        let block = block(routine: routine)
        #expect(resolve(block: block, resolution: .emptySplit) == .fix(.routineHasNoSessions(routine)))
    }

    @Test func fixWhenTheScheduledSessionHasNoExercises() {
        let routine = routine()
        let (template, slot) = session(exerciseCount: 0, in: routine)
        let block = block(routine: routine)
        #expect(resolve(block: block, resolution: .session(slot!)) == .fix(.sessionHasNoExercises(template)))
    }

    @Test func attachWhenTheBlockHasNoRoutine() {
        let block = block()
        #expect(resolve(block: block, resolution: .noBlock) == .attach(block))
    }

    @Test func restDay() {
        let block = block(routine: routine())
        #expect(resolve(block: block, resolution: .restDay) == .rest(block))
    }

    @Test func todayWithExercises() {
        let (block, slot, _) = scheduled()
        #expect(resolve(block: block, resolution: .session(slot)) == .today(block, slot))
    }

    // MARK: No block

    @Test func pickWithASessionInALiveRoutine() {
        let routine = routine()
        let (template, slot) = session(exerciseCount: 1, in: routine)
        #expect(resolve(routines: [routine]) == .pick(.init(session: template, slot: slot)))
    }

    @Test func pickMovesOnAfterAFinishedSlottedWorkout() {
        let routine = routine()
        let (_, push) = session(name: "Push A", exerciseCount: 1, in: routine)
        let (pullA, pull) = session(name: "Pull A", exerciseCount: 1, in: routine)
        let done = workout(startedAt: now.addingTimeInterval(-86_400))
        done.slot = push
        #expect(resolve(finished: [done], routines: [routine]) == .pick(.init(session: pullA, slot: pull)))
    }

    @Test func pickWithAStandaloneSession() {
        let (template, _) = session(exerciseCount: 1)
        #expect(resolve(sessions: [template]) == .pick(.init(session: template, slot: nil)))
    }

    @Test func pickWithASessionOnlyInAnArchivedRoutine() {
        let archived = routine()
        archived.isArchived = true
        let (template, _) = session(exerciseCount: 1, in: archived)
        #expect(resolve(sessions: [template]) == .pick(.init(session: template, slot: nil)))
    }

    @Test func fixWithALiveRoutineAndNoSessions() {
        let routine = routine()
        #expect(resolve(routines: [routine]) == .fix(.routineHasNoSessions(routine)))
    }

    @Test func fixWithALiveRoutineAndNoExercises() {
        let routine = routine()
        let (template, _) = session(exerciseCount: 0, in: routine)
        #expect(resolve(routines: [routine], sessions: [template]) == .fix(.routineHasNoExercises(routine)))
    }

    @Test func fixNamesTheNewestLiveRoutine() {
        let older = routine(name: "Old", createdAt: now.addingTimeInterval(-100))
        let newer = routine(name: "New", createdAt: now.addingTimeInterval(-10))
        #expect(resolve(routines: [older, newer]) == .fix(.routineHasNoSessions(newer)))
        #expect(resolve(routines: [newer, older]) == .fix(.routineHasNoSessions(newer)))
    }

    @Test func firstOnAFreshStore() {
        #expect(resolve() == .first)
    }

    @Test func fixNamesTheRoutineWithTheNewestSessionEdit() {
        let older = routine(name: "Older", createdAt: now.addingTimeInterval(-100))
        let newer = routine(name: "Newer", createdAt: now)
        let (recent, _) = session(exerciseCount: 0, in: older)
        let (stale, _) = session(exerciseCount: 0, in: newer)
        recent.updatedAt = now
        stale.updatedAt = now.addingTimeInterval(-10)
        #expect(resolve(routines: [older, newer]) == .fix(.routineHasNoExercises(older)))
        #expect(resolve(routines: [newer, older]) == .fix(.routineHasNoExercises(older)))
    }

    @Test func fixBreaksEqualDatesByNameThenID() {
        let z = routine(name: "Z", createdAt: now)
        let a = routine(name: "A", createdAt: now)
        #expect(resolve(routines: [z, a]) == .fix(.routineHasNoSessions(a)))
        let otherA = routine(name: "A", createdAt: now)
        let first = a.id.uuidString < otherA.id.uuidString ? a : otherA
        #expect(resolve(routines: [a, otherA]) == .fix(.routineHasNoSessions(first)))
    }

    @Test func theDayTurnsOverWithNow() {
        let (block, slot, _) = scheduled()
        let done = workout(startedAt: now)
        #expect(resolve(block: block, resolution: .session(slot), finished: [done]) == .done([done]))
        #expect(resolve(block: block, resolution: .session(slot), finished: [done], at: now.addingTimeInterval(86_400))
                == .today(block, slot))
    }

    // MARK: Advisory

    @Test func showsDeloadAdvisory() {
        let (block, slot, _) = scheduled()
        let open = workout(startedAt: now, finished: false)
        #expect(!TodayState.showsDeloadAdvisory(state: .resume(open), phase: nil))
        #expect(!TodayState.showsDeloadAdvisory(state: .today(block, slot), phase: .deload))
        #expect(TodayState.showsDeloadAdvisory(state: .today(block, slot), phase: .accumulation))
        #expect(TodayState.showsDeloadAdvisory(state: .first, phase: nil))
    }
}
