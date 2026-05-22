//
//  PlateCalculatorTests.swift
//  fitbodTests
//
//  Tests for the PlateCalculator greedy plate-loading solver.
//  All 5 @Test cases assert concrete behavior against PlateCalculator
//  (plan 03-03 implementation).
//

import Foundation
import Testing
@testable import fitbod

@Suite("PlateCalculator")
struct PlateCalculatorTests {

    // Standard kg barbell inventory (with 1.25 microplates).
    private let standardKgPlatesWithMicroplates: [(weight: Double, countPerSide: Int)] = [
        (weight: 25, countPerSide: 4),
        (weight: 20, countPerSide: 2),
        (weight: 15, countPerSide: 2),
        (weight: 10, countPerSide: 2),
        (weight: 5,  countPerSide: 2),
        (weight: 2.5, countPerSide: 2),
        (weight: 1.25, countPerSide: 2),
    ]

    // Standard kg barbell inventory WITHOUT 1.25 microplates.
    // Per-side increment is 2.5 kg — cannot load odd increments like 41.25 kg/side.
    private let standardKgPlatesNoMicroplates: [(weight: Double, countPerSide: Int)] = [
        (weight: 25, countPerSide: 4),
        (weight: 20, countPerSide: 2),
        (weight: 15, countPerSide: 2),
        (weight: 10, countPerSide: 2),
        (weight: 5,  countPerSide: 2),
        (weight: 2.5, countPerSide: 2),
    ]

    @Test("solve100kgWith20kgBar")
    func solve100kgWith20kgBar() throws {
        // 100 kg target, 20 kg bar → 40 kg per side.
        // Greedy: 1×25 (rem 15), 1×15 (rem 0) → platesPerSide = [(25,1),(15,1)].
        let result = PlateCalculator.solve(
            target: 100,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        let stack = try #require(result)
        #expect(stack.totalWeight == 100.0)
        #expect(stack.platesPerSide.count == 2)
        #expect(stack.platesPerSide[0].weight == 25.0)
        #expect(stack.platesPerSide[0].count == 1)
        #expect(stack.platesPerSide[1].weight == 15.0)
        #expect(stack.platesPerSide[1].count == 1)
    }

    @Test("roundDown102_5kgWith2_5kgIncrement")
    func roundDown102_5kgWith2_5kgIncrement() throws {
        // 102.5 kg target, 20 kg bar, no 1.25 microplates.
        // Per side: (102.5 - 20) / 2 = 41.25 kg — not achievable without 1.25 plates.
        // Greedy loads: 1×25 + 1×15 = 40 per side → 100 kg total.
        let result = PlateCalculator.roundDown(
            target: 102.5,
            barWeight: 20,
            plates: standardKgPlatesNoMicroplates
        )
        #expect(result == 100.0)
    }

    @Test("belowBarReturnsBar")
    func belowBarReturnsBar() throws {
        // Target (15) < barWeight (20) → return barWeight (20).
        let result = PlateCalculator.roundDown(
            target: 15,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        #expect(result == 20.0)
    }

    @Test("epsilonFloatDriftGuard")
    func epsilonFloatDriftGuard() throws {
        // 97.4999 is within float rounding noise of 97.5.
        // Per-side for 97.5: (97.5 - 20) / 2 = 38.75 → 1×25 + 1×10 + 1×2.5 + 1×1.25 = 38.75
        // Both targets should resolve to the same plate-loadable result: 97.5 kg.
        let resultA = PlateCalculator.roundDown(
            target: 97.4999,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        let resultB = PlateCalculator.roundDown(
            target: 97.5,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        #expect(resultA == resultB)
        #expect(resultB == 97.5)
    }

    @Test("noSolutionReturnsNil")
    func noSolutionReturnsNil() throws {
        // Only 20 kg plates × 2 per side → maximum loadable: 20 + 2*(20*2) = 100 kg.
        // 1000 kg is not achievable.
        let result = PlateCalculator.solve(
            target: 1000,
            barWeight: 20,
            plates: [(weight: 20, countPerSide: 2)]
        )
        #expect(result == nil)
    }
}
