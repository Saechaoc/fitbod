//
//  PlateCalculatorTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the PlateCalculator greedy solver.
//  Replaced by plan 03-03 with real assertions against PlateCalculator
//  (a pure function type that does not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-03 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("PlateCalculator")
struct PlateCalculatorTests {

    @Test("solve100kgWith20kgBar")
    func solve100kgWith20kgBar() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: 100kg target / 20kg bar / [25×4,20×2,15×2,10×2,5×2,2.5×2,1.25×2] returns stack {1×25,1×15} per side, totalWeight=100")
    }

    @Test("roundDown102_5kgWith2_5kgIncrement")
    func roundDown102_5kgWith2_5kgIncrement() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: roundDown returns 100.0 if 102.5 not loadable with given inventory")
    }

    @Test("belowBarReturnsBar")
    func belowBarReturnsBar() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: roundDown(target:15, bar:20, plates:...) returns 20.0")
    }

    @Test("epsilonFloatDriftGuard")
    func epsilonFloatDriftGuard() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: roundDown(target:97.4999, bar:20, plates:standard) returns same as roundDown(target:97.5, ...) (no float-drift mis-solve per RESEARCH §Pitfall 4)")
    }

    @Test("noSolutionReturnsNil")
    func noSolutionReturnsNil() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: solve(target:1000, bar:20, plates:[20×2]) returns nil")
    }
}
