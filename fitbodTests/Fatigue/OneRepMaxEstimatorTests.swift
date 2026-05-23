//
//  OneRepMaxEstimatorTests.swift
//  fitbodTests
//
//  Pins the Brzycki ≤ 6 / Epley 6–10 / suppression > 10 boundaries
//  per REQUIREMENTS PROG-02 (also RESEARCH §1). Pure-function math;
//  no @MainActor, no SwiftData container.
//
//  Boundary cases (the implementation's branch points) are the entire
//  test surface for a 6-line function:
//    Brzycki:    reps = 1, 5, 6
//    Epley:      reps = 7, 10
//    Suppressed: reps = 0, 11, -3
//

import Foundation
import Testing
@testable import fitbod

@Suite("OneRepMaxEstimator")
struct OneRepMaxEstimatorTests {

    // MARK: - Brzycki (reps ≤ 6)

    @Test("Brzycki at reps = 5: 100 × (36/32) == 112.5")
    func brzyckiAtFiveReps() {
        let e1RM = OneRepMaxEstimator.estimate(weight: 100, reps: 5)
        #expect(e1RM != nil)
        let v = try! #require(e1RM)
        #expect(abs(v - 112.5) < 0.001)
    }

    @Test("Brzycki at reps = 1: 100 × (36/36) == 100.0")
    func brzyckiAtOneRep() {
        let e1RM = OneRepMaxEstimator.estimate(weight: 100, reps: 1)
        let v = try! #require(e1RM)
        #expect(abs(v - 100.0) < 0.001)
    }

    @Test("Brzycki at the ≤ 6 boundary: reps = 6 → 100 × (36/31) ≈ 116.129")
    func brzyckiAtSixRepBoundary() {
        let e1RM = OneRepMaxEstimator.estimate(weight: 100, reps: 6)
        let v = try! #require(e1RM)
        #expect(abs(v - 116.129) < 0.01)
    }

    // MARK: - Epley (reps 7–10)

    @Test("Epley at reps = 7: 100 × (1 + 7/30) ≈ 123.333")
    func epleyAtSevenReps() {
        let e1RM = OneRepMaxEstimator.estimate(weight: 100, reps: 7)
        let v = try! #require(e1RM)
        #expect(abs(v - 123.333) < 0.01)
    }

    @Test("Epley at the ≤ 10 boundary: reps = 10 → 100 × (1 + 10/30) ≈ 133.333")
    func epleyAtTenRepBoundary() {
        let e1RM = OneRepMaxEstimator.estimate(weight: 100, reps: 10)
        let v = try! #require(e1RM)
        #expect(abs(v - 133.333) < 0.01)
    }

    // MARK: - Suppression (reps > 10 or ≤ 0)

    @Test("Suppressed at reps = 11 → nil per PROG-02")
    func suppressedAtElevenReps() {
        #expect(OneRepMaxEstimator.estimate(weight: 100, reps: 11) == nil)
    }

    @Test("Suppressed at reps = 0 → nil (defensive guard)")
    func suppressedAtZeroReps() {
        #expect(OneRepMaxEstimator.estimate(weight: 100, reps: 0) == nil)
    }

    @Test("Suppressed at reps = -3 → nil (defensive guard against negative input)")
    func suppressedAtNegativeReps() {
        #expect(OneRepMaxEstimator.estimate(weight: 100, reps: -3) == nil)
    }
}
