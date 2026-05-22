//
//  TuchschererTableTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the Tuchscherer RPE/reps percentage
//  lookup table. Replaced by plan 03-03 with real assertions against
//  TuchschererTable (a pure static function that does not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-03 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("TuchschererTable")
struct TuchschererTableTests {

    @Test("rpe10reps1Returns1_000")
    func rpe10reps1Returns1_000() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: TuchschererTable.percent(reps:1, rpe:10.0) must equal 1.000")
    }

    @Test("rpe8reps5Returns0_811")
    func rpe8reps5Returns0_811() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: TuchschererTable.percent(reps:5, rpe:8.0) must equal 0.811")
    }

    @Test("rpe6reps10Returns0_656")
    func rpe6reps10Returns0_656() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: TuchschererTable.percent(reps:10, rpe:6.0) must equal 0.656")
    }

    @Test("clampRepsAboveTen")
    func clampRepsAboveTen() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: reps > 10 must clamp to reps = 10 (per CONTEXT.md Area 1 lock, revised 2026-05-22): percent(reps:12, rpe:8.0) == percent(reps:10, rpe:8.0)")
    }

    @Test("nearestRPESnap")
    func nearestRPESnap() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-03: RPE 8.3 must snap to RPE 8.5; percent(reps:5, rpe:8.3) == percent(reps:5, rpe:8.5)")
    }
}
