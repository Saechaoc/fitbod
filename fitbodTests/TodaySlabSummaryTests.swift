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
