//
//  PRDetectorTests.swift
//  fitbodTests
//
//  Wave-2 plan 06-02 — PRDetector kernel coverage (PROG-05 + PROG-08 +
//  CONTEXT D-10..D-17). Six @Test functions:
//
//    1. buildTableMatchesExpectedPRs — runs PRFixtures.seedKnownPRHistory
//       and asserts every expected (exerciseID, intent, kind, bucket)
//       slot resolves to the hand-computed value
//    2. singleSetSingleKindWins — a set that only beats weight returns
//       exactly {.weight}
//    3. singleSetStacksMultipleKinds — a set that beats weight + volume +
//       e1RM returns all three (D-16 multi-PR stacking)
//    4. tableMutatesInPlace — calling check twice with the same set
//       returns empty the second time
//    5. tiesAreNotPRs — a tie returns empty (CONTEXT D-16 strict-> rule)
//    6. highRepSuppressesE1RM — a 12-rep set never returns .e1RM even
//       when it tops the other PR kinds
//
//  Each test acquires a fresh in-memory baseline ModelContainer via
//  the existing fitbodTests/TestSupport/InMemoryContainer.makeCurrent()
//  helper. `.serialized` because SwiftData ModelContainer setup is
//  not safe to parallelize across @Test instances.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PRDetector (PROG-05 + PROG-08 + CONTEXT D-10..D-17)", .serialized)
struct PRDetectorTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    /// Collect every SetEntry in the context — used by buildTable tests.
    private func allSets(in ctx: ModelContext) throws -> [SetEntry] {
        try ctx.fetch(FetchDescriptor<SetEntry>())
    }

    // MARK: - 1. buildTable matches expected fixture PRs

    @Test("buildTableMatchesExpectedPRs — every expected slot resolves")
    func buildTableMatchesExpectedPRs() throws {
        let ctx = try makeContext()
        let seed = try PRFixtures.seedKnownPRHistory(ctx: ctx)
        let all = try allSets(in: ctx)
        let table = PRDetector.buildTable(from: all)

        for (exerciseID, intent, kind, bucket, expectedValue) in seed.expected {
            let record = try #require(
                table.record(exerciseID: exerciseID, intent: intent, kind: kind, bucket: bucket),
                "Missing PR for (\(exerciseID), \(intent), \(kind), \(bucket))"
            )
            switch kind {
            case .weight:
                #expect(abs(record.weight - expectedValue) < 0.0001)
            case .reps:
                #expect(record.reps == Int(expectedValue))
            case .volume:
                let actualVol = record.weight * Double(record.reps)
                #expect(abs(actualVol - expectedValue) < 0.0001)
            case .e1RM:
                let actualE1RM = OneRepMax.estimate(weight: record.weight, reps: record.reps) ?? 0
                #expect(abs(actualE1RM - expectedValue) < 0.01)
            }
        }
    }

    // MARK: - 2. single PR kind

    @Test("singleSetSingleKindWins — a set that only beats weight returns {.weight}")
    func singleSetSingleKindWins() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)

        // Prior baseline: 100 × 5 (weight 100, reps 5, vol 500, e1RM 112.5)
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true)]
        )
        let initial = try allSets(in: ctx)
        var table = PRDetector.buildTable(from: initial)

        // New set: 101 × 4 — tops weight (101 > 100) but NOT reps (4 < 5),
        // NOT volume (404 < 500), NOT e1RM (Brzycki 4-rep at 101 ≈ 110.18
        // vs old 112.5).
        let newSession = try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_604_800),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 101, reps: 4, rpe: 8.5, isWarmup: false, isComplete: true)]
        )
        let newSet = try #require(newSession.exercises?.first?.sets?.first)

        let topped = PRDetector.check(set: newSet, against: &table)
        #expect(topped == [.weight])
    }

    // MARK: - 3. multi-PR stacking

    @Test("singleSetStacksMultipleKinds — D-16 multi-PR stacking from one set")
    func singleSetStacksMultipleKinds() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)

        // Baseline 100 × 5.
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true)]
        )
        let initial = try allSets(in: ctx)
        var table = PRDetector.buildTable(from: initial)

        // New set 110 × 6 — beats weight (110>100), reps (6>5), volume (660>500),
        // e1RM (Brzycki 110×36/31 ≈ 127.74 > 112.5).
        let newSession = try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_604_800),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 110, reps: 6, rpe: 9.0, isWarmup: false, isComplete: true)]
        )
        let newSet = try #require(newSession.exercises?.first?.sets?.first)

        let topped = PRDetector.check(set: newSet, against: &table)
        #expect(topped == Set([.weight, .reps, .volume, .e1RM]))
    }

    // MARK: - 4. in-place mutation

    @Test("tableMutatesInPlace — calling check twice with the same set returns empty")
    func tableMutatesInPlace() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)
        let session = try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true)]
        )
        let set = try #require(session.exercises?.first?.sets?.first)

        var table = PRTable()
        let firstResult = PRDetector.check(set: set, against: &table)
        // First call: empty table → all 4 kinds top.
        #expect(firstResult == Set([.weight, .reps, .volume, .e1RM]))

        let secondResult = PRDetector.check(set: set, against: &table)
        // Same set against the updated table — ties everywhere → empty.
        #expect(secondResult.isEmpty)
    }

    // MARK: - 5. ties are not PRs

    @Test("tiesAreNotPRs — equal-value sets return empty (strict-> rule)")
    func tiesAreNotPRs() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true)]
        )
        let initial = try allSets(in: ctx)
        var table = PRDetector.buildTable(from: initial)

        // Identical-value set: 100 × 5 again → no PR.
        let tieSession = try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_604_800),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [(weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true)]
        )
        let tieSet = try #require(tieSession.exercises?.first?.sets?.first)
        #expect(PRDetector.check(set: tieSet, against: &table).isEmpty)
    }

    // MARK: - 6. high-rep e1RM suppression

    @Test("highRepSuppressesE1RM — 12-rep set never returns .e1RM")
    func highRepSuppressesE1RM() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)

        // Empty table — any working set tops weight/reps/volume.
        var table = PRTable()
        let session = try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.hypertrophy.rawValue,
            sets: [(weight: 60, reps: 12, rpe: 7.0, isWarmup: false, isComplete: true)]
        )
        let set = try #require(session.exercises?.first?.sets?.first)

        let topped = PRDetector.check(set: set, against: &table)
        // High-rep set in highRep bucket → tops weight/reps/volume but NOT e1RM.
        #expect(topped.contains(.weight))
        #expect(topped.contains(.reps))
        #expect(topped.contains(.volume))
        #expect(topped.contains(.e1RM) == false)
    }
}
