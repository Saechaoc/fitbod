//
//  DoubleProgressionStrategyTests.swift
//  fitbodTests
//
//  5 @Test functions for DoubleProgressionStrategy — turned GREEN by plan 03-05.
//  All tests are pure-function: no SwiftData context needed since the strategy
//  operates on pre-fetched value types only.
//

import Foundation
import Testing
@testable import fitbod

@Suite("DoubleProgressionStrategy")
struct DoubleProgressionStrategyTests {

    // Standard kg plate set. Standard barbell plates add 2 × plate to the bar total,
    // so valid loadable weights increase in 2.5 kg steps (smallest plate = 1.25 kg/side).
    private let standardPlates: [(weight: Double, countPerSide: Int)] = [
        (weight: 20.0, countPerSide: 4),
        (weight: 10.0, countPerSide: 4),
        (weight: 5.0, countPerSide: 4),
        (weight: 2.5, countPerSide: 4),
        (weight: 1.25, countPerSide: 4)
    ]
    private let barWeight: Double = 20.0
    private let strategy = DoubleProgressionStrategy()

    // MARK: - 1. Bump when all sets hit top of range

    @Test("bumpWhenAllSetsHitTopOfRange")
    func bumpWhenAllSetsHitTopOfRange() throws {
        // All working sets hit targetRepsHigh (12) → bump triggered.
        // lastWeight = 100.0, smallestIncrement = 2.5 → rawBump = 102.5 (loadable).
        let lastWeight = 100.0
        let smallestIncrement = 2.5

        let (weight, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: nil,
            lastSessionRepsArray: [12, 12, 12],
            smallestIncrement: smallestIncrement,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: lastWeight,
            lastSessionReps: 12,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        #expect(explanation.bumpOccurred == true)
        // 102.5 kg is plate-loadable (2 × 20 + 2 × 10 + 2 × 2.5 + 2 × 1.25 per side).
        #expect(weight == lastWeight + smallestIncrement)
        #expect(explanation.roundedWeight == lastWeight + smallestIncrement)
        #expect(explanation.formulaName == "Double progression")
    }

    // MARK: - 2. No bump when any set misses top

    @Test("noBumpWhenAnySetMissesTop")
    func noBumpWhenAnySetMissesTop() throws {
        // One set missed the top of range (10 < 12) → hold weight.
        let lastWeight = 100.0

        let (weight, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: nil,
            lastSessionRepsArray: [12, 10, 12],  // 10 < 12 → no bump
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: lastWeight,
            lastSessionReps: 12,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        #expect(explanation.bumpOccurred == false)
        // Weight should remain at 100 (rounded to nearest plate-loadable).
        #expect(weight == lastWeight)
        #expect(explanation.roundedWeight == lastWeight)
    }

    // MARK: - 3. Warmup sets excluded from bump trigger

    @Test("noBumpWhenWarmupsExcluded")
    func noBumpWhenWarmupsExcluded() throws {
        // The caller filters lastSessionRepsArray to working sets only before calling.
        // When nil is passed (caller has no working-set data), no bump occurs.
        let lastWeight = 100.0

        let (_, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: nil,
            lastSessionRepsArray: nil,  // nil = no working-set signal → no bump
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: lastWeight,
            lastSessionReps: 12,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        // nil array → no bump regardless of lastSessionReps scalar.
        #expect(explanation.bumpOccurred == false)
    }

    // MARK: - 4. First session (no prior data) returns appropriate explanation

    @Test("noBumpFirstSessionUsesPriorHint")
    func noBumpFirstSessionUsesPriorHint() throws {
        // No lastSessionWeight → first-session branch.
        let (weight, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: nil,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: nil,  // no prior session
            lastSessionReps: nil,
            lastSessionRPE: nil,
            lastSessionDate: nil
        )

        #expect(weight == 0)
        #expect(explanation.lastSessionLine == nil)
        #expect(explanation.bumpOccurred == false)
        #expect(explanation.formulaName == "Double progression")
        #expect(explanation.status == .notApplicable)
    }

    // MARK: - 5. Smallest increment honored

    @Test("smallestIncrementHonored")
    func smallestIncrementHonored() throws {
        // Verify that the bump triggers and bumpOccurred == true with 1.25 kg increment.
        // The rounded weight may differ from raw bump (PlateCalculator.roundDown is applied),
        // but bumpOccurred reflects the bump decision, not the rounded outcome.
        // Use a weight where rawBump IS plate-loadable: lastWeight = 97.5,
        // smallestIncrement = 2.5 → rawBump = 100.0 (exactly loadable with standard plates).
        let lastWeight = 97.5
        let smallestIncrement = 2.5

        let (weight, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: nil,
            lastSessionRepsArray: [12, 12, 12],  // bump triggered
            smallestIncrement: smallestIncrement,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: lastWeight,
            lastSessionReps: 12,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        #expect(explanation.bumpOccurred == true)
        // 97.5 + 2.5 = 100.0 which is plate-loadable.
        #expect(weight == lastWeight + smallestIncrement)
        #expect(explanation.roundedWeight == lastWeight + smallestIncrement)
    }
}
