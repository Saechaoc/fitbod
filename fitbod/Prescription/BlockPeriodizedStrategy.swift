//
//  BlockPeriodizedStrategy.swift
//  fitbod
//
//  Phase 4 block-aware progression strategy. Uses the current block phase
//  as the intensity curve and keeps deload-week weight at the baseline.
//

import Foundation

public struct BlockPeriodizedStrategy: ProgressionStrategy {
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

        guard let block, let phase = PeriodizationEngine.phase(for: block, on: today) else {
            return (
                weight: baseline,
                explanation: PrescriptionExplanation(
                    lastSessionLine: nil,
                    formulaName: "Block periodized",
                    computedLine: "No block context - using baseline.",
                    roundedWeight: baseline,
                    roundedLine: "-> \(Self.formattedKg(baseline)) \(unit.rawValue) (baseline)",
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
            let line = "Deload week: weight held at \(Self.formattedKg(baseline)) \(unit.rawValue)"
            return (
                weight: baseline,
                explanation: PrescriptionExplanation(
                    lastSessionLine: lastLine,
                    formulaName: "Block periodized",
                    computedLine: line,
                    roundedWeight: baseline,
                    roundedLine: "-> \(Self.formattedKg(baseline)) \(unit.rawValue) (baseline held)",
                    status: .notApplicable,
                    phaseContextLine: contextLine,
                    deloadNoteLine: "Working sets cut by ~50%. Weight held at baseline."
                )
            )
        }

        let rawTarget = baseline * phase.intensityMultiplier
        let rounded = PlateCalculator.roundDown(
            target: rawTarget,
            barWeight: barWeight,
            plates: plates
        )

        return (
            weight: rounded,
            explanation: PrescriptionExplanation(
                lastSessionLine: lastLine,
                formulaName: "Block periodized",
                computedLine: "Phase \(phase.kind.rawValue): baseline \(Self.formattedKg(baseline)) \(unit.rawValue) x \(Self.formatMultiplier(phase.intensityMultiplier)) -> \(Self.formattedKg(rawTarget)) \(unit.rawValue)",
                roundedWeight: rounded,
                roundedLine: "-> \(Self.formattedKg(rounded)) \(unit.rawValue) (plate-rounded)",
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
