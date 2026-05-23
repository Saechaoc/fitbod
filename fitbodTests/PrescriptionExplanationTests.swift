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

    // MARK: - Phase 3.1 (PIVOT-04 / D-12)

    @Test("sessionIntent default is nil; setting it round-trips")
    func sessionIntentDefaultIsNilAndSettingRoundTrips() throws {
        // Default-constructed PrescriptionExplanation carries nil sessionIntent
        // (the field is additive — pre-3.1 strategies that don't thread it
        // through end up at nil; WhyThisWeightSheet falls back to the
        // unprefixed Phase 3 status copy).
        let defaultExp = PrescriptionExplanation(
            formulaName: "Double progression",
            roundedWeight: 100.0,
            roundedLine: "→ 100 kg",
            status: .notApplicable
        )
        #expect(defaultExp.sessionIntent == nil)

        // When the caller (SessionFactory / SessionExerciseCard) sets it from
        // session.intent, the value sticks for WhyThisWeightSheet to read.
        let explicitExp = PrescriptionExplanation(
            formulaName: "RPE autoregulation",
            roundedWeight: 107.5,
            roundedLine: "→ 107.5 kg",
            status: .calibrating(current: 4, threshold: 10),
            sessionIntent: .strength
        )
        #expect(explicitExp.sessionIntent == .strength)

        // The field is also mutable post-init (the caller assigns it after
        // the strategy returns its computed explanation).
        var mutated = defaultExp
        mutated.sessionIntent = .hypertrophy
        #expect(mutated.sessionIntent == .hypertrophy)
    }
}
