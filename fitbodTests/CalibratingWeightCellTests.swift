//
//  CalibratingWeightCellTests.swift
//  fitbodTests
//
//  The exercise shows the calibration range. Each field reports the set's
//  weight and still tracks changes from the prescription.
//

import SwiftUI
import Testing
@testable import fitbod

@MainActor
@Suite("CalibratingWeightCell")
struct CalibratingWeightCellTests {

    @Test("A bench last logged at 110 x 5 at RPE 8 calibrates to 95 – 105 lb and suggests 100")
    func benchCalibratesToRange() {
        let explanation = benchCalibration()
        #expect(explanation.range == 95.0...105.0)
        #expect(explanation.roundedWeight == 100)
    }

    @Test("An open set shows a weight typed away from the prescription")
    func typedWeightShows() {
        let cell = benchCell(weight: 102.5, wasManualOverride: true)
        #expect(cell.isManualOverride(102.5))
        #expect(cell.accessibilityValueText == "102.5 lb")
    }

    @Test("An open set shows a suggestion above 0", arguments: [
        // Use in the set menu writes the suggestion.
        (100.0, 97.5),
        // A typed weight equal to the prescription stored at the start is
        // no change from it, and still a suggestion.
        (97.5, 97.5),
    ])
    func suggestionShows(weight: Double, prescribed: Double) {
        let cell = benchCell(weight: weight, prescribed: prescribed)
        #expect(cell.accessibilityValueText == "\(String(format: "%g", weight)) lb")
    }

    // MARK: - A logged set shows the weight it logged

    @Test("A logged set shows the weight it logged, never the range", arguments: [false, true])
    func loggedSetShowsWeight(wasManualOverride: Bool) {
        let cell = benchCell(weight: 110, wasManualOverride: wasManualOverride, isComplete: true)
        #expect(cell.accessibilityValueText == "110 lb")
    }

    @Test("An open calibrating set shows its own weight", arguments: [110.0, 0.0])
    func untouchedSetShowsWeight(weight: Double) {
        let cell = benchCell(weight: weight)
        #expect(cell.accessibilityValueText == (weight == 0 ? "none" : "110 lb"))
    }

    @Test("An untouched range of 0 to 0 keeps T61's dash, read as none")
    func zeroRangeKeepsDash() {
        let cell = bodyweightCell(weight: 0)
        #expect(cell.accessibilityValueText == "none")
    }

    // MARK: - A load typed over a range of 0 to 0

    @Test("A load typed over a range of 0 to 0 is a change from it, and keeps showing")
    func typedLoadOverZeroRangeShows() {
        let untouched = bodyweightCell(weight: 0)
        #expect(untouched.isManualOverride(10))
        #expect(!untouched.isManualOverride(0))

        let typed = bodyweightCell(weight: 10, wasManualOverride: true)
        #expect(typed.accessibilityValueText == "10 lb")
    }

    @Test("Without a range, a weight with no prescription is still no change")
    func noRangeNoPrescriptionIsNoChange() {
        let cell = PrescriptionWeightCell(
            weight: .constant(10),
            prescribed: 0,
            range: nil,
            unitLabel: "lb",
            wasManualOverride: .constant(false)
        )
        #expect(!cell.isManualOverride(10))
    }

    // MARK: - Helpers

    /// The weight cell as SetRow builds it for an open or logged set of the
    /// bench press in `benchCalibration()`: a range of 95 to 105 lb and a
    /// suggestion of 100 lb.
    private func benchCell(
        weight: Double,
        prescribed: Double = 100,
        wasManualOverride: Bool = false,
        isComplete: Bool = false
    ) -> PrescriptionWeightCell {
        let explanation = benchCalibration()
        return PrescriptionWeightCell(
            weight: .constant(weight),
            prescribed: prescribed,
            range: explanation.range,
            unitLabel: "lb",
            wasManualOverride: .constant(wasManualOverride),
            isComplete: isComplete
        )
    }

    /// The weight cell for an open set of the bodyweight lift in
    /// `bodyweightCalibration()`: a range of 0 to 0, no suggestion and no
    /// prescription.
    private func bodyweightCell(weight: Double, wasManualOverride: Bool = false) -> PrescriptionWeightCell {
        let explanation = bodyweightCalibration()
        return PrescriptionWeightCell(
            weight: .constant(weight),
            prescribed: 0,
            range: explanation.range,
            unitLabel: "lb",
            wasManualOverride: .constant(wasManualOverride)
        )
    }

    /// What RPE autoregulation explains for CalibratingSetSeed's bench
    /// press: 6 to 8 reps at RPE 8, last logged at 110 x 5 at RPE 8, on a
    /// 45 lb bar with the default lb plates, with too few sets to calibrate.
    private func benchCalibration() -> PrescriptionExplanation {
        RPEAutoregStrategy().prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8,
            lastSessionRepsArray: [5, 5, 5],
            smallestIncrement: 2.5,
            plates: [
                (weight: 45, countPerSide: 4), (weight: 35, countPerSide: 2),
                (weight: 25, countPerSide: 2), (weight: 10, countPerSide: 2),
                (weight: 5, countPerSide: 2), (weight: 2.5, countPerSide: 2),
                (weight: 1.25, countPerSide: 2),
            ],
            barWeight: 45,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: 110,
            lastSessionReps: 5,
            lastSessionRPE: 8,
            lastSessionDate: nil
        ).explanation
    }

    /// What RPE autoregulation explains for a bodyweight lift, still
    /// calibrating, whose last workout added no load: a range of 0 to 0.
    private func bodyweightCalibration() -> PrescriptionExplanation {
        RPEAutoregStrategy().prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8,
            lastSessionRepsArray: [8],
            smallestIncrement: 2.5,
            plates: [],
            barWeight: 0,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: 0,
            lastSessionReps: 8,
            lastSessionRPE: 8,
            lastSessionDate: nil
        ).explanation
    }
}
