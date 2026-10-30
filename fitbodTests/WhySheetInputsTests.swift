//
//  WhySheetInputsTests.swift
//  fitbodTests
//
//  Ticket T89 (findings F103 and F104): Why this weight shows the set's
//  rep range, target RPE and set type, which the logger passes in, and a
//  last top set logged without an RPE is still the last session: the sheet
//  names its weight, reps and date, with no RPE, and step 02 no longer says
//  "No prior data" for it. The strategies suggest what they did before.
//  Step 01's reps in reserve are 10 less the last session's RPE.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("WhySheetInputs")
struct WhySheetInputsTests {

    /// When the last top set was logged.
    private let lastDate = Date(timeIntervalSince1970: 1_790_000_000)

    /// The last-session line's date, as the strategies write it: "Sep 21".
    private var lastDay: String {
        lastDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private let plates: [(weight: Double, countPerSide: Int)] = [
        (weight: 45, countPerSide: 4), (weight: 25, countPerSide: 2), (weight: 10, countPerSide: 2),
        (weight: 5, countPerSide: 2), (weight: 2.5, countPerSide: 2),
    ]

    // MARK: - Double progression

    @Test("Double progression names a last top set logged without an RPE")
    func doubleProgressionNamesLastSetWithoutRPE() {
        let explanation = doubleProgression(lastRPE: nil).explanation
        #expect(explanation.lastSessionLine == "100 lb × 5 (\(lastDay))")
        let sheet = WhyThisWeightSheet(explanation: explanation, unitLabel: "lb")
        #expect(sheet.step02Body == "Weight holds.")
    }

    @Test("Double progression still names a last top set's RPE")
    func doubleProgressionKeepsLastRPE() {
        #expect(doubleProgression(lastRPE: 8).explanation.lastSessionLine == "100 lb × 5 @ RPE 8.0 (\(lastDay))")
    }

    @Test("Without an RPE, double progression holds and bumps as it does with one", arguments: [
        [5, 5, 5], [8, 8, 8],
    ])
    func doubleProgressionSuggestsTheSameWithoutRPE(lastReps: [Int]) {
        let withoutRPE = doubleProgression(lastRPE: nil, lastReps: lastReps)
        let withRPE = doubleProgression(lastRPE: 8, lastReps: lastReps)
        #expect(withoutRPE.weight == withRPE.weight)
        #expect(withoutRPE.explanation.bumpOccurred == withRPE.explanation.bumpOccurred)
        #expect(withoutRPE.explanation.roundedLine == withRPE.explanation.roundedLine)
    }

    // MARK: - RPE autoregulation

    @Test("Calibrated RPE autoregulation names a last top set without an RPE and keeps its suggestion")
    func calibratedRPEAutoregNamesLastSetWithoutRPE() {
        let history = (1...10).map { HistoryPoint(e1RM: 120, date: lastDate.addingTimeInterval(-Double($0) * 86_400)) }
        let withoutRPE = rpeAutoregulation(history: history, lastRPE: nil)
        let withRPE = rpeAutoregulation(history: history, lastRPE: 8)
        #expect(withoutRPE.explanation.lastSessionLine == "100 lb × 5 (\(lastDay))")
        #expect(withRPE.explanation.lastSessionLine == "100 lb × 5 @ RPE 8.0 (\(lastDay))")
        #expect(withoutRPE.weight > 0)
        #expect(withoutRPE.weight == withRPE.weight)
        #expect(withoutRPE.explanation.computedLine == withRPE.explanation.computedLine)
    }

    @Test("Calibrating RPE autoregulation names a last top set without an RPE and still suggests nothing")
    func calibratingRPEAutoregNamesLastSetWithoutRPE() {
        let (weight, explanation) = rpeAutoregulation(history: [], lastRPE: nil)
        #expect(weight == 0)
        #expect(explanation.roundedWeight == 0)
        #expect(explanation.range == nil)
        #expect(explanation.lastSessionLine == "100 lb × 5 (\(lastDay))")
        let sheet = WhyThisWeightSheet(explanation: explanation, unitLabel: "lb")
        #expect(!sheet.step02Body.hasPrefix("No prior data"))
        // T61 and T79: a suggestion of 0 still shows the dash, no Use and no step 03.
        #expect(sheet.heroWeightText == "\u{2014}")
        #expect(sheet.useTitle == nil)
        #expect(sheet.step03Label == nil)
    }

    @Test("With no last session, both strategies still have no last-session line")
    func noLastSessionStaysEmpty() {
        let double = DoubleProgressionStrategy().prescribe(
            history: [], targetRepsLow: 5, targetRepsHigh: 8, targetRPE: nil,
            lastSessionRepsArray: nil, smallestIncrement: 2.5, plates: plates, barWeight: 45, unit: .lb,
            minCalibrationSets: 10, lastSessionWeight: nil, lastSessionReps: nil, lastSessionRPE: nil,
            lastSessionDate: nil
        ).explanation
        let rpe = RPEAutoregStrategy().prescribe(
            history: [], targetRepsLow: 5, targetRepsHigh: 8, targetRPE: 8,
            lastSessionRepsArray: nil, smallestIncrement: 2.5, plates: plates, barWeight: 45, unit: .lb,
            minCalibrationSets: 10, lastSessionWeight: nil, lastSessionReps: nil, lastSessionRPE: nil,
            lastSessionDate: nil
        ).explanation
        #expect(double.lastSessionLine == nil)
        #expect(rpe.lastSessionLine == nil)
    }

    // MARK: - The hero and step 02 show the set's targets

    @Test("The hero shows the set's rep range", arguments: [
        (8...12, "×8–12", "reps 8 to 12"),
        (5...5, "×5", "reps 5"),
    ])
    func heroShowsRepRange(reps: ClosedRange<Int>, shown: String, spoken: String) {
        let sheet = WhyThisWeightSheet(explanation: explanation(), reps: reps, unitLabel: "lb")
        #expect(sheet.heroRepsText == shown)
        #expect(sheet.heroAccessibilityLabel.contains(", \(spoken),"))
    }

    @Test("Without a rep range the hero shows its dash")
    func heroWithoutRepRangeShowsDash() {
        let sheet = WhyThisWeightSheet(explanation: explanation(), unitLabel: "lb")
        #expect(sheet.heroRepsText == "×—")
        #expect(sheet.heroAccessibilityLabel.contains(", reps unknown,"))
    }

    @Test("The hero reads the set's target RPE and type, and step 02 its target")
    func heroAndStepTwoShowTargetRPE() {
        let sheet = WhyThisWeightSheet(
            explanation: explanation(), reps: 6...8, rpe: 8, setTypeLabel: "Working", unitLabel: "lb"
        )
        #expect(sheet.heroAccessibilityLabel == "Recommended weight 100 lb, reps 6 to 8, RPE 8, Working")
        #expect(sheet.step02Label == "Target @ RPE 8")
    }

    @Test("The logger's rep range comes from the exercise's targets, or is none", arguments: [
        (5, 8, 5...8 as ClosedRange<Int>?),
        (8, 8, 8...8),
        (9, 8, nil),
        (0, 0, nil),
    ])
    func loggerRepRange(low: Int, high: Int, expected: ClosedRange<Int>?) {
        #expect(SetRow.targetReps(low: low, high: high) == expected)
    }

    // MARK: - Step 01's reps in reserve

    @Test("Step 01's reps in reserve are 10 less the last session's RPE", arguments: [
        ("100 lb × 5 @ RPE 8.0 (Oct 26)", "You had ~2 reps in reserve."),
        ("100 lb × 5 @ RPE 9.0 (Oct 26)", "You had ~1 rep in reserve."),
        ("195 × 8 @ RPE 8.5 (May 16)", "You had ~1.5 reps in reserve."),
    ])
    func repsInReserveFromLastSessionRPE(line: String, shown: String) {
        // The set's target RPE differs from the last session's; it is not the source.
        let sheet = WhyThisWeightSheet(explanation: explanation(lastSessionLine: line), rpe: 6, unitLabel: "lb")
        #expect(sheet.step01SubCopy == shown)
    }

    @Test("Step 01 shows no reps in reserve without a last session's RPE, or at RPE 10", arguments: [
        "100 lb × 5 (Oct 26)" as String?,
        "100 lb × 5 @ RPE 10.0 (Oct 26)",
        nil,
    ])
    func noRepsInReserveWithoutLastSessionRPE(line: String?) {
        let sheet = WhyThisWeightSheet(explanation: explanation(lastSessionLine: line), rpe: 8, unitLabel: "lb")
        #expect(sheet.step01SubCopy == nil)
    }

    // MARK: - Helpers

    /// An RPE-autoregulated suggestion of 100 lb after `lastSessionLine`.
    private func explanation(lastSessionLine: String? = "100 lb × 5 @ RPE 8.0 (Oct 26)") -> PrescriptionExplanation {
        PrescriptionExplanation(
            lastSessionLine: lastSessionLine,
            formulaName: "RPE autoregulation",
            computedLine: nil,
            roundedWeight: 100,
            roundedLine: "→ 100 lb (rounded down to 2.5 lb plates)",
            status: .calibrating(current: 3, threshold: 10),
            bumpOccurred: false,
            range: 95...105
        )
    }

    /// Double progression for a 5 to 8 rep bench last logged at 100 lb,
    /// its top set 100 x 5 at `lastRPE`.
    private func doubleProgression(
        lastRPE: Double?,
        lastReps: [Int] = [5, 5, 5]
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        DoubleProgressionStrategy().prescribe(
            history: [],
            targetRepsLow: 5,
            targetRepsHigh: 8,
            targetRPE: nil,
            lastSessionRepsArray: lastReps,
            smallestIncrement: 2.5,
            plates: plates,
            barWeight: 45,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: 100,
            lastSessionReps: 5,
            lastSessionRPE: lastRPE,
            lastSessionDate: lastDate
        )
    }

    /// RPE autoregulation for a 5 to 8 rep bench at RPE 8, its last top set
    /// 100 x 5 at `lastRPE`, a week before today.
    private func rpeAutoregulation(
        history: [HistoryPoint],
        lastRPE: Double?
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        RPEAutoregStrategy().prescribe(
            history: history,
            targetRepsLow: 5,
            targetRepsHigh: 8,
            targetRPE: 8,
            lastSessionRepsArray: [5, 5, 5],
            smallestIncrement: 2.5,
            plates: plates,
            barWeight: 45,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: 100,
            lastSessionReps: 5,
            lastSessionRPE: lastRPE,
            lastSessionDate: lastDate,
            today: lastDate.addingTimeInterval(7 * 86_400)
        )
    }
}
