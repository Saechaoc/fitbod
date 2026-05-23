//
//  SeriesBuilderTests.swift
//  fitbodTests
//
//  Wave-3 plan 06-05 — pure-function tests for SeriesBuilder.
//  Five @Test functions:
//
//    1. emitsTopSetAndAvgPerSession — 2 points per session w/ usable e1RM
//    2. excludesWarmupAndIncompleteSets — non-working/incomplete filtered out
//    3. skipsSessionWhenAllRepsAboveTen — PROG-02 suppression empties session
//    4. topSetByE1RMTiebreaker — D-05 ordering verified by example
//    5. allSetAvgIsArithmeticMean — D-06 explicit-mean correctness
//
//  Hermetic via InMemoryContainer.makeCurrent() — SwiftData @Model
//  classes need a ModelContext to be valid even when SeriesBuilder
//  itself is pure (it reads properties off the @Model rows).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SeriesBuilder (PROG-03 + CONTEXT D-05/D-06)", .serialized)
struct SeriesBuilderTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    /// Build a single SessionExercise with the provided sets and
    /// return the SessionExercise (parent Session also inserted).
    private func makeSessionExercise(
        in ctx: ModelContext,
        startedAt: Date,
        intentRaw: String,
        sets: [(weight: Double, reps: Int, isWarmup: Bool, isComplete: Bool, setTypeRaw: String)]
    ) -> SessionExercise {
        let exercise = Exercise(
            name: "Test", canonicalName: "test",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        let session = Session()
        session.startedAt = startedAt
        session.intentRaw = intentRaw
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        ctx.insert(exercise); ctx.insert(session); ctx.insert(se)

        for (i, tup) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = tup.weight
            entry.reps = tup.reps
            entry.isWarmup = tup.isWarmup
            entry.isComplete = tup.isComplete
            entry.setTypeRaw = tup.setTypeRaw
            entry.completedAt = startedAt.addingTimeInterval(Double(i) * 60)
            ctx.insert(entry)
        }
        return se
    }

    // MARK: - 1. emits both points

    @Test("emitsTopSetAndAvgPerSession — 2 points per session")
    func emitsTopSetAndAvgPerSession() throws {
        let ctx = try makeContext()
        let se = makeSessionExercise(
            in: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            intentRaw: Intent.strength.rawValue,
            sets: [
                (100, 5, false, true, "working"),
                (95,  5, false, true, "working"),
            ]
        )
        let points = SeriesBuilder.buildPoints(from: [se])
        #expect(points.count == 2)
        #expect(points.contains(where: { $0.kind == .topSet }))
        #expect(points.contains(where: { $0.kind == .allSetAvg }))
    }

    // MARK: - 2. excludes warmup + incomplete + non-working

    @Test("excludesWarmupAndIncompleteSets — only working+complete count")
    func excludesWarmupAndIncompleteSets() throws {
        let ctx = try makeContext()
        let se = makeSessionExercise(
            in: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            intentRaw: Intent.strength.rawValue,
            sets: [
                (60,  5, true,  true,  "warmup"),   // excluded — warmup
                (100, 5, false, false, "working"),  // excluded — incomplete
                (80,  8, false, true,  "drop"),     // excluded — drop set
                (100, 5, false, true,  "working"),  // INCLUDED
            ]
        )
        let points = SeriesBuilder.buildPoints(from: [se])
        // Only one working+complete set → topSet == allSetAvg == 100×5 e1RM
        #expect(points.count == 2)
        let topSet = try #require(points.first(where: { $0.kind == .topSet }))
        let avg = try #require(points.first(where: { $0.kind == .allSetAvg }))
        let expectedE1RM = try #require(OneRepMax.estimate(weight: 100, reps: 5))
        #expect(abs(topSet.e1RM - expectedE1RM) < 0.001)
        #expect(abs(avg.e1RM - expectedE1RM) < 0.001)
    }

    // MARK: - 3. all > 10 reps suppresses session entirely

    @Test("skipsSessionWhenAllRepsAboveTen — PROG-02 suppression empties session")
    func skipsSessionWhenAllRepsAboveTen() throws {
        let ctx = try makeContext()
        let se = makeSessionExercise(
            in: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            intentRaw: Intent.hypertrophy.rawValue,
            sets: [
                (50, 15, false, true, "working"),
                (45, 12, false, true, "working"),
            ]
        )
        let points = SeriesBuilder.buildPoints(from: [se])
        #expect(points.isEmpty)
    }

    // MARK: - 4. top-set D-05 tiebreaker

    @Test("topSetByE1RMTiebreaker — D-05 picks highest e1RM not highest weight")
    func topSetByE1RMTiebreaker() throws {
        let ctx = try makeContext()
        // 100×5 → e1RM 112.5
        // 105×1 → e1RM 105.0
        // 95×6  → e1RM ≈ 110.32
        // Top set per D-05 (e1RM-first) = 100×5.
        let se = makeSessionExercise(
            in: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            intentRaw: Intent.strength.rawValue,
            sets: [
                (105, 1, false, true, "working"),
                (100, 5, false, true, "working"),
                (95,  6, false, true, "working"),
            ]
        )
        let points = SeriesBuilder.buildPoints(from: [se])
        let topSet = try #require(points.first(where: { $0.kind == .topSet }))
        let expectedE1RM = try #require(OneRepMax.estimate(weight: 100, reps: 5))
        #expect(abs(topSet.e1RM - expectedE1RM) < 0.001)
    }

    // MARK: - 5. arithmetic mean for allSetAvg

    @Test("allSetAvgIsArithmeticMean — D-06 explicit-mean correctness")
    func allSetAvgIsArithmeticMean() throws {
        let ctx = try makeContext()
        // 100×5 → 112.5 ; 100×4 → 100 * 36/33 ≈ 109.09 ; 100×3 → 100 * 36/34 ≈ 105.88
        // Mean = (112.5 + 109.09 + 105.88) / 3 ≈ 109.16
        let se = makeSessionExercise(
            in: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            intentRaw: Intent.strength.rawValue,
            sets: [
                (100, 5, false, true, "working"),
                (100, 4, false, true, "working"),
                (100, 3, false, true, "working"),
            ]
        )
        let points = SeriesBuilder.buildPoints(from: [se])
        let avg = try #require(points.first(where: { $0.kind == .allSetAvg }))
        let e1 = try #require(OneRepMax.estimate(weight: 100, reps: 5))
        let e2 = try #require(OneRepMax.estimate(weight: 100, reps: 4))
        let e3 = try #require(OneRepMax.estimate(weight: 100, reps: 3))
        let expected = (e1 + e2 + e3) / 3.0
        #expect(abs(avg.e1RM - expected) < 0.001)
    }
}
