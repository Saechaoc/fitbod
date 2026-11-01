//
//  ContributingExercisesOrderTests.swift
//  fitbodTests
//
//  T109, finding F210: a muscle's CONTRIBUTING EXERCISES rows sort by
//  weighted sets, most first. Rows with exactly the same weighted sets go
//  by name, then by id, so the order never changes between renders, while
//  rows that only read the same count keep their weighted order
//  (tradeoffs.md "Contributing exercises order"). Each case orders the
//  rows from both starting orders, as a dictionary can hand them over.
//

import Foundation
import Testing
@testable import fitbod

@Suite("Contributing exercises order")
struct ContributingExercisesOrderTests {

    @Test("Rows with the same weighted sets sort by name")
    func exactTieSortsByName() {
        let bench = row("Barbell Bench Press - Medium Grip", direct: 3)
        let incline = row("Incline Dumbbell Press", direct: 3)
        #expect(bench.trailingCopy == "3 sets" && incline.trailingCopy == "3 sets")

        for rows in [[bench, incline], [incline, bench]] {
            #expect(names(rows) == ["Barbell Bench Press - Medium Grip", "Incline Dumbbell Press"])
        }
    }

    @Test("More weighted sets stay first when both rows read the same count")
    func nearTieKeepsWeightedOrder() {
        let incline = row("Incline Dumbbell Press", direct: 3)
        let shoulderPress = row("Barbell Shoulder Press", direct: 2.5)
        #expect(incline.trailingCopy == "3 sets" && shoulderPress.trailingCopy == "3 sets")

        for rows in [[incline, shoulderPress], [shoulderPress, incline]] {
            #expect(names(rows) == ["Incline Dumbbell Press", "Barbell Shoulder Press"])
        }
    }

    @Test("Rows with the same weighted sets and name sort by id")
    func sameNameSortsByID() throws {
        let first = row("Cable Fly", direct: 2, id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")))
        let second = row("Cable Fly", direct: 2, id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")))

        for rows in [[first, second], [second, first]] {
            #expect(rows.sorted(by: ContributingExercise.precedes).map(\.exerciseID) == [first.exerciseID, second.exerciseID])
        }
    }

    // MARK: - Helpers

    private func row(_ name: String, direct: Double, id: UUID = UUID()) -> ContributingExercise {
        ContributingExercise(exerciseID: id, exerciseName: name, direct: direct, indirect: 0)
    }

    private func names(_ rows: [ContributingExercise]) -> [String] {
        rows.sorted(by: ContributingExercise.precedes).map(\.exerciseName)
    }
}
