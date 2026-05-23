//
//  PrescriptionExplanationTests.swift
//  fitbodTests
//
//  5 @Test functions for PrescriptionExplanation value type and
//  CalibrationStatus enum — turned GREEN by plan 03-05.
//

import Foundation
import Testing
@testable import fitbod

@Suite("PrescriptionExplanation")
struct PrescriptionExplanationTests {

    @Test("constructionExposesAllFields")
    func constructionExposesAllFields() throws {
        let lastSessionLine = "100 kg × 8 @ RPE 8.5 (May 15)"
        let computedLine = "Target e1RM 122.0 kg → 88% × 8 → 107.0 kg"
        let roundedLine = "→ 107.5 kg (rounded down to 1.25 kg plates)"
        let range: ClosedRange<Double> = 95.0...105.0

        let exp = PrescriptionExplanation(
            lastSessionLine: lastSessionLine,
            formulaName: "RPE autoregulation",
            computedLine: computedLine,
            roundedWeight: 107.5,
            roundedLine: roundedLine,
            status: .calibrating(current: 4, threshold: 10),
            bumpOccurred: true,
            range: range
        )

        #expect(exp.lastSessionLine == lastSessionLine)
        #expect(exp.formulaName == "RPE autoregulation")
        #expect(exp.computedLine == computedLine)
        #expect(exp.roundedWeight == 107.5)
        #expect(exp.roundedLine == roundedLine)
        #expect(exp.status == .calibrating(current: 4, threshold: 10))
        #expect(exp.bumpOccurred == true)
        #expect(exp.range == range)
    }

    @Test("calibrationStatusEquatable")
    func calibrationStatusEquatable() throws {
        #expect(CalibrationStatus.calibrated == .calibrated)
        #expect(CalibrationStatus.calibrating(current: 4, threshold: 10) == .calibrating(current: 4, threshold: 10))
        #expect(CalibrationStatus.calibrating(current: 4, threshold: 10) != .calibrating(current: 5, threshold: 10))
        #expect(CalibrationStatus.calibrated != .notApplicable)
        #expect(CalibrationStatus.notApplicable != .calibrating(current: 0, threshold: 10))
    }

    @Test("sendableSafe")
    func sendableSafe() async throws {
        let exp = PrescriptionExplanation(
            lastSessionLine: nil,
            formulaName: "Double progression",
            roundedWeight: 100.0,
            roundedLine: "→ 100.0 kg",
            status: .notApplicable
        )
        // PrescriptionExplanation is a value type with all Sendable fields —
        // the closure capture compiles without a @Sendable annotation under
        // Swift 6 strict concurrency.
        let task = Task {
            let _ = exp
        }
        // Await to ensure the task ran (not asserting anything else — the
        // compile-time Sendable check is the real assertion here).
        await task.value
    }

    @Test("bumpOccurredFalseByDefault")
    func bumpOccurredFalseByDefault() throws {
        let exp = PrescriptionExplanation(
            formulaName: "x",
            roundedWeight: 100,
            roundedLine: "→ 100 kg",
            status: .notApplicable
        )
        #expect(exp.bumpOccurred == false)
    }

    @Test("rangeNilByDefault")
    func rangeNilByDefault() throws {
        let exp = PrescriptionExplanation(
            formulaName: "x",
            roundedWeight: 100,
            roundedLine: "→ 100 kg",
            status: .notApplicable
        )
        #expect(exp.range == nil)
    }
}
