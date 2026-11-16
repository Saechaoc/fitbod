//
//  VolumeListTests.swift
//  fitbodTests
//
//  RM-017: Volume lists the muscles trained this week with their bars and
//  folds the untrained ones into one "n muscles not trained yet" row; the
//  heatmap names the week by its dates.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("VolumeList")
struct VolumeListTests {

    private func muscle(_ slug: String, _ name: String) -> MuscleGroup {
        MuscleGroup(slug: slug, displayName: name)
    }

    private func sets(_ direct: Double, indirect: Double = 0) -> WeightedSetTotal {
        WeightedSetTotal(directSets: direct, indirectSets: indirect)
    }

    @Test("trained muscles keep their bars, untrained ones fold, each in name order")
    func trainedAndUntrainedSplit() {
        let muscles = [
            muscle("quadriceps", "Quadriceps"), muscle("hamstrings", "Hamstrings"), muscle("chest", "Chest"),
            muscle("calves", "Calves"), muscle("neck", "Neck"), muscle("front delts", "Front Delts"),
            muscle("abductors", "Abductors"),
        ]
        let list = FatigueSurfaceView.listedMuscles(
            muscles,
            thisWeek: [
                "hamstrings": sets(2), "chest": sets(6, indirect: 1.5),
                // Sets that round to 0 read NOT TRAINED, so they fold too.
                "calves": sets(0, indirect: 0.25),
                // The front delts' MEV is 0, so they list only once trained.
                "front delts": sets(0, indirect: 3),
            ],
            // Abductors have no target with an MEV above 0.
            targetedSlugs: ["quadriceps", "hamstrings", "chest", "calves", "neck"]
        )
        #expect(list.trained.map(\.slug) == ["chest", "front delts", "hamstrings"])
        #expect(list.untrained.map(\.slug) == ["calves", "neck", "quadriceps"])
    }

    @Test("a fresh week folds every targeted muscle into the one row")
    func freshWeekFoldsEverything() {
        let muscles = [muscle("chest", "Chest"), muscle("lats", "Lats"), muscle("front delts", "Front Delts")]
        let list = FatigueSurfaceView.listedMuscles(muscles, thisWeek: [:], targetedSlugs: ["chest", "lats"])
        #expect(list.trained.isEmpty)
        #expect(list.untrained.map(\.slug) == ["chest", "lats"])
    }

    @Test(
        "the heatmap names the week's seven days",
        arguments: [
            (2026, 11, 9, "NOV 9–15"),
            // A week that starts on Sunday.
            (2026, 11, 8, "NOV 8–14"),
            (2026, 10, 26, "OCT 26–NOV 1"),
            // US clocks go back on its first day; six days of seconds would end on the 6th.
            (2026, 11, 1, "NOV 1–7"),
        ]
    )
    func weekRange(year: Int, month: Int, day: Int, expected: String) throws {
        // New York has daylight saving, so the clock-change case proves the
        // day math on any machine: Pacific here, where its midnight falls the
        // evening before, or UTC on CI.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let weekStart = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        #expect(FatigueSurfaceView.weekRange(weekStart: weekStart, calendar: calendar) == expected)
    }
}
