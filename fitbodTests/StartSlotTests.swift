import Foundation
import SwiftData
import Testing
@testable import fitbod

/// The slot rule every start shares (RM-006, O-2): NEXT in each scheduling mode, the slot a
/// start credits, what it skips, and the session Today suggests when no block runs.
@MainActor
@Suite("StartSlot")
struct StartSlotTests: ProgramFixtures {
    let ctx: ModelContext
    let bench: Exercise
    let now = StartSlotTests.tuesdayEvening
    let calendar = StartSlotTests.utcCalendar

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Self.makeBench(in: ctx)
    }

    /// NEXT in `block` as a caller gets it: the real resolver's answer for `date`, then the rule.
    private func next(in block: Block, at date: Date? = nil) throws -> SplitSessionSlot? {
        let date = date ?? now
        return StartSlot.next(
            in: block, resolution: resolution(for: block, at: date),
            finished: try finishedWorkouts(), now: date, calendar: calendar)
    }

    // MARK: NEXT in a block

    @Test("rotation block: NEXT is the resolver's next slot, before and after a workout today")
    func rotationNext() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let block = makeBlock(on: routine)
        #expect(try next(in: block) == slots[0])
        makeWorkout(in: slots[0], daysAgo: 0, block: block)
        #expect(try next(in: block) == slots[1])
    }

    @Test("weekly block: today's slot until a counted workout starts today, then the next training day's")
    func weeklyNext() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine, weekly: [3, 5]) // Tuesday, Thursday
        #expect(try next(in: block) == slots[0])
        makeWorkout(in: slots[0], daysAgo: 0, block: block, logged: false) // finished with nothing logged
        makeWorkout(in: slots[0], daysAgo: 1, block: block)                // counted, but started yesterday
        #expect(try next(in: block) == slots[0])
        makeWorkout(in: nil, daysAgo: 0)                                   // any counted workout started today
        #expect(try next(in: block) == slots[1])
    }

    @Test("weekly block: a rest day names the next training day's slot, past the week's end too")
    func weeklyNextOnARestDay() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine, weekly: [3, 5])
        #expect(try next(in: block, at: now.addingTimeInterval(day)) == slots[1])     // Wednesday: Thursday's
        #expect(try next(in: block, at: now.addingTimeInterval(3 * day)) == slots[0]) // Friday: next Tuesday's
    }

    @Test("weekly block: the only training day comes round again, and no training day gives no NEXT")
    func weeklyNextWithOneOrNoTrainingDay() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine, weekly: [3])
        makeWorkout(in: slots[0], daysAgo: 0, block: block)
        #expect(try next(in: block) == slots[0])
        block.trainingDays = []
        #expect(try next(in: block) == nil)
    }

    @Test("a block with no routine, or a routine with no sessions, has no NEXT")
    func blockWithNothingToRun() throws {
        #expect(try next(in: makeBlock(on: nil)) == nil)
        #expect(try next(in: makeBlock(on: makeRoutine())) == nil)
        #expect(try next(in: makeBlock(on: makeRoutine(), weekly: [3])) == nil)
    }

    // MARK: NEXT with no block

    @Test("no block: NEXT is the first slot, then the slot after the newest counted workout, wrapping")
    func routineNext() {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        #expect(StartSlot.next(in: routine, finished: []) == slots[0])
        let push = makeWorkout(in: slots[0], daysAgo: 3)
        #expect(StartSlot.next(in: routine, finished: [push]) == slots[1])
        let legs = makeWorkout(in: slots[2], daysAgo: 1)
        #expect(StartSlot.next(in: routine, finished: [push, legs]) == slots[0])
        #expect(StartSlot.next(in: routine, finished: [legs, push]) == slots[0])
    }

    @Test("no block: NEXT never names a session with no exercises")
    func routineNextSkipsEmptySessions() {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"], empty: ["Pull A"])
        #expect(StartSlot.next(in: routine, finished: [makeWorkout(in: slots[0], daysAgo: 1)]) == slots[2])

        let (emptyFirst, emptyFirstSlots) = makeRoutine("Upper Lower", sessions: ["Upper A", "Lower A"], empty: ["Upper A"])
        #expect(StartSlot.next(in: emptyFirst, finished: []) == emptyFirstSlots[1])

        let (allEmpty, _) = makeRoutine("Arms", sessions: ["Arms A"], empty: ["Arms A"])
        #expect(StartSlot.next(in: allEmpty, finished: []) == nil)
        #expect(StartSlot.next(in: makeRoutine("No sessions"), finished: []) == nil)
    }

    @Test("no block: open, empty, unslotted and other-routine workouts do not move NEXT")
    func routineNextIgnoresWorkoutsThatDoNotCount() {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let (other, otherSlots) = makeRoutine("Upper Lower", sessions: ["Upper A", "Lower A"])
        let workouts = [
            makeWorkout(in: slots[0], daysAgo: 5),                  // the anchor
            makeWorkout(in: slots[1], daysAgo: 4, finished: false), // still open
            makeWorkout(in: slots[2], daysAgo: 3, logged: false),   // finished with nothing logged
            makeWorkout(in: nil, daysAgo: 2),                       // unslotted, as after its slot is deleted
            makeWorkout(in: otherSlots[0], daysAgo: 1),             // the other routine's
        ]
        #expect(StartSlot.next(in: routine, finished: workouts) == slots[1])
        #expect(StartSlot.next(in: other, finished: workouts) == otherSlots[1])
    }

    // MARK: The slot a start credits

    /// The slot a start of `session` from `routine` credits, asked the way the starter asks at the tap.
    private func slot(for session: SessionTemplate, startedFrom routine: Split?, block: Block? = nil) throws -> SplitSessionSlot? {
        StartSlot.slot(
            for: session, startedFrom: routine, block: block, resolution: resolution(for: block, at: now),
            finished: try finishedWorkouts(), now: now, calendar: calendar)
    }

    @Test("no block: a start takes its slot in the routine it starts from, counted from that routine's NEXT")
    func startWithNoBlock() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let pull = try #require(slots[1].sessionTemplate)
        let other = makeRoutine("Upper Lower")
        let otherSlots = addSlots([pull, makeSession("Lower A")], to: other)
        makeWorkout(in: slots[0], daysAgo: 1)

        #expect(try slot(for: pull, startedFrom: routine) == slots[1])
        #expect(try slot(for: pull, startedFrom: other) == otherSlots[0])
        #expect(try slot(for: pull, startedFrom: nil) == nil)
        other.isArchived = true
        #expect(try slot(for: pull, startedFrom: other) == nil)
    }

    @Test("while a block runs, only a start from the block's own routine takes a slot")
    func startWhileABlockRuns() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let pull = try #require(slots[1].sessionTemplate)
        let other = makeRoutine("Upper Lower")
        _ = addSlots([pull], to: other)
        let block = makeBlock(on: routine)

        #expect(try slot(for: pull, startedFrom: routine, block: block) == slots[1])
        #expect(try slot(for: pull, startedFrom: other, block: block) == nil)
        #expect(try slot(for: pull, startedFrom: nil, block: block) == nil)
    }

    @Test("a session slotted twice takes NEXT when NEXT holds it, else its first slot after NEXT")
    func slotForASessionSlottedTwice() {
        let routine = makeRoutine()
        let push = makeSession("Push"), pull = makeSession("Pull"), legs = makeSession("Legs")
        let slots = addSlots([push, pull, legs, push, pull, legs], to: routine)

        #expect(StartSlot.slot(for: push, in: routine, next: slots[3]) == slots[3])
        #expect(StartSlot.slot(for: pull, in: routine, next: slots[3]) == slots[4])
        // Legs is never credited to its earlier slot, which would move the rotation backwards.
        #expect(StartSlot.slot(for: legs, in: routine, next: slots[4]) == slots[5])
        #expect(StartSlot.slot(for: push, in: routine, next: slots[4]) == slots[0])
        // With no NEXT a session takes its first slot.
        #expect(StartSlot.slot(for: legs, in: routine, next: nil) == slots[2])
        // A session the routine does not hold starts unslotted.
        #expect(StartSlot.slot(for: makeSession("Arms"), in: routine, next: slots[3]) == nil)
    }

    @Test("a start past NEXT skips the sessions from NEXT up to its slot, each named once")
    func skippedSessions() {
        let routine = makeRoutine()
        let a = makeSession("A"), b = makeSession("B"), c = makeSession("C")
        let slots = addSlots([a, b, a, c], to: routine)

        #expect(StartSlot.skipped(startingAt: slots[0], next: slots[0]).isEmpty)
        #expect(StartSlot.skipped(startingAt: slots[1], next: slots[0]) == [a])
        #expect(StartSlot.skipped(startingAt: slots[3], next: slots[0]) == [a, b])
        #expect(StartSlot.skipped(startingAt: slots[0], next: slots[3]) == [c])
        #expect(StartSlot.skipped(startingAt: slots[1], next: slots[2]) == [a, c])
        #expect(StartSlot.skipped(startingAt: slots[1], next: nil).isEmpty)
    }

    // MARK: Today's suggestion with no block

    @Test("suggestion: the routine with the newest counted slotted workout gives its NEXT, and moves on")
    func suggestionFollowsTheNewestWorkout() {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        let (other, otherSlots) = makeRoutine("Upper Lower", sessions: ["Upper A", "Lower A"])
        var workouts = [makeWorkout(in: otherSlots[0], daysAgo: 4), makeWorkout(in: slots[0], daysAgo: 2)]
        let pullA = StartSlot.suggestion(liveRoutines: [other, routine], sessions: [], finished: workouts)
        #expect(pullA == StartSlot.Suggestion(session: slots[1].sessionTemplate!, slot: slots[1]))

        // The suggested session, trained, moves the suggestion to the next one.
        workouts.append(makeWorkout(in: slots[1], daysAgo: 1))
        #expect(StartSlot.suggestion(liveRoutines: [other, routine], sessions: [], finished: workouts)?.slot == slots[2])
    }

    @Test("suggestion: a routine whose sessions are all empty is passed over, even with the newest workout")
    func suggestionPassesOverARoutineWithNoNext() {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let (emptied, emptiedSlots) = makeRoutine("Emptied", sessions: ["Arms A"], empty: ["Arms A"])
        let newest = makeWorkout(in: emptiedSlots[0], daysAgo: 1)
        #expect(StartSlot.suggestion(liveRoutines: [emptied, routine], sessions: [], finished: [newest])?.slot == slots[0])
    }

    @Test("suggestion: with no slotted workout, the routine holding the most recently updated session with exercises")
    func suggestionFallsBackToTheNewestEdit() {
        let old = now.addingTimeInterval(-10 * day), recent = now.addingTimeInterval(-day)
        let routine = makeRoutine()
        let slots = addSlots([makeSession("Push A", updatedAt: old), makeSession("Pull A", updatedAt: recent)], to: routine)
        let other = makeRoutine("Upper Lower")
        // Lower A is the newest edit of all, but it has no exercises.
        _ = addSlots([makeSession("Upper A", updatedAt: old), makeSession("Lower A", empty: true)], to: other)

        #expect(StartSlot.suggestion(liveRoutines: [other, routine], sessions: [], finished: [])?.slot == slots[0])
    }

    @Test("suggestion: routines that tie on workouts and edits lead by name")
    func suggestionBreaksTiesByName() {
        let (b, _) = makeRoutine("B", sessions: ["B1"])
        let (a, aSlots) = makeRoutine("A", sessions: ["A1"])
        #expect(StartSlot.suggestion(liveRoutines: [b, a], sessions: [], finished: [])?.slot == aSlots[0])
        #expect(StartSlot.suggestion(liveRoutines: [a, b], sessions: [], finished: [])?.slot == aSlots[0])
    }

    @Test("suggestion: with no usable routine session, the most recently updated session in no live routine")
    func suggestionFallsBackToASessionInNoLiveRoutine() {
        let (emptyRoutine, emptySlots) = makeRoutine(sessions: ["Push A"], empty: ["Push A"])
        let archived = makeRoutine("Old Split")
        archived.isArchived = true
        let oldPush = makeSession("Old Push", updatedAt: now.addingTimeInterval(-5 * day))
        _ = addSlots([oldPush], to: archived)
        let arms = makeSession("Arms", updatedAt: now.addingTimeInterval(-day))
        let blank = makeSession("Blank", empty: true)
        let sessions = [oldPush, arms, blank, emptySlots[0].sessionTemplate!]

        let suggestion = StartSlot.suggestion(liveRoutines: [emptyRoutine], sessions: sessions, finished: [])
        #expect(suggestion == StartSlot.Suggestion(session: arms, slot: nil))
        // A session only an archived routine holds is in no live routine, so it can lead, unslotted.
        #expect(StartSlot.suggestion(liveRoutines: [emptyRoutine], sessions: [oldPush], finished: [])
                == StartSlot.Suggestion(session: oldPush, slot: nil))
        #expect(StartSlot.suggestion(liveRoutines: [emptyRoutine], sessions: [blank], finished: []) == nil)
        #expect(StartSlot.suggestion(liveRoutines: [], sessions: [], finished: []) == nil)
    }

    @Test("suggestion: a routine session with exercises leads over a newer session in no routine")
    func suggestionPrefersARoutineSession() {
        let routine = makeRoutine()
        let push = makeSession("Push A", updatedAt: now.addingTimeInterval(-10 * day))
        let slots = addSlots([push], to: routine)
        let arms = makeSession("Arms")
        #expect(StartSlot.suggestion(liveRoutines: [routine], sessions: [push, arms], finished: [])?.slot == slots[0])
    }
}
