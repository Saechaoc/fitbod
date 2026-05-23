//
//  PRFixtures.swift
//  fitbodTests
//
//  Wave-2 plan 06-02 — deterministic multi-exercise multi-intent PR
//  fixture used by PRDetectorTests. Seeds:
//
//    Bench Press × strength × 2 sessions (W0, W1)
//      W0: 100 × 5  (top set)        → weight/reps/volume/e1RM @ strength
//      W1: 105 × 5  (new weight PR)  → tops weight, volume, e1RM
//
//    Bench Press × hypertrophy × 1 session (W2)
//      W2: 80  × 10 (top set)        → first hypertrophy bucket entry
//
//    Squat × strength × 1 session (W0)
//      W0: 140 × 3  (top set)        → first squat entry
//
//  Exposes the hand-computed expected PR table as `expectedPRs` so
//  PRDetectorTests can assert PRDetector.buildTable(...) matches
//  every (exerciseID, intent, kind, bucket) tuple.
//

import Foundation
import SwiftData
@testable import fitbod

@MainActor
enum PRFixtures {

    struct SeedResult {
        let benchID: UUID
        let squatID: UUID
        /// (exerciseID, intent, kind, bucket, expectedValue) — value is
        /// weight for .weight, reps for .reps, weight*reps for .volume,
        /// and OneRepMax.estimate(weight, reps) for .e1RM.
        let expected: [(UUID, Intent, PRKind, RepBucket, Double)]
    }

    static func seedKnownPRHistory(ctx: ModelContext) throws -> SeedResult {
        let bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        let squat = Exercise(
            name: "Back Squat",
            canonicalName: "back squat",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        ctx.insert(squat)

        // Week 0 — Bench strength @ 100 × 5
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [
                (weight: 100, reps: 5, rpe: 8.0, isWarmup: false, isComplete: true),
            ]
        )

        // Week 1 — Bench strength @ 105 × 5 (tops weight + volume + e1RM)
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_604_800), // +7 days
            exercise: bench,
            intentRaw: Intent.strength.rawValue,
            sets: [
                (weight: 105, reps: 5, rpe: 8.5, isWarmup: false, isComplete: true),
            ]
        )

        // Week 2 — Bench hypertrophy @ 80 × 10 (new bucket entry)
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_701_209_600), // +7 more days
            exercise: bench,
            intentRaw: Intent.hypertrophy.rawValue,
            sets: [
                (weight: 80, reps: 10, rpe: 8.0, isWarmup: false, isComplete: true),
            ]
        )

        // Week 0 — Squat strength @ 140 × 3 (first squat entry)
        try SessionFixtures.makeCompletedSession(
            ctx: ctx,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: squat,
            intentRaw: Intent.strength.rawValue,
            sets: [
                (weight: 140, reps: 3, rpe: 8.0, isWarmup: false, isComplete: true),
            ]
        )

        let benchE1RM5 = OneRepMax.estimate(weight: 105, reps: 5) ?? 0
        let benchE1RM10 = OneRepMax.estimate(weight: 80, reps: 10) ?? 0
        let squatE1RM3 = OneRepMax.estimate(weight: 140, reps: 3) ?? 0

        let expected: [(UUID, Intent, PRKind, RepBucket, Double)] = [
            // Bench × strength × strength bucket (reps 1..6) — Wave 1 wins.
            (bench.id, .strength, .weight, .strength, 105),
            (bench.id, .strength, .reps, .strength, 5),
            (bench.id, .strength, .volume, .strength, 105.0 * 5),
            (bench.id, .strength, .e1RM, .strength, benchE1RM5),

            // Bench × hypertrophy × hypertrophy bucket — single entry.
            (bench.id, .hypertrophy, .weight, .hypertrophy, 80),
            (bench.id, .hypertrophy, .reps, .hypertrophy, 10),
            (bench.id, .hypertrophy, .volume, .hypertrophy, 80.0 * 10),
            (bench.id, .hypertrophy, .e1RM, .hypertrophy, benchE1RM10),

            // Squat × strength × strength bucket — single entry.
            (squat.id, .strength, .weight, .strength, 140),
            (squat.id, .strength, .reps, .strength, 3),
            (squat.id, .strength, .volume, .strength, 140.0 * 3),
            (squat.id, .strength, .e1RM, .strength, squatE1RM3),
        ]

        return SeedResult(benchID: bench.id, squatID: squat.id, expected: expected)
    }
}
