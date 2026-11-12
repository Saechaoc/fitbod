//
//  ProgramViewFidelityTests.swift
//  fitbodTests
//
//  Program's rules that compute something: which block leads and the
//  order of the rest (RM-011, O-6), the routine sublines and the past
//  block lines. The look itself is checked on the simulator, not pinned
//  in tests.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ProgramView fidelity")
struct ProgramViewFidelityTests: ProgramFixtures {
    let ctx: ModelContext
    let bench: Exercise
    let now = Self.tuesdayEvening
    let calendar = Self.utcCalendar

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Self.makeBench(in: ctx)
    }

    // MARK: - Block order

    @Test("The oldest created ready block leads, then by name and id; the rest stay in that order")
    func readyBlocksLeadOldestCreatedFirst() {
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let newer = unstarted("Newer", createdDaysAgo: 2, on: routine)
        let oldest = unstarted("Oldest", createdDaysAgo: 9, on: routine)
        let tiedB = unstarted("B", createdDaysAgo: 5, on: routine)
        let tiedA = unstarted("A", createdDaysAgo: 5, on: routine)

        let blocks = ProgramBlocks([newer, tiedB, oldest, tiedA])

        #expect(blocks.ready.map(\.name) == ["Oldest", "A", "B", "Newer"])
        #expect(blocks.lead?.name == "Oldest")
        #expect(blocks.planned.map(\.name) == ["A", "B", "Newer"])
        #expect(blocks.drafts.isEmpty && blocks.active == nil && blocks.past.isEmpty)
    }

    @Test("With drafts only, the newest created draft leads and the other drafts follow, newest first")
    func draftsLeadNewestCreatedFirst() {
        let older = unstarted("Older", createdDaysAgo: 8, on: nil)
        let newest = unstarted("Newest", createdDaysAgo: 1, on: nil)
        let middle = unstarted("Middle", createdDaysAgo: 4, on: nil)

        let blocks = ProgramBlocks([older, newest, middle])

        #expect(blocks.drafts.map(\.name) == ["Newest", "Middle", "Older"])
        #expect(blocks.lead?.name == "Newest")
        #expect(blocks.planned.map(\.name) == ["Middle", "Older"])
    }

    @Test("A ready block outranks a newer draft, and PLANNED lists the other ready blocks before the drafts")
    func readyOutranksDrafts() {
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let draft = unstarted("Draft", createdDaysAgo: 1, on: nil)
        let later = unstarted("Later", createdDaysAgo: 3, on: routine)
        let first = unstarted("First", createdDaysAgo: 6, on: routine)

        let blocks = ProgramBlocks([draft, later, first])

        #expect(blocks.lead?.name == "First")
        #expect(blocks.planned.map(\.name) == ["Later", "Draft"])
    }

    @Test("The active block leads, PLANNED keeps every block that has not started, and past blocks list newest ended first")
    func activeLeadsAndPastListsNewestEndedFirst() {
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let active = makeBlock(on: routine)
        active.name = "Running"
        let ready = unstarted("Ready", createdDaysAgo: 3, on: routine)
        let draft = unstarted("Draft", createdDaysAgo: 1, on: nil)
        let endedLong = ended("Winter", daysAgo: 90)
        let endedRecently = ended("Summer", daysAgo: 10)

        let blocks = ProgramBlocks([endedLong, draft, active, endedRecently, ready])

        #expect(blocks.active?.name == "Running")
        #expect(blocks.lead?.name == "Running")
        #expect(blocks.planned.map(\.name) == ["Ready", "Draft"])
        #expect(blocks.past.map(\.name) == ["Summer", "Winter"])
    }

    @Test("Today's T-READY leads with the block Program's ready slab leads with")
    func todayAndProgramLeadWithTheSameReadyBlock() {
        let (routine, _) = makeRoutine(sessions: ["Push A"])
        let ready = [
            unstarted("Summer", createdDaysAgo: 2, on: routine),
            unstarted("Spring", createdDaysAgo: 6, on: routine),
        ]
        let state = TodayState.resolve(
            openWorkouts: [], activeBlock: nil, resolution: .noBlock, finishedWorkouts: [],
            readyBlocks: ready, liveRoutines: [routine], sessions: [], now: now, calendar: calendar)

        #expect(state == .ready(ProgramBlocks(ready).lead!))
    }

    // MARK: - Routine sublines

    @Test("A routine's subline names the live blocks on it by name, and not the finished ones")
    func routineSublineNamesItsLiveBlocks() {
        let (routine, _) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"])
        _ = unstarted("Summer", createdDaysAgo: 2, on: routine)
        _ = unstarted("", createdDaysAgo: 1, on: routine)
        ended("Winter", daysAgo: 30).split = routine
        makeBlock(on: routine).name = "Spring"
        let (unused, _) = makeRoutine("Upper Lower", sessions: ["Upper"])

        #expect(RoutineSplitRow.subline(for: routine) == "3 sessions · used by Spring, Summer, Untitled Block")
        #expect(RoutineSplitRow.subline(for: unused) == "1 session")
    }

    // MARK: - Past blocks

    @Test("A past block reads its plan's weeks, the dates it ran and its counted workouts")
    func pastLineCountsItsWorkouts() throws {
        let block = try past("Summer", from: (2023, 9, 23), to: (2023, 11, 4), weeks: 6)
        makeWorkout(in: nil, daysAgo: 20, block: block)
        makeWorkout(in: nil, daysAgo: 13, block: block)
        makeWorkout(in: nil, daysAgo: 12, block: block, logged: false)

        let line = PastBlocksView.line(of: block, now: now, calendar: calendar)

        #expect(line.line == "6 weeks · Sep 23 - Nov 4 · 2 workouts")
        #expect(line.spoken == "6 weeks, Sep 23 to Nov 4, 2 workouts")
    }

    @Test("A block that ended in an earlier year carries its year, and its start's when that differs (D-127)")
    func pastLineShowsTheYearAcrossYears() throws {
        let lastYear = try past("Winter", from: (2022, 11, 4), to: (2022, 12, 1), weeks: 4)
        let acrossNewYear = try past("Winter", from: (2021, 12, 2), to: (2022, 1, 13), weeks: 6)
        let intoThisYear = try past("Winter", from: (2022, 12, 5), to: (2023, 1, 16), weeks: 6)

        #expect(PastBlocksView.line(of: lastYear, now: now, calendar: calendar).line
            == "4 weeks · Nov 4 - Dec 1, 2022 · 0 workouts")
        #expect(PastBlocksView.line(of: acrossNewYear, now: now, calendar: calendar).line
            == "6 weeks · Dec 2, 2021 - Jan 13, 2022 · 0 workouts")
        #expect(PastBlocksView.line(of: intoThisYear, now: now, calendar: calendar).line
            == "6 weeks · Dec 5 - Jan 16 · 0 workouts")
    }

    // MARK: - Fixtures

    /// A one-phase block that has not started, created `createdDaysAgo`
    /// days ago: ready on a routine with a session, a draft without one.
    private func unstarted(_ name: String, createdDaysAgo: Double, on routine: Split?) -> Block {
        let block = Block()
        ctx.insert(block)
        block.name = name
        block.split = routine
        block.startDate = now.addingTimeInterval(-createdDaysAgo * day)
        addPhase(weeks: 4, to: block)
        return block
    }

    /// A completed block that ended `daysAgo` days ago, after six weeks.
    private func ended(_ name: String, daysAgo: Double) -> Block {
        let block = Block()
        ctx.insert(block)
        block.name = name
        block.endDate = now.addingTimeInterval(-daysAgo * day)
        block.startDate = block.endDate!.addingTimeInterval(-42 * day)
        addPhase(weeks: 6, to: block)
        return block
    }

    /// A completed block that ran from noon UTC on `start` to noon UTC on `end`.
    private func past(
        _ name: String, from start: (Int, Int, Int), to end: (Int, Int, Int), weeks: Int
    ) throws -> Block {
        func noon(_ date: (Int, Int, Int)) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: date.0, month: date.1, day: date.2, hour: 12)))
        }
        let block = Block()
        ctx.insert(block)
        block.name = name
        block.startDate = try noon(start)
        block.endDate = try noon(end)
        addPhase(weeks: weeks, to: block)
        return block
    }

    private func addPhase(weeks: Int, to block: Block) {
        let phase = BlockPhase()
        ctx.insert(phase)
        phase.block = block
        phase.weeks = weeks
    }
}
