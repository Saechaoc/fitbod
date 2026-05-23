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
//  No SwiftData coupling. No @MainActor. Implicitly Sendable (value type,
//  no stored mutable state — FOUND-07).
//

import Foundation

/// RPE autoregulation strategy. Switches from TuchschererTable prior to
/// Calibration.predict LOWESS once enough history is accumulated.
public struct RPEAutoregStrategy: ProgressionStrategy {

    public init() {}

    public func prescribe(
        history: [HistoryPoint],
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        lastSessionRepsArray: [Int]?,
        smallestIncrement: Double,
        plates: [(weight: Double, countPerSide: Int)],
        barWeight: Double,
        minCalibrationSets: Int,
        lastSessionWeight: Double?,
        lastSessionReps: Int?,
        lastSessionRPE: Double?,
        lastSessionDate: Date?
    ) -> (weight: Double, explanation: PrescriptionExplanation) {

        let effectiveRPE = targetRPE ?? 8.0
        let lastLine = Self.lastSessionLine(
            weight: lastSessionWeight,
            reps: lastSessionReps,
            rpe: lastSessionRPE,
            date: lastSessionDate
        )

        // MARK: Calibrated path

        if history.count >= minCalibrationSets {
            if let calibratedE1RM = Calibration.predict(
                history: history,
                targetReps: targetRepsHigh,
                targetRPE: effectiveRPE
            ), let pct = TuchschererTable.percent(reps: targetRepsHigh, rpe: effectiveRPE) {

                let rawTarget = calibratedE1RM * pct
                let rounded = PlateCalculator.roundDown(
                    target: rawTarget,
                    barWeight: barWeight,
                    plates: plates
                )

                let pctDisplay = Int((pct * 100).rounded())
                let computedLine = "Target e1RM \(Self.fmt1(calibratedE1RM)) kg → \(pctDisplay)% × \(targetRepsHigh) → \(Self.fmt1(rawTarget)) kg"
                let roundedLine = "→ \(Self.fmtG(rounded)) kg (rounded down to \(Self.fmtG(smallestIncrement)) kg plates)"

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
                plates: plates
            )

            // ±5% range, both endpoints rounded DOWN to plates.
            let lowRaw = rawTarget * 0.95
            let highRaw = rawTarget * 1.05
            let lowRounded = PlateCalculator.roundDown(
                target: lowRaw,
                barWeight: barWeight,
                plates: plates
            )
            let highRounded = PlateCalculator.roundDown(
                target: highRaw,
                barWeight: barWeight,
                plates: plates
            )
            let range: ClosedRange<Double> = lowRounded...max(lowRounded, highRounded)

            let roundedLine = "→ \(Self.fmtG(rounded)) kg (rounded down to \(Self.fmtG(smallestIncrement)) kg plates)"

            let exp = PrescriptionExplanation(
                lastSessionLine: lastLine,
                formulaName: "RPE autoregulation",
                computedLine: nil,
                roundedWeight: rounded,
                roundedLine: roundedLine,
                status: .calibrating(current: history.count, threshold: minCalibrationSets),
                bumpOccurred: false,
                range: range
            )
            return (weight: rounded, explanation: exp)
        }

        // MARK: Calibrating path — no prior session data

        let exp = PrescriptionExplanation(
            lastSessionLine: nil,
            formulaName: "RPE autoregulation",
            computedLine: nil,
            roundedWeight: 0,
            roundedLine: "No prior data — log a set to begin calibrating.",
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
    /// Format: "{weight} kg × {reps} @ RPE {rpe} (May 15)"
    static func lastSessionLine(
        weight: Double?,
        reps: Int?,
        rpe: Double?,
        date: Date?
    ) -> String? {
        guard let weight, let reps, let rpe, let date else { return nil }
        let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
        return "\(fmtG(weight)) kg × \(reps) @ RPE \(String(format: "%.1f", rpe)) (\(dateStr))"
    }
}
