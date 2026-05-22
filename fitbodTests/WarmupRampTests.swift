//
//  WarmupRampTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the WarmupRamp generator.
//  Replaced by plan 03-05 with real assertions against WarmupRamp
//  (a pure function type that does not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-05 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("WarmupRamp")
struct WarmupRampTests {

    @Test("barbellCompoundAtTopGenerates4Sets")
    func barbellCompoundAtTopGenerates4Sets() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: WarmupRamp.generate(top:100, bar:20, plates:standardKg) returns 4 SetEntry rows with weights ≤ 0.40*100, 0.60*100, 0.75*100, 0.90*100 and reps 5,3,2,1")
    }

    @Test("dumbbellHalvesTo2Sets")
    func dumbbellHalvesTo2Sets() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: dumbbell equipment returns 2 SetEntry rows (60%×3, 90%×1)")
    }

    @Test("lightWeightSkipsRamp")
    func lightWeightSkipsRamp() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: shouldGenerate(for: sessionExercise with working weight < 1.5×barWeight) returns false")
    }

    @Test("bodyweightSkipsRamp")
    func bodyweightSkipsRamp() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: shouldGenerate(for: sessionExercise with bodyweight equipment) returns false")
    }

    @Test("deloadActiveSkipsRamp")
    func deloadActiveSkipsRamp() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: shouldGenerate(deloadActive: true) returns false even on qualifying compound")
    }
}
