//
//  ProgramViewFidelityTests.swift
//  fitbodTests
//
//  Program's rules that compute something: which block leads and the
//  order of the rest (RM-011, O-6), and the template rows. The look itself
//  is checked on the simulator, not pinned in tests.
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

    // MARK: - Template rows

    @Test("Each template row shows only its template's weeks, name and phases")
    func templateRowsComeFromTheirTemplates() {
        let rows = ProgramView.templateRows

        #expect(rows.map(\.template.name) == BlockTemplates.catalog.map(\.name))
        for row in rows {
            let weeks = row.template.phases.reduce(0) { $0 + $1.weeks }
            let phases = row.template.phases.map { "\($0.kind.shortLabel) \($0.weeks)" }
            #expect(row.weeks == "\(weeks)W")
            #expect(row.title == row.template.name)
            #expect(row.phases == phases.joined(separator: " · "))
        }
        #expect(rows.map(\.weeks) == ["8W", "8W", "8W", "4W"])
        #expect(rows.map(\.phases) == [
            "ACCUM 5 · INTNS 2 · DELOAD 1",
            "ACCUM 4 · INTNS 2 · REAL 1 · DELOAD 1",
            "ACCUM 3 · INTNS 3 · REAL 1 · DELOAD 1",
            "ACCUM 1 · INTNS 1 · REAL 1 · DELOAD 1",
        ])
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

    private func addPhase(weeks: Int, to block: Block) {
        let phase = BlockPhase()
        ctx.insert(phase)
        phase.block = block
        phase.weeks = weeks
    }
}
