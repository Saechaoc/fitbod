//
//  CalibratingStepCopyTests.swift
//  fitbodTests
//
//  Ticket T97 (findings F137 and F138): Why this weight explains RPE
//  autoregulation's calibrating suggestions. Calibrating from the last
//  session, step 02 shows the e1RM from that session, the percentage for
//  the target reps and RPE, and the raw target, in the calibrated line's
//  shape. A last session without an RPE gives nothing to calibrate from:
//  step 02 says so, step 03 asks for a starting weight, and nothing is
//  suggested. "Weight holds." is double progression's alone. Suggested
//  weights and ranges are unchanged.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("CalibratingStepCopy")
struct CalibratingStepCopyTests {

    /// When the last top set was logged.
    private let lastDate = Date(timeIntervalSince1970: 1_790_000_000)

    private let plates: [(weight: Double, countPerSide: Int)] = [
        (weight: 45, countPerSide: 4), (weight: 25, countPerSide: 2), (weight: 10, countPerSide: 2),
        (weight: 5, countPerSide: 2), (weight: 2.5, countPerSide: 2),
    ]

    @Test("Calibrating from 110 lb x 8 @ RPE 8, step 02 shows how RPE autoregulation got the weight")
    func calibratingFromLastSessionShowsComputation() {
        let (weight, explanation) = rpeAutoregulation(lastRPE: 8)
        // 110 lb is 73.9% of a 148.8 lb e1RM; 5 reps at RPE 8 is 81% of it,
        // 120.7 lb, rounded down to 120 lb plates.
        #expect(weight == 120)
        #expect(explanation.roundedWeight == 120)
        #expect(explanation.range == 110...125)
        let sheet = WhyThisWeightSheet(explanation: explanation, reps: 3...5, rpe: 8, unitLabel: "lb")
        #expect(sheet.step02Body == "Last session e1RM 148.8 lb → 81% × 5 → 120.7 lb")
        #expect(sheet.step03Label == "Rounded to plate 2.5 lb")
        #expect(sheet.step03Text == "120.7 → 120")
    }

    @Test("A last session without an RPE: step 02 says why nothing is suggested, step 03 asks for a starting weight")
    func lastSessionWithoutRPEAsksForStartingWeight() {
        let (weight, explanation) = rpeAutoregulation(lastRPE: nil)
        #expect(weight == 0)
        #expect(explanation.roundedWeight == 0)
        #expect(explanation.range == nil)
        let sheet = WhyThisWeightSheet(explanation: explanation, reps: 3...5, rpe: 8, unitLabel: "lb")
        #expect(sheet.step02Body == "Last session has no RPE to calibrate from. Log one on this set.")
        #expect(sheet.step03Label == "Starting weight")
        #expect(sheet.step03Text == "Choose a starting weight.")
    }

    @Test("Every other suggestion of 0 after a last session still leaves step 03 out", arguments: [
        "RPE autoregulation", "Double progression",
    ])
    func otherZeroSuggestionsLeaveStepThreeOut(formula: String) {
        // A bodyweight lift last logged with no added load rounds to 0.
        let explanation = formula == "RPE autoregulation"
            ? rpeAutoregulation(lastWeight: 0, lastRPE: 8, barWeight: 0).explanation
            : DoubleProgressionStrategy().prescribe(
                history: [], targetRepsLow: 3, targetRepsHigh: 5, targetRPE: nil,
                lastSessionRepsArray: [3], smallestIncrement: 2.5, plates: [], barWeight: 0, unit: .lb,
                minCalibrationSets: 10, lastSessionWeight: 0, lastSessionReps: 3, lastSessionRPE: 8,
                lastSessionDate: lastDate
            ).explanation
        #expect(explanation.roundedWeight == 0)
        #expect(explanation.lastSessionLine != nil)
        let sheet = WhyThisWeightSheet(explanation: explanation, unitLabel: "lb")
        #expect(sheet.step03Label == nil)
        #expect(sheet.step03Text == nil)
    }

    @Test("\"Weight holds.\" is double progression's alone")
    func onlyDoubleProgressionHolds() {
        // An RPE-autoregulated suggestion explained without a computed line.
        let explanation = PrescriptionExplanation(
            lastSessionLine: "110 lb × 8 @ RPE 8.0 (Sep 21)",
            formulaName: "RPE autoregulation",
            roundedWeight: 110,
            roundedLine: "→ 110 lb (rounded down to 2.5 lb plates)",
            status: .calibrating(current: 1, threshold: 10),
            range: 100...115
        )
        let sheet = WhyThisWeightSheet(explanation: explanation, unitLabel: "lb")
        #expect(sheet.step02Body == "→ 110 lb (rounded down to 2.5 lb plates)")
    }

    // MARK: - Helpers

    /// RPE autoregulation, still calibrating, for a 3 to 5 rep bench at
    /// RPE 8, its last top set `lastWeight` x 8 at `lastRPE`, a week before
    /// today.
    private func rpeAutoregulation(
        lastWeight: Double = 110,
        lastRPE: Double?,
        barWeight: Double = 45
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        RPEAutoregStrategy().prescribe(
            history: [HistoryPoint(e1RM: 150, date: lastDate)],
            targetRepsLow: 3,
            targetRepsHigh: 5,
            targetRPE: 8,
            lastSessionRepsArray: [8, 8, 8],
            smallestIncrement: 2.5,
            plates: plates,
            barWeight: barWeight,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: lastWeight,
            lastSessionReps: 8,
            lastSessionRPE: lastRPE,
            lastSessionDate: lastDate,
            today: lastDate.addingTimeInterval(7 * 86_400)
        )
    }
}
