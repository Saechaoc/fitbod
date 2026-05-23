//
//  DoubleProgressionStrategy.swift
//  fitbod
//
//  Pure-function double-progression strategy. Advances weight by
//  smallestIncrement when ALL working sets from the prior session hit the
//  top of the rep range. Holds weight on any miss. First-session (no prior
//  data) returns weight 0 and a "no prior data" explanation.
//
//  Bump trigger: lastSessionRepsArray != nil && !lastSessionRepsArray.isEmpty
//  && lastSessionRepsArray.allSatisfy { $0 >= targetRepsHigh }.
//  The caller (plan 03-08 SessionFactory) is responsible for supplying the
//  working-set rep array from the most recent session via PreviousMatchingIntent.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable (value type,
//  no stored mutable state — FOUND-07).
//

import Foundation

/// Double-progression strategy: bump weight by `smallestIncrement` when every
/// working set in the prior session hit `targetRepsHigh`; hold otherwise.
public struct DoubleProgressionStrategy: ProgressionStrategy {

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

        // No prior data — first session.
        guard let lastWeight = lastSessionWeight else {
            let explanation = PrescriptionExplanation(
                lastSessionLine: nil,
                formulaName: "Double progression",
                computedLine: nil,
                roundedWeight: 0,
                roundedLine: "No prior data — starting at prescribed weight.",
                status: .notApplicable,
                bumpOccurred: false,
                range: nil
            )
            return (weight: 0, explanation: explanation)
        }

        // Format last session line.
        let lastLine = Self.lastSessionLine(
            weight: lastWeight,
            reps: lastSessionReps,
            rpe: lastSessionRPE,
            date: lastSessionDate
        )

        // Determine if a bump is triggered.
        let bump: Bool
        if let repsArray = lastSessionRepsArray,
           !repsArray.isEmpty,
           repsArray.allSatisfy({ $0 >= targetRepsHigh }) {
            bump = true
        } else {
            bump = false
        }

        let rawTarget = bump ? lastWeight + smallestIncrement : lastWeight
        let rounded = PlateCalculator.roundDown(
            target: rawTarget,
            barWeight: barWeight,
            plates: plates
        )

        let roundedLine = "→ \(Self.formatWeight(rounded)) kg (rounded down to \(Self.formatWeight(smallestIncrement)) kg plates)"

        let explanation = PrescriptionExplanation(
            lastSessionLine: lastLine,
            formulaName: "Double progression",
            computedLine: nil,
            roundedWeight: rounded,
            roundedLine: roundedLine,
            status: .notApplicable,
            bumpOccurred: bump,
            range: nil
        )
        return (weight: rounded, explanation: explanation)
    }
}

// MARK: - Private Helpers

private extension DoubleProgressionStrategy {

    /// Formats a weight value for display using %g to omit trailing zeros.
    static func formatWeight(_ weight: Double) -> String {
        String(format: "%g", weight)
    }

    /// Builds the "last session" line shown in the WhyThisWeightSheet.
    /// Format: "{weight} kg × {reps} @ RPE {rpe} (May 15)"
    /// Matches UI-SPEC § WhyThisWeightSheet and Phase 2 ExerciseHistoryView convention.
    static func lastSessionLine(
        weight: Double,
        reps: Int?,
        rpe: Double?,
        date: Date?
    ) -> String? {
        guard let reps, let rpe, let date else { return nil }
        let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
        return "\(formatWeight(weight)) kg × \(reps) @ RPE \(String(format: "%.1f", rpe)) (\(dateStr))"
    }
}
