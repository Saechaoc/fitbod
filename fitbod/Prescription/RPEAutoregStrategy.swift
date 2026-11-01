//
//  RPEAutoregStrategy.swift
//  fitbod
//
//  RPE autoregulation progression strategy. Two modes:
//
//  CALIBRATING (history.count < minCalibrationSets):
//    Uses TuchschererTable as prior. Back-calculates e1RM from the most recent
//    logged set (lastSessionWeight / percent(reps:rpe:)), then applies the
//    target reps/RPE percent to derive the point estimate. Expands ±5% into a
//    plate-rounded range. Returns range != nil and status .calibrating(...).
//    Its computed line shows that e1RM, the target's percent and the raw
//    target, in the calibrated line's shape. A last set without an RPE
//    gives no e1RM, so nothing is suggested, and the explanation says why.
//
//  CALIBRATED (history.count >= minCalibrationSets):
//    Calls Calibration.predict(history:targetReps:targetRPE:) for the Gaussian-
//    weighted mean e1RM. Applies TuchschererTable percent for the target slot.
//    Returns range == nil and status .calibrated.
//
//  NOTE: The caller (plan 03-08 SessionFactory) is responsible for filtering
//  nil-RPE history points before passing the [HistoryPoint] array per
//  RESEARCH §Pitfall 7. The strategy assumes every HistoryPoint has a valid
//  e1RM derived from a non-nil RPE. It does NOT re-filter the input.
//
//  Phase 5: a separate `OneRepMaxEstimator` (Brzycki ≤6 / Epley 6–10 / nil >10
//  per REQUIREMENTS PROG-02) was extracted in `fitbod/Prescription/` for use
//  by `PlateauDetector` and Phase 6 charts. `RPEAutoregStrategy` itself does
//  NOT use that estimator — RPE-based progression back-calculates e1RM via
//  TuchschererTable percent lookup, not Brzycki/Epley. The extraction does
//  not change this file's public surface.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable (value type,
//  per-prescription value configuration — FOUND-07).
//

import Foundation

/// RPE autoregulation strategy. Switches from TuchschererTable prior to
/// Calibration.predict LOWESS once enough history is accumulated.
public struct RPEAutoregStrategy: ProgressionStrategy {

    public var roundingIncrement: Double?

    public init(roundingIncrement: Double? = nil) {
        self.roundingIncrement = roundingIncrement
    }

