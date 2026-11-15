//
//  WeeklyTonnagePhaseFilterTests.swift
//  fitbodTests
//
//  RM-023, finding D-28: Weekly Tonnage's phase chips filter. A set counts
//  in the phase its workout's block was in on the day the workout started;
//  a set outside a block, or past its block's plan, is in no phase. No chip
//  keeps every set. The week detail filters the same way, so a bar and the
//  week it opens still total the same.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Weekly Tonnage phase chips (RM-023)", .serialized)
struct WeeklyTonnagePhaseFilterTests {

    @Test("A phase chip keeps the sets of workouts that ran in that phase; none keeps every set")
    func keepsTheSetsOfTheChosenPhases() throws {
        let week = try PhasedWeek()
        let all = week.sets

        #expect(WeeklyTonnageAggregator.sets(all, inPhases: []).count == all.count)
        #expect(Set(WeeklyTonnageAggregator.sets(all, inPhases: ["accumulation"]).map(\.weight)) == [100])
        #expect(Set(WeeklyTonnageAggregator.sets(all, inPhases: ["deload"]).map(\.weight)) == [60])
        #expect(Set(WeeklyTonnageAggregator.sets(all, inPhases: ["accumulation", "deload"]).map(\.weight)) == [100, 60])
        #expect(WeeklyTonnageAggregator.sets(all, inPhases: ["peak"]).isEmpty)
    }

    @Test("A filtered bar and the week it opens total the same")
    func aBarAndItsWeekTotalTheSame() throws {
        let week = try PhasedWeek()
        let deload = WeeklyTonnageAggregator.sets(week.sets, inPhases: ["deload"])
        let bars = WeeklyTonnageAggregator.aggregate(sets: deload, weekStartsMonday: true, selectedMuscleIDs: [])
        #expect(bars.count == 1)
        let bar = try #require(bars.first)
        #expect(bar.weekStart == week.monday)
        #expect(bar.totalTonnage == 3 * 60 * 5)

        let detail = WeekDetailGrouping.detail(counting: deload, inWeekStarting: bar.weekStart, weekStartsMonday: true)
        #expect(detail.workouts.count == 1)
        #expect(detail.total == bar.totalTonnage)
        let whole = WeekDetailGrouping.detail(counting: week.sets, inWeekStarting: bar.weekStart, weekStartsMonday: true)
        #expect(whole.total > bar.totalTonnage, "The accumulation and unblocked workouts of the same week must drop out")
    }

    /// A block started on Wednesday 4 March 2026 with a week of accumulation
    /// then a week of deload, and the chart week from Monday 9 March, which
    /// holds the end of the first and the start of the second: a workout
    /// on Tuesday at 100 (accumulation), one on Thursday at 60 (deload), one
    /// that Thursday in no block at 80, and one the next Wednesday at 40,
    /// past the plan. Three sets of 5 each.
    private struct PhasedWeek {
        let context: ModelContext
        let monday: Date
        let sets: [SetEntry]

        @MainActor
        init() throws {
            context = ModelContext(try InMemoryContainer.makeCurrent())
            let calendar = Calendar.current
            func day(_ day: Int, hour: Int = 0) -> Date {
                calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
            }
            monday = day(9)

            let block = Block()
            context.insert(block)
            block.name = "Phased"
            block.startDate = day(4)
            block.isActive = true
            for (index, kind) in [BlockPhaseKind.accumulation, .deload].enumerated() {
                let phase = BlockPhase()
                context.insert(phase)
                phase.block = block
                phase.orderIndex = index
                phase.nameRaw = kind.rawValue
                phase.weeks = 1
            }

            let bench = Exercise(name: "Bench Press", canonicalName: "bench press", equipmentRaw: "barbell", mechanicRaw: "compound")
            context.insert(bench)
            var sets: [SetEntry] = []
            for (start, weight, inBlock) in [(day(10, hour: 9), 100.0, true), (day(12, hour: 9), 60, true), (day(12, hour: 18), 80, false), (day(18, hour: 9), 40, true)] {
                let workout = Session()
                context.insert(workout)
                workout.startedAt = start
                workout.completedAt = start.addingTimeInterval(3600)
                workout.block = inBlock ? block : nil
                let entry = SessionExercise()
                context.insert(entry)
                entry.session = workout
                entry.exercise = bench
                for index in 0..<3 {
                    let set = SetEntry()
                    context.insert(set)
                    set.sessionExercise = entry
                    set.orderIndex = index
                    set.weight = weight
                    set.reps = 5
                    set.isComplete = true
                    set.completedAt = start.addingTimeInterval(Double(index) * 180)
                    sets.append(set)
                }
            }
            self.sets = sets.sorted { $0.completedAt < $1.completedAt }
        }
    }
}
