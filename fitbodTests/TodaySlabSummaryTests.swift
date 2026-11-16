import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct TodaySlabSummaryTests: ProgramFixtures {
    let ctx: ModelContext
    let bench: Exercise
    let now = Self.tuesdayEvening
    let calendar = Self.utcCalendar

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Self.makeBench(in: ctx)
    }

    @Test func doneOmitsUnknownDurationAndZeroRecords() {
        let workout = makeWorkout(in: nil, daysAgo: 0)
        #expect(DoneTodaySlab.caption(for: workout, prCount: 0) == "1 set")
        workout.totalDurationSeconds = 47 * 60
        #expect(DoneTodaySlab.caption(for: workout, prCount: 2) == "47M · 1 set · 2 PRS")
    }

    /// T-DONE's and T-REST's next line at `date`, and the session the sheet marks NEXT then.
    private func nextLine(block: Block?, routine: Split, at date: Date) throws -> (line: String?, sheet: String?) {
        let finished = try finishedWorkouts()
        let resolution = resolution(for: block, at: date)
        let line = TodayView.upNextLabel(
            block: block, resolution: resolution, finished: finished,
            liveRoutines: [routine], sessions: [], now: date, calendar: calendar)
        let sheet = SessionSheetContent(
            liveRoutines: [routine], sessions: [], block: block, resolution: resolution,
            finished: finished, now: date, calendar: calendar)
        return (line, sheet.groups.flatMap(\.rows).first(where: \.isNext)?.session.name)
    }

    @Test func weeklyNextLineNamesTheNextTrainingDayOnARestDayAndOnceTrained() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A"])
        let block = makeBlock(on: routine, weekly: [3, 5]) // Tuesday, Thursday
        #expect(try nextLine(block: block, routine: routine, at: now + day) == ("Next: Pull A · Thursday", "Pull A"))
        #expect(try nextLine(block: block, routine: routine, at: now + 3 * day) == ("Next: Push A · Tuesday", "Push A"))
        makeWorkout(in: slots[0], daysAgo: 0, block: block)
        #expect(try nextLine(block: block, routine: routine, at: now) == ("Next: Pull A · Thursday", "Pull A"))
    }

    @Test func rotationNextLineKeepsNextAfterAnUnslottedWorkout() throws {
        let (routine, slots) = makeRoutine(sessions: ["Push A", "Pull A", "Legs A"], empty: ["Legs A"])
        let block = makeBlock(on: routine)
        makeWorkout(in: slots[0], daysAgo: 1, block: block)
        makeWorkout(in: nil, daysAgo: 0, block: block)
        #expect(try nextLine(block: block, routine: routine, at: now) == ("Next up: Pull A", "Pull A"))
        makeWorkout(in: slots[1], daysAgo: 0, block: block)
        #expect(try nextLine(block: block, routine: routine, at: now) == (nil, nil)) // Legs A has no exercises
        #expect(try nextLine(block: nil, routine: routine, at: now) == ("Next up: Push A · Push Pull Legs", "Push A"))
    }

    @Test func readyCountsItsActualPhasesAndWeeks() {
        let routine = makeRoutine()
        let block = makeBlock(on: routine)
        for (index, weeks) in [3, 2, 1].enumerated() {
            let phase = BlockPhase()
            ctx.insert(phase)
            phase.block = block
            phase.orderIndex = index
            phase.weeks = weeks
        }
        #expect(ReadyBlockCard.summary(of: block) == "6 weeks · 3 phases · Push Pull Legs")
    }
}
