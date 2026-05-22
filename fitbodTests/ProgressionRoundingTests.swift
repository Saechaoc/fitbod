//
//  ProgressionRoundingTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for progression weight rounding logic
//  (per-exercise increment overrides global default). Replaced by plan
//  03-05 with real assertions against the rounding helper (pure function
//  that does not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-05 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ProgressionRounding")
struct ProgressionRoundingTests {

    @Test("exerciseIncrementOverridesGlobal")
    func exerciseIncrementOverridesGlobal() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: Exercise.smallestIncrement = 1.25 used in preference to UserSettings.defaultIncrementKg = 2.5")
    }

    @Test("globalDefaultUsedWhenNil")
    func globalDefaultUsedWhenNil() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: Exercise.smallestIncrement == nil falls back to UserSettings.defaultIncrementKg")
    }

    @Test("kgVsLbUnitOverride")
    func kgVsLbUnitOverride() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: Per-exercise Exercise.unitOverride does NOT affect rounding math (which stays canonical kg per RESEARCH); only display layer differs")
    }

    @Test("microplateIncrement")
    func microplateIncrement() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: 0.5 kg increment respected end-to-end")
    }

    @Test("roundingDownNeverExceedsTarget")
    func roundingDownNeverExceedsTarget() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: Any rounded prescribed weight is <= raw target weight for all sample inputs")
    }
}
