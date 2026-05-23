//
//  RPEAutoregStrategyTests.swift
//  fitbodTests
//
//  5 @Test functions for RPEAutoregStrategy — turned GREEN by plan 03-05.
//  All tests are pure-function: no SwiftData context needed since the strategy
//  operates on pre-fetched HistoryPoint arrays.
//

import Foundation
import Testing
@testable import fitbod

@Suite("RPEAutoregStrategy")
struct RPEAutoregStrategyTests {

    private let strategy = RPEAutoregStrategy()
    private let barWeight: Double = 20.0
    private let standardPlates: [(weight: Double, countPerSide: Int)] = [
        (weight: 20.0, countPerSide: 4),
        (weight: 10.0, countPerSide: 4),
        (weight: 5.0, countPerSide: 4),
        (weight: 2.5, countPerSide: 4),
        (weight: 1.25, countPerSide: 4)
    ]

    // MARK: - 1. Calibrating below threshold shows range

    @Test("calibratingBelowThresholdShowsRange")
    func calibratingBelowThresholdShowsRange() throws {
        // history.count (3) < minCalibrationSets (10) → calibrating mode.
        // With valid lastSession scalars, the strategy should return:
        //   - status == .calibrating(current: 3, threshold: 10)
        //   - range != nil (±5% of point estimate, rounded to plates)
        let history = [
            HistoryPoint(e1RM: 120.0, date: Date()),
            HistoryPoint(e1RM: 122.0, date: Date()),
            HistoryPoint(e1RM: 121.0, date: Date())
        ]

        let (_, explanation) = strategy.prescribe(
            history: history,
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: 100.0,
            lastSessionReps: 8,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        #expect(explanation.status == .calibrating(current: 3, threshold: 10))
        #expect(explanation.range != nil)
        // Range should contain a low and high plate-rounded bound.
        if let range = explanation.range {
            #expect(range.lowerBound <= range.upperBound)
            // The range should be plausible for an ~122 e1RM at 8 reps RPE 8.
            // TuchschererTable.percent(reps:8, rpe:8) = 0.739
            // rawTarget ≈ 122 * 0.739 ≈ 90.2
            // ±5% → [85.7, 94.7] → rounded down to plates
            #expect(range.lowerBound > 0)
        }
        #expect(explanation.formulaName == "RPE autoregulation")
        #expect(explanation.bumpOccurred == false)
    }

    // MARK: - 2. Calibrated above threshold returns point estimate, no range

    @Test("calibratedAboveThresholdReturnsPointEstimate")
    func calibratedAboveThresholdReturnsPointEstimate() throws {
        // history.count (10) >= minCalibrationSets (10) → calibrated mode.
        // Strategy must return status == .calibrated and range == nil.
        let now = Date()
        let history: [HistoryPoint] = (0..<10).map { i in
            let daysAgo = TimeInterval(i) * 86400
            return HistoryPoint(e1RM: 120.0, date: now.addingTimeInterval(-daysAgo))
        }

        let (weight, explanation) = strategy.prescribe(
            history: history,
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: 100.0,
            lastSessionReps: 8,
            lastSessionRPE: 8.0,
            lastSessionDate: now.addingTimeInterval(-86400)
        )

        #expect(explanation.status == .calibrated)
        #expect(explanation.range == nil)
        #expect(explanation.formulaName == "RPE autoregulation")
        #expect(explanation.bumpOccurred == false)
        // Weight should be a reasonable plate-rounded value > 0.
        // Calibration.predict → weighted mean e1RM ≈ 120.0
        // TuchschererTable.percent(reps:8, rpe:8) = 0.739
        // rawTarget ≈ 88.7 → rounded to plates (should be > 0 and <= 100)
        #expect(weight > 0)
        #expect(explanation.computedLine != nil)
    }

    // MARK: - 3. Nil-RPE history points are excluded by caller

    @Test("nilRPEInHistoryIsExcluded")
    func nilRPEInHistoryIsExcluded() throws {
        // Per RESEARCH §Pitfall 7, the caller filters nil-RPE sets before calling.
        // The strategy receives pre-filtered history. When empty (all filtered out),
        // it returns calibrating status with history.count == 0.
        // We simulate this by passing an empty array (all nil-RPE points excluded).
        let emptyHistory: [HistoryPoint] = []

        let (weight, explanation) = strategy.prescribe(
            history: emptyHistory,
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: nil,   // also no last-session scalars
            lastSessionReps: nil,
            lastSessionRPE: nil,
            lastSessionDate: nil
        )

        // Empty history + no last-session data → calibrating with count 0, range nil.
        #expect(weight == 0)
        #expect(explanation.range == nil)
        if case .calibrating(let current, let threshold) = explanation.status {
            #expect(current == 0)
            #expect(threshold == 10)
        } else {
            Issue.record("Expected .calibrating status, got \(explanation.status)")
        }
    }

    // MARK: - 4. Empty history returns first-session explanation

    @Test("emptyHistoryReturnsFirstSessionExplanation")
    func emptyHistoryReturnsFirstSessionExplanation() throws {
        // No history and no last-session scalars → "No prior data" explanation.
        let (weight, explanation) = strategy.prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: nil,
            lastSessionReps: nil,
            lastSessionRPE: nil,
            lastSessionDate: nil
        )

        #expect(weight == 0)
        #expect(explanation.lastSessionLine == nil)
        #expect(explanation.formulaName == "RPE autoregulation")
        // status is calibrating with 0 sets accumulated.
        if case .calibrating(let current, _) = explanation.status {
            #expect(current == 0)
        } else {
            Issue.record("Expected .calibrating status, got \(explanation.status)")
        }
    }

    // MARK: - 5. TuchschererTable back-calc used below threshold

    @Test("tuchschererBackCalcUsedBelowThreshold")
    func tuchschererBackCalcUsedBelowThreshold() throws {
        // Below threshold with known last-session values → verify the back-calculation
        // produces a sensible prescribed weight from TuchschererTable.percent.
        //
        // Setup: lastWeight=100 kg × 5 reps @ RPE 8.0
        //   TuchschererTable.percent(reps:5, rpe:8.0) = 0.811
        //   e1RM = 100 / 0.811 ≈ 123.3 kg
        //   Target: 5 reps @ RPE 8 → 0.811 fraction
        //   rawTarget = 123.3 × 0.811 ≈ 100.0 kg (same session weight, as expected)
        //   → rounded = 100.0 (plate-loadable)
        let (weight, explanation) = strategy.prescribe(
            history: [],    // empty → clearly below calibration threshold
            targetRepsLow: 3,
            targetRepsHigh: 5,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: standardPlates,
            barWeight: barWeight,
            minCalibrationSets: 10,
            lastSessionWeight: 100.0,
            lastSessionReps: 5,
            lastSessionRPE: 8.0,
            lastSessionDate: Date()
        )

        // With identical target (5 reps @ RPE 8 same as last session),
        // the prescribed weight should equal lastSessionWeight (back-calc round-trip).
        #expect(weight == 100.0)
        #expect(explanation.range != nil)   // calibrating → range present
        #expect(explanation.formulaName == "RPE autoregulation")

        // status must be .calibrating(current: 0, threshold: 10)
        if case .calibrating(let current, let threshold) = explanation.status {
            #expect(current == 0)
            #expect(threshold == 10)
        } else {
            Issue.record("Expected .calibrating status, got \(explanation.status)")
        }
    }
}
