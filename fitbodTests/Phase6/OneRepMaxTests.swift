//
//  OneRepMaxTests.swift
//  fitbodTests
//
//  Wave-1 plan 06-01 — boundary coverage for `OneRepMax.estimate(weight:reps:)`.
//  Six `@Test` functions:
//
//    1. identityAtOneRep — reps == 1 returns weight verbatim (Pitfall 4)
//    2. brzyckiRange — reps 2..6 use Brzycki within 0.1 unit tolerance
//    3. epleyRange — reps 7..10 use Epley within 0.1 unit tolerance
//    4. suppressesHighRep — reps 11..20 all return nil (PROG-02 / D-04)
//    5. nilOnNonPositiveInputs — weight ≤ 0 or reps ≤ 0 returns nil
//    6. handlesNegativeWeight — Pitfall 5 bodyweight-assist returns nil
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("OneRepMax (PROG-02 + CONTEXT D-04)")
struct OneRepMaxTests {

    @Test("identityAtOneRep — reps == 1 returns weight verbatim")
    func identityAtOneRep() throws {
        let actual = try #require(OneRepMax.estimate(weight: 100, reps: 1))
        #expect(abs(actual - 100.0) < 0.0001)
        let actual200 = try #require(OneRepMax.estimate(weight: 200.0, reps: 1))
        #expect(abs(actual200 - 200.0) < 0.0001)
    }

    @Test(
        "brzyckiRange — reps 2..6 use Brzycki formula",
        arguments: [
            // (weight, reps, expected): expected = weight * 36 / (37 - reps)
            (100.0, 2, 100.0 * 36.0 / 35.0),   // ≈ 102.857
            (100.0, 3, 100.0 * 36.0 / 34.0),   // ≈ 105.882
            (100.0, 4, 100.0 * 36.0 / 33.0),   // ≈ 109.091
            (100.0, 5, 100.0 * 36.0 / 32.0),   // == 112.5
            (100.0, 6, 100.0 * 36.0 / 31.0),   // ≈ 116.129
            ( 80.0, 5,  80.0 * 36.0 / 32.0),   // == 90.0
        ] as [(Double, Int, Double)]
    )
    func brzyckiRange(weight: Double, reps: Int, expected: Double) throws {
        let actual = try #require(OneRepMax.estimate(weight: weight, reps: reps))
        #expect(abs(actual - expected) < 0.1)
    }

    @Test(
        "epleyRange — reps 7..10 use Epley formula",
        arguments: [
            // (weight, reps, expected): expected = weight * (1 + reps / 30)
            (100.0, 7,  100.0 * (1.0 + 7.0  / 30.0)), // ≈ 123.33
            (100.0, 8,  100.0 * (1.0 + 8.0  / 30.0)), // ≈ 126.67
            (100.0, 9,  100.0 * (1.0 + 9.0  / 30.0)), // == 130.0
            (100.0, 10, 100.0 * (1.0 + 10.0 / 30.0)), // ≈ 133.33
            ( 80.0, 10,  80.0 * (1.0 + 10.0 / 30.0)), // ≈ 106.67
        ] as [(Double, Int, Double)]
    )
    func epleyRange(weight: Double, reps: Int, expected: Double) throws {
        let actual = try #require(OneRepMax.estimate(weight: weight, reps: reps))
        #expect(abs(actual - expected) < 0.1)
    }

    @Test(
        "suppressesHighRep — reps 11..20 return nil per PROG-02 / D-04",
        arguments: [11, 12, 15, 20, 50] as [Int]
    )
    func suppressesHighRep(reps: Int) {
        #expect(OneRepMax.estimate(weight: 100.0, reps: reps) == nil)
    }

    @Test("nilOnNonPositiveInputs — zero or negative reps returns nil")
    func nilOnNonPositiveInputs() {
        #expect(OneRepMax.estimate(weight: 100.0, reps: 0) == nil)
        #expect(OneRepMax.estimate(weight: 100.0, reps: -3) == nil)
        #expect(OneRepMax.estimate(weight: 0.0, reps: 5) == nil)
    }

    @Test("handlesNegativeWeight — Pitfall 5 bodyweight-assist returns nil")
    func handlesNegativeWeight() {
        // Assisted pull-up encoded as negative effective load (-20 kg of
        // assistance) would otherwise emit a nonsense negative e1RM.
        #expect(OneRepMax.estimate(weight: -20.0, reps: 5) == nil)
        #expect(OneRepMax.estimate(weight: -100.0, reps: 1) == nil)
    }
}
