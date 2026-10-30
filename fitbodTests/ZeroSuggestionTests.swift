//
//  ZeroSuggestionTests.swift
//  fitbodTests
//
//  Ticket T61 (finding F33): a suggested weight of 0 is no suggestion.
//  Why-this-weight offers no Use for it, and a calibrating range of 0 to 0
//  shows the weight field's empty "—", which VoiceOver reads as "none".
//  Suggestions and ranges above 0 keep their numbers.
//

import SwiftUI
import Testing
@testable import fitbod

@MainActor
@Suite("ZeroSuggestion")
struct ZeroSuggestionTests {

    // MARK: - Why-this-weight's Use

    @Test("WHY offers Use for a suggestion above 0")
    func whyOffersUseAboveZero() {
        let sheet = WhyThisWeightSheet(explanation: suggestion(102.5), unitLabel: "lb")
        #expect(sheet.useTitle == "Use 102.5 ▸")
    }

    @Test("WHY offers no Use for an exercise with no history, which suggests 0")
    func whyOffersNoUseWithoutHistory() {
        let explanation = noHistorySuggestion()
        #expect(explanation.roundedWeight == 0)
        let sheet = WhyThisWeightSheet(explanation: explanation, unitLabel: "lb")
        #expect(sheet.useTitle == nil)
    }

    // MARK: - The read-only calibrating range

    @Test("A calibrating range of 0 to 0 shows the placeholder, read as none")
    func zeroRangeShowsPlaceholder() {
        let explanation = bodyweightCalibration()
        #expect(explanation.range == 0.0...0.0)
        let cell = weightCell(range: explanation.range)
        #expect(cell.rangeText == nil)
        #expect(cell.accessibilityLabelText == "Prescribed weight: none")
        #expect(cell.accessibilityValueText == "none")
    }

    @Test("A calibrating range above 0 shows its numbers", arguments: [
        (95.0...105.0, "95 – 105", "95 to 105"),
        (0.0...2.5, "0 – 2.5", "0 to 2.5"),
    ])
    func rangeAboveZeroShowsNumbers(range: ClosedRange<Double>, shown: String, spoken: String) {
        let cell = weightCell(range: range)
        #expect(cell.rangeText == "\(shown) lb")
        #expect(cell.accessibilityLabelText == "Prescribed weight range: \(spoken) lb")
        #expect(cell.accessibilityValueText == "")
    }

    // MARK: - Helpers

    /// A double-progression explanation that suggests `weight` lb.
    private func suggestion(_ weight: Double) -> PrescriptionExplanation {
        PrescriptionExplanation(
            lastSessionLine: "100 × 8 @ RPE 8 (Oct 23)",
            formulaName: "Double progression",
            computedLine: nil,
            roundedWeight: weight,
            roundedLine: "→ \(weight) lb (rounded down to 2.5 lb plates)",
            status: .notApplicable,
            bumpOccurred: true,
            range: nil
        )
    }

    /// What double progression explains for an exercise with no history.
    private func noHistorySuggestion() -> PrescriptionExplanation {
        DoubleProgressionStrategy().prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: nil,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: [],
            barWeight: 45,
            unit: .lb,
            minCalibrationSets: 10,
            lastSessionWeight: nil,
            lastSessionReps: nil,
            lastSessionRPE: nil,
            lastSessionDate: nil
        ).explanation
    }

    /// What RPE autoregulation explains for a bodyweight lift, still
    /// calibrating, whose last workout added no load.
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

    /// The weight cell as SetRow builds it for a set showing `range`.
    private func weightCell(range: ClosedRange<Double>?) -> PrescriptionWeightCell {
        PrescriptionWeightCell(
            weight: .constant(0),
            prescribed: 0,
            range: range,
            explanation: nil,
            unitLabel: "lb",
            wasManualOverride: .constant(false)
        )
    }
}
