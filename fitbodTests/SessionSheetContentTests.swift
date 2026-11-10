import Foundation
import SwiftData
import Testing
@testable import fitbod

/// What the session sheet lists (RM-006): each routine's sessions once, the one NEXT mark,
/// the sessions a start skips, and the sessions that sit in no live routine.
@MainActor
@Suite("SessionSheetContent")
struct SessionSheetContentTests: ProgramFixtures {
    let ctx: ModelContext
    let bench: Exercise
    let now = SessionSheetContentTests.tuesdayEvening
    let calendar = SessionSheetContentTests.utcCalendar

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Self.makeBench(in: ctx)
    }

    /// The sheet's content as Today builds it, from the store as it is.
    private func content(routines: [Split], sessions: [SessionTemplate] = [], block: Block? = nil) throws -> SessionSheetContent {
        SessionSheetContent(
            liveRoutines: routines, sessions: sessions, block: block, resolution: resolution(for: block, at: now),
            finished: try finishedWorkouts(), now: now, calendar: calendar)
    }

    /// A group's rows as text: the name, " NEXT" on the marked row, then " skips A, B".
    private func rows(_ group: SessionSheetContent.Group) -> [String] {
        group.rows.map { row in
            row.session.name + (row.isNext ? " NEXT" : "")
                + (row.skips.isEmpty ? "" : " skips " + row.skips.map(\.name).joined(separator: ", "))
        }
    }

    // MARK: With no block

    @Test("no block: NEXT is marked once, a row past it names what it skips, an empty session cannot start")
    func noBlock() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"], empty: ["Legs A"])
        makeWorkout(in: slots[0], daysAgo: 2)

        let group = try #require(try content(routines: [routine]).groups.first)
        #expect(rows(group) == ["Push A skips Pull A, Legs A", "Pull A NEXT", "Legs A"])
        #expect(group.rows.map(\.canStart) == [true, true, false])
    }

    @Test("no block: the suggested routine leads and holds the one NEXT; another routine skips from its own NEXT")
    func noBlockWithTwoRoutines() throws {
        let (alpha, _) = makeRoutine("Alpha", sessions: ["A1", "A2"])
        let (beta, betaSlots) = makeRoutine("Beta", sessions: ["B1", "B2"])
        makeWorkout(in: betaSlots[0], daysAgo: 1)

        let groups = try content(routines: [alpha, beta]).groups
        #expect(groups.map(\.routine.name) == ["Beta", "Alpha"])
        #expect(rows(groups[0]) == ["B1 skips B2", "B2 NEXT"])
        #expect(rows(groups[1]) == ["A1", "A2 skips A1"])
    }

    // MARK: In a block

    @Test("rotation block: a session slotted twice is listed once, and skips count from NEXT")
    func rotationBlock() throws {
        let routine = makeRoutine()
        let push = makeSession("Push"), pull = makeSession("Pull"), legs = makeSession("Legs")
        let slots = addSlots([push, pull, legs, push, pull, legs], to: routine)
        let block = makeBlock(on: routine)
        #expect(rows(try #require(try content(routines: [routine], block: block).groups.first))
                == ["Push NEXT", "Pull skips Push", "Legs skips Push, Pull"])

        // Four workouts on, NEXT is the second Pull.
        for (index, slot) in slots.prefix(4).enumerated() {
            makeWorkout(in: slot, daysAgo: Double(10 - index), block: block)
        }
        #expect(rows(try #require(try content(routines: [routine], block: block).groups.first))
                == ["Push skips Pull, Legs", "Pull NEXT", "Legs skips Pull"])
    }

    @Test("rotation block: an empty session at NEXT is not marked, and the row after it says it is skipped")
    func rotationBlockWithAnEmptyNext() throws {
        let (routine, _) = makeRoutine(sessions: ["Push B", "Pull A"], empty: ["Push B"])
        let block = makeBlock(on: routine)
        #expect(rows(try #require(try content(routines: [routine], block: block).groups.first))
                == ["Push B", "Pull A skips Push B"])
    }

    @Test("weekly block: NEXT moves to the next training day after a workout today, and nothing is skipped")
    func weeklyBlock() throws {
        let (routine, _) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine, weekly: [3, 5]) // Tuesday, Thursday
        #expect(rows(try #require(try content(routines: [routine], block: block).groups.first)) == ["Push A NEXT", "Pull A"])

        makeWorkout(in: nil, daysAgo: 0)
        #expect(rows(try #require(try content(routines: [routine], block: block).groups.first)) == ["Push A", "Pull A NEXT"])
    }

    @Test("while a block runs its routine leads, and another routine's rows carry no NEXT and no skips")
    func otherRoutineWhileABlockRuns() throws {
        let (zeta, _) = makeRoutine("Zeta", sessions: ["Z1", "Z2"])
        let (alpha, _) = makeRoutine("Alpha", sessions: ["A1", "A2"])
        let block = makeBlock(on: zeta)

        let groups = try content(routines: [alpha, zeta], block: block).groups
        #expect(groups.map(\.routine.name) == ["Zeta", "Alpha"])
        #expect(rows(groups[0]) == ["Z1 NEXT", "Z2 skips Z1"])
        #expect(rows(groups[1]) == ["A1", "A2"])
    }

    // MARK: Other sessions

    @Test("sessions in no live routine are listed last by name; a routine with no sessions is left out")
    func otherSessions() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A"])
        let archived = makeRoutine("Old Split")
        archived.isArchived = true
        let oldPush = makeSession("Old Push")
        _ = addSlots([oldPush], to: archived)
        let arms = makeSession("Arms")
        let blank = makeSession("Blank", empty: true)
        let inRoutine = try #require(slots[0].sessionTemplate)

        let sheet = try content(
            routines: [routine, makeRoutine("No sessions")], sessions: [oldPush, inRoutine, blank, arms])
        #expect(sheet.groups.map(\.routine.name) == ["Push Pull Legs"])
        #expect(sheet.others.map(\.name) == ["Arms", "Blank", "Old Push"])
    }

    // MARK: Row text

    @Test("a row reads its exercises and sets, then what it skips; an empty session says so")
    func rowText() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"], empty: ["Legs A"])
        makeWorkout(in: slots[0], daysAgo: 2)
        let rows = try #require(try content(routines: [routine]).groups.first).rows

        #expect(SessionSheet.subline(for: rows[0], phase: nil) == "1 exercise · 3 sets · skips Pull A, Legs A")
        #expect(SessionSheet.subline(for: rows[1], phase: nil) == "1 exercise · 3 sets")
        #expect(SessionSheet.subline(for: rows[2], phase: nil) == "No exercises yet")
    }
}
