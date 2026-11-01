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
//  per-prescription value configuration — FOUND-07).
//

import Foundation

/// Double-progression strategy: bump weight by `smallestIncrement` when every
/// working set in the prior session hit `targetRepsHigh`; hold otherwise.
public struct DoubleProgressionStrategy: ProgressionStrategy {

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

        // Phase 4 protocol extension: double progression ignores block context.
        // No prior data — first session.
        guard let lastWeight = lastSessionWeight else {
            let explanation = PrescriptionExplanation(
                lastSessionLine: nil,
                formulaName: "Double progression",
                computedLine: nil,
                roundedWeight: 0,
                roundedLine: "No prior data - starting at prescribed weight.",
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
            date: lastSessionDate,
            unit: unit
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
            plates: plates,
            increment: increment
        )

        let roundedLine = "→ \(Self.formatWeight(rounded)) \(unit.rawValue) (rounded down to \(Self.formatWeight(increment ?? smallestIncrement)) \(unit.rawValue) \(increment == nil ? "plates" : "increments"))"

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
    /// Format: "{weight} {unit} × {reps} @ RPE {rpe} (May 15)". A top set
    /// logged without an RPE is still the last session: "{weight} {unit} ×
    /// {reps} (May 15)".
    /// Matches UI-SPEC § WhyThisWeightSheet and Phase 2 ExerciseHistoryView convention.
    static func lastSessionLine(
        weight: Double,
        reps: Int?,
        rpe: Double?,
        date: Date?,
        unit: WeightUnit
    ) -> String? {
        guard let reps, let date else { return nil }
        let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
        let rpeStr = rpe.map { " @ RPE \(String(format: "%.1f", $0))" } ?? ""
        return "\(formatWeight(weight)) \(unit.rawValue) × \(reps)\(rpeStr) (\(dateStr))"
    }
}
