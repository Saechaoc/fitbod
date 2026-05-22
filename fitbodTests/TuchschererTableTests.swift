//
//  TuchschererTableTests.swift
//  fitbodTests
//
//  Tests for the Tuchscherer RPE/reps percentage lookup table.
//  All 5 @Test cases assert concrete values against TuchschererTable
//  (plan 03-03 implementation).
//

import Foundation
import Testing
@testable import fitbod

@Suite("TuchschererTable")
struct TuchschererTableTests {

    @Test("rpe10reps1Returns1_000")
    func rpe10reps1Returns1_000() throws {
        #expect(TuchschererTable.percent(reps: 1, rpe: 10.0) == 1.000)
    }

    @Test("rpe8reps5Returns0_811")
    func rpe8reps5Returns0_811() throws {
        #expect(TuchschererTable.percent(reps: 5, rpe: 8.0) == 0.811)
    }

    @Test("rpe6reps10Returns0_656")
    func rpe6reps10Returns0_656() throws {
        #expect(TuchschererTable.percent(reps: 10, rpe: 6.0) == 0.656)
    }

    @Test("clampRepsAboveTen")
    func clampRepsAboveTen() throws {
        #expect(TuchschererTable.percent(reps: 12, rpe: 8.0) == TuchschererTable.percent(reps: 10, rpe: 8.0))
        #expect(TuchschererTable.percent(reps: 12, rpe: 8.0) == 0.696)
    }

    @Test("nearestRPESnap")
    func nearestRPESnap() throws {
        #expect(TuchschererTable.percent(reps: 5, rpe: 8.3) == TuchschererTable.percent(reps: 5, rpe: 8.5))
        #expect(TuchschererTable.percent(reps: 5, rpe: 8.3) == 0.824)
    }
}
