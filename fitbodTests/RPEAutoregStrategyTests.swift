//
//  RPEAutoregStrategyTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the RPEAutoregStrategy (calibrating /
//  calibrated mode switch). Replaced by plan 03-05 with real assertions
//  against RPEAutoregStrategy (a pure function over HistoryPoint arrays
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

@Suite("RPEAutoregStrategy")
struct RPEAutoregStrategyTests {

    @Test("calibratingBelowThresholdShowsRange")
    func calibratingBelowThresholdShowsRange() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: history < minCalibrationSets returns explanation with CalibrationStatus .calibrating(n, threshold) AND PrescriptionExplanation.range non-nil")
    }

    @Test("calibratedAboveThresholdReturnsPointEstimate")
    func calibratedAboveThresholdReturnsPointEstimate() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: history >= minCalibrationSets returns CalibrationStatus .calibrated AND PrescriptionExplanation.range == nil")
    }

    @Test("nilRPEInHistoryIsExcluded")
    func nilRPEInHistoryIsExcluded() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: history points with nil rpe are skipped (RESEARCH §Pitfall 7)")
    }

    @Test("emptyHistoryReturnsFirstSessionExplanation")
    func emptyHistoryReturnsFirstSessionExplanation() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: empty history returns lastSessionLine == nil and a non-zero startWeight from caller-supplied prior weight hint OR 0 if absent")
    }

    @Test("tuchschererBackCalcUsedBelowThreshold")
    func tuchschererBackCalcUsedBelowThreshold() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: below threshold: prescribedWeight derived from prior actualRPE+actualReps via TuchschererTable.percent (e1RM = actualWeight / percent)")
    }
}
