//
//  PrescriptionExplanationTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the PrescriptionExplanation value type
//  (the "Why this weight?" data model). Replaced by plan 03-05 with real
//  assertions against PrescriptionExplanation and CalibrationStatus
//  (types that do not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-05 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("PrescriptionExplanation")
struct PrescriptionExplanationTests {

    @Test("constructionExposesAllFields")
    func constructionExposesAllFields() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: PrescriptionExplanation(lastSessionLine:formulaName:computedLine:roundedWeight:roundedLine:status:bumpOccurred:range:) initializer returns a value with those fields")
    }

    @Test("calibrationStatusEquatable")
    func calibrationStatusEquatable() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: CalibrationStatus.calibrated == .calibrated; .calibrating(4,10) == .calibrating(4,10); .calibrating(4,10) != .calibrating(5,10)")
    }

    @Test("sendableSafe")
    func sendableSafe() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: PrescriptionExplanation value crosses Sendable boundaries (Task { let ex = explanation; ... } compiles)")
    }

    @Test("bumpOccurredFalseByDefault")
    func bumpOccurredFalseByDefault() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: Memberwise init with bumpOccurred default false")
    }

    @Test("rangeNilByDefault")
    func rangeNilByDefault() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: range default nil")
    }
}
