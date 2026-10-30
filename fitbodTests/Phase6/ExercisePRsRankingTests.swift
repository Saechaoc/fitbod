//
//  ExercisePRsRankingTests.swift
//  fitbodTests
//
//  T13, review item 31 — the PR list's bucket rows (PRBucketRanking):
//  a distinct set is one exercise, weight and reps, kept from when it was
//  first logged; rows are ranked by the bucket's measure across exercises,
//  at most three per exercise.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PR list bucket ranking", .serialized)
struct ExercisePRsRankingTests {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    /// One logged set: minutes after `start`, weight, reps and RPE.
    private typealias Logged = (minute: Int, weight: Double, reps: Int, rpe: Double?)

    /// Logs each exercise's sets in its own workout and returns every set.
    private func log(_ plan: [(name: String, sets: [Logged])], in ctx: ModelContext) -> [SetEntry] {
        var entries: [SetEntry] = []
        for (name, sets) in plan {
            let exercise = Exercise(
                name: name, canonicalName: name.lowercased(),
                equipmentRaw: "barbell", mechanicRaw: "compound"
            )
            ctx.insert(exercise)
            let workout = Session()
            ctx.insert(workout)
            workout.startedAt = start
            let logged = SessionExercise()
            ctx.insert(logged)
            logged.session = workout
            logged.exercise = exercise
            for (index, set) in sets.enumerated() {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = logged
                entry.orderIndex = index
                entry.weight = set.weight
                entry.reps = set.reps
                entry.rpe = set.rpe
                entry.isComplete = true
                entry.completedAt = start.addingTimeInterval(Double(set.minute) * 60)
                entries.append(entry)
            }
        }
        return entries
    }

    private func describe(_ rows: [SetEntry]) -> [String] {
        rows.map { "\(PRBucketRanking.exerciseName($0)) \($0.weight)x\($0.reps)" }
    }

    @Test("dedupesTheSameSetKeepingTheFirstLogged — one row per exercise, weight and reps")
    func dedupesTheSameSetKeepingTheFirstLogged() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let sets = log([
            ("Bench", [(30, 100, 5, 8), (10, 100, 5, 9), (20, 100, 5, nil), (40, 95, 5, 8)]),
            ("Squat", [(50, 100, 5, 7)]),
        ], in: ctx)

        let rows = PRBucketRanking.rows(kind: .weight, sets: sets)

        #expect(describe(rows) == ["Bench 100.0x5", "Squat 100.0x5", "Bench 95.0x5"])
        let bench = try #require(rows.first)
        #expect(bench.completedAt == start.addingTimeInterval(10 * 60))
        #expect(bench.rpe == 9)
    }

    @Test("ranksAcrossExercisesThreePerExercise — the measure orders every row, three per exercise")
    func ranksAcrossExercisesThreePerExercise() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let sets = log([
            ("Bench", [(0, 107.5, 2, 9.5), (1, 105, 3, 9), (2, 102.5, 4, 8), (3, 100, 5, 8)]),
            ("Squat", [(4, 160, 3, 9), (5, 150, 3, 9), (6, 145, 4, 8.5), (7, 140, 5, 8)]),
        ], in: ctx)

        #expect(describe(PRBucketRanking.rows(kind: .weight, sets: sets)) == [
            "Squat 160.0x3", "Squat 150.0x3", "Squat 145.0x4",
            "Bench 107.5x2", "Bench 105.0x3", "Bench 102.5x4",
        ])
        // Reps: more reps first; at equal reps, more weight first.
        #expect(describe(PRBucketRanking.rows(kind: .reps, sets: sets)) == [
            "Squat 140.0x5", "Bench 100.0x5", "Squat 145.0x4",
            "Bench 102.5x4", "Squat 160.0x3", "Bench 105.0x3",
        ])
        // Volume: weight x reps.
        #expect(describe(PRBucketRanking.rows(kind: .volume, sets: sets)) == [
            "Squat 140.0x5", "Squat 145.0x4", "Bench 100.0x5",
            "Squat 160.0x3", "Bench 102.5x4", "Bench 105.0x3",
        ])
    }

    @Test("e1RMSkipsSetsWithoutAnEstimate — sets above 10 reps have no e1RM row")
    func e1RMSkipsSetsWithoutAnEstimate() throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        let sets = log([
            ("Bench", [(0, 75, 12, 9), (1, 85, 8, 8), (2, 80, 10, 9)]),
        ], in: ctx)

        let rows = PRBucketRanking.rows(kind: .e1RM, sets: sets)

        #expect(describe(rows) == ["Bench 85.0x8", "Bench 80.0x10"])
    }
}
