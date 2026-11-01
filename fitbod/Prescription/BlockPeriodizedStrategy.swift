//
//  BlockPeriodizedStrategy.swift
//  fitbod
//
//  Phase 4 block-aware progression strategy. Uses the current block phase
//  as the intensity curve and keeps deload-week weight at the baseline.
//

import Foundation

public struct BlockPeriodizedStrategy: ProgressionStrategy {
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

        let baseline = (lastSessionWeight ?? 0) > 0 ? lastSessionWeight ?? 0 : 0
        let increment = roundingIncrement.map { $0.isFinite && $0 > 0 ? $0 : 2.5 }
        let heldBaseline = increment != nil && baseline > 0
            ? PlateCalculator.roundDown(target: baseline, barWeight: barWeight, plates: plates, increment: increment)
            : baseline
        let heldRoundedLine = increment.map {
            "-> \(Self.formattedKg(heldBaseline)) \(unit.rawValue) (rounded down to \(Self.formattedKg($0)) \(unit.rawValue) increments)"
        }

        guard let block, let phase = PeriodizationEngine.phase(for: block, on: today) else {
            return (
                weight: heldBaseline,
                explanation: PrescriptionExplanation(
                    lastSessionLine: nil,
                    formulaName: "Block periodized",
                    computedLine: "No block context - using baseline.",
                    roundedWeight: heldBaseline,
                    roundedLine: heldRoundedLine ?? "-> \(Self.formattedKg(baseline)) \(unit.rawValue) (baseline)",
                    status: .notApplicable
                )
            )
        }

        guard baseline > 0 else {
            return (
                weight: 0,
                explanation: PrescriptionExplanation(
                    lastSessionLine: nil,
                    formulaName: "Block periodized",
                    computedLine: "No prior data - log a baseline session first.",
                    roundedWeight: 0,
                    roundedLine: "No prior data - log a baseline session first.",
                    status: .notApplicable,
                    phaseContextLine: Self.phaseContextLine(for: block, on: today)
                )
            )
        }

        let lastLine = Self.lastSessionLine(baseline: baseline, reps: lastSessionReps, unit: unit)
        let contextLine = Self.phaseContextLine(for: block, on: today)

        if phase.kind == .deload {
            let line = "Deload week: weight held at \(Self.formattedKg(heldBaseline)) \(unit.rawValue)"
            return (
                weight: heldBaseline,
                explanation: PrescriptionExplanation(
                    lastSessionLine: lastLine,
                    formulaName: "Block periodized",
                    computedLine: line,
                    roundedWeight: heldBaseline,
                    roundedLine: heldRoundedLine ?? "-> \(Self.formattedKg(baseline)) \(unit.rawValue) (baseline held)",
                    status: .notApplicable,
                    phaseContextLine: contextLine,
                    deloadNoteLine: increment == nil
                        ? "Working sets cut by ~50%. Weight held at baseline."
                        : "Working sets cut by ~50%. Baseline rounded down to the available increment."
                )
            )
        }

        let rawTarget = baseline * phase.intensityMultiplier
        let rounded = PlateCalculator.roundDown(
            target: rawTarget,
            barWeight: barWeight,
            plates: plates,
            increment: increment
        )

        return (
            weight: rounded,
            explanation: PrescriptionExplanation(
                lastSessionLine: lastLine,
                formulaName: "Block periodized",
                computedLine: "Phase \(phase.kind.rawValue): baseline \(Self.formattedKg(baseline)) \(unit.rawValue) x \(Self.formatMultiplier(phase.intensityMultiplier)) -> \(Self.formattedKg(rawTarget)) \(unit.rawValue)",
                roundedWeight: rounded,
                roundedLine: "-> \(Self.formattedKg(rounded)) \(unit.rawValue) (\(increment == nil ? "plate-rounded" : "increment-rounded"))",
                status: .notApplicable,
                phaseContextLine: contextLine
            )
        )
    }
}

private extension BlockPeriodizedStrategy {
    static func phaseContextLine(for block: Block, on date: Date) -> String? {
        guard
            let phase = PeriodizationEngine.phase(for: block, on: date),
            let weekIndex = PeriodizationEngine.weekIndex(for: block, on: date)
        else { return nil }

        let totalWeeks = (block.phases ?? []).reduce(0) { $0 + $1.weeks }
        return "\(phase.kind.rawValue) phase - Week \(weekIndex + 1) of \(totalWeeks)"
    }

    static func lastSessionLine(baseline: Double, reps: Int?, unit: WeightUnit) -> String? {
        guard let reps else { return nil }
        return "Last: \(formattedKg(baseline)) \(unit.rawValue) x \(reps)"
    }

    static func formatMultiplier(_ multiplier: Double) -> String {
        String(format: "%.2f", multiplier)
    }

    static func formattedKg(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