    public func prescribe(
        history: [HistoryPoint],
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        lastSessionRepsArray: [Int]?,
        smallestIncrement: Double,
        plates: [(weight: Double, countPerSide: Int)],
        barWeight: Double,
        unit: WeightUnit,
        minCalibrationSets: Int,
        lastSessionWeight: Double?,
        lastSessionReps: Int?,
        lastSessionRPE: Double?,
        lastSessionDate: Date?,
        block: Block? = nil,
        today: Date = Date.now
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        let increment = roundingIncrement.map { $0.isFinite && $0 > 0 ? $0 : 2.5 }

        // Phase 4 protocol extension: RPE autoregulation ignores block context.
        let effectiveRPE = targetRPE ?? 8.0
        let lastLine = Self.lastSessionLine(
            weight: lastSessionWeight,
            reps: lastSessionReps,
            rpe: lastSessionRPE,
            date: lastSessionDate,
            unit: unit
        )

        // MARK: Calibrated path

        if history.count >= minCalibrationSets {
            if let calibratedE1RM = Calibration.predict(
                history: history,
                targetReps: targetRepsHigh,
                targetRPE: effectiveRPE,
                now: today
            ), let pct = TuchschererTable.percent(reps: targetRepsHigh, rpe: effectiveRPE) {

                let rawTarget = calibratedE1RM * pct
                let rounded = PlateCalculator.roundDown(
                    target: rawTarget,
                    barWeight: barWeight,
                    plates: plates,
                    increment: increment
                )

                let pctDisplay = Int((pct * 100).rounded())
                let computedLine = "Target e1RM \(Self.fmt1(calibratedE1RM)) \(unit.rawValue) → \(pctDisplay)% × \(targetRepsHigh) → \(Self.fmt1(rawTarget)) \(unit.rawValue)"
                let roundedLine = "→ \(Self.fmtG(rounded)) \(unit.rawValue) (rounded down to \(Self.fmtG(increment ?? smallestIncrement)) \(unit.rawValue) \(increment == nil ? "plates" : "increments"))"

                let exp = PrescriptionExplanation(
                    lastSessionLine: lastLine,
                    formulaName: "RPE autoregulation",
                    computedLine: computedLine,
                    roundedWeight: rounded,
                    roundedLine: roundedLine,
                    status: .calibrated,
                    bumpOccurred: false,
                    range: nil
                )
                return (weight: rounded, explanation: exp)
            }
            // Calibration.predict returned nil (empty or negligible weights) —
            // fall through to calibrating-with-no-data branch.
        }

        // MARK: Calibrating path — with prior session data

        if let lastWeight = lastSessionWeight,
           let lastReps = lastSessionReps,
           let lastRPE = lastSessionRPE,
           let priorPct = TuchschererTable.percent(reps: lastReps, rpe: lastRPE),
           priorPct > 0,
           let targetPct = TuchschererTable.percent(reps: targetRepsHigh, rpe: effectiveRPE) {

            let e1RM = lastWeight / priorPct
            let rawTarget = e1RM * targetPct

            let rounded = PlateCalculator.roundDown(
                target: rawTarget,
                barWeight: barWeight,
                plates: plates,
                increment: increment
            )

            // ±5% range, both endpoints rounded DOWN with the prescription's rounding mode.
            let lowRaw = rawTarget * 0.95
            let highRaw = rawTarget * 1.05
            let lowRounded = PlateCalculator.roundDown(
                target: lowRaw,
                barWeight: barWeight,
                plates: plates,
                increment: increment
            )
            let highRounded = PlateCalculator.roundDown(
                target: highRaw,
                barWeight: barWeight,
                plates: plates,
                increment: increment
            )
            let range: ClosedRange<Double> = lowRounded...max(lowRounded, highRounded)

            let pctDisplay = Int((targetPct * 100).rounded())
            let computedLine = "Last session e1RM \(Self.fmt1(e1RM)) \(unit.rawValue) → \(pctDisplay)% × \(targetRepsHigh) → \(Self.fmt1(rawTarget)) \(unit.rawValue)"
            let roundedLine = "→ \(Self.fmtG(rounded)) \(unit.rawValue) (rounded down to \(Self.fmtG(increment ?? smallestIncrement)) \(unit.rawValue) \(increment == nil ? "plates" : "increments"))"

            let exp = PrescriptionExplanation(
                lastSessionLine: lastLine,
                formulaName: "RPE autoregulation",
                computedLine: computedLine,
                roundedWeight: rounded,
                roundedLine: roundedLine,
                status: .calibrating(current: history.count, threshold: minCalibrationSets),
                bumpOccurred: false,
                range: range
            )
            return (weight: rounded, explanation: exp)
        }

        // MARK: Calibrating path — no prior session data
        // A last top set without an RPE gives no e1RM to calibrate from,
        // so nothing is suggested, but it is still the last session: the
        // computed line says why, and the rounded line asks for a weight.

        let exp = PrescriptionExplanation(
            lastSessionLine: lastLine,
            formulaName: "RPE autoregulation",
            computedLine: lastLine == nil ? nil : "Last session has no RPE to calibrate from. Log one on this set.",
            roundedWeight: 0,
            roundedLine: lastLine == nil ? "No prior data - log a set to begin calibrating." : "Choose a starting weight.",
            status: .calibrating(current: history.count, threshold: minCalibrationSets),
            bumpOccurred: false,
            range: nil
        )
        return (weight: 0, explanation: exp)
    }
}

// MARK: - Private Helpers

private extension RPEAutoregStrategy {

    /// Format a weight to 1 decimal place (e.g. "122.0").
    static func fmt1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Format a weight with %g (strips trailing zeros, e.g. "100" not "100.0").
    static func fmtG(_ value: Double) -> String {
        String(format: "%g", value)
    }

    /// Builds the "last session" line shown in the WhyThisWeightSheet.
    /// Format: "{weight} {unit} × {reps} @ RPE {rpe} (May 15)". A top set
    /// logged without an RPE is still the last session: "{weight} {unit} ×
    /// {reps} (May 15)".
    static func lastSessionLine(
        weight: Double?,
        reps: Int?,
        rpe: Double?,
        date: Date?,
        unit: WeightUnit
    ) -> String? {
        guard let weight, let reps, let date else { return nil }
        let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
        let rpeStr = rpe.map { " @ RPE \(String(format: "%.1f", $0))" } ?? ""
        return "\(fmtG(weight)) \(unit.rawValue) × \(reps)\(rpeStr) (\(dateStr))"
    }
}
