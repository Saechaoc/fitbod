//
//  HybridStrategy.swift
//  fitbod
//
//  Phase 4 hybrid progression: block periodization provides the ceiling,
//  RPE autoregulation can pull the day down when readiness is lower.
//

import Foundation

public struct HybridStrategy: ProgressionStrategy {
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
        lastSessionDate: Date?,
        block: Block? = nil,
        today: Date = Date.now
    ) -> (weight: Double, explanation: PrescriptionExplanation) {

        let blockResult = BlockPeriodizedStrategy().prescribe(
            history: history,
            targetRepsLow: targetRepsLow,
            targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE,
            lastSessionRepsArray: lastSessionRepsArray,
            smallestIncrement: smallestIncrement,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE,
            lastSessionDate: lastSessionDate,
            block: block,
            today: today
        )

        let rpeResult = RPEAutoregStrategy().prescribe(
            history: history,
            targetRepsLow: targetRepsLow,
            targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE,
            lastSessionRepsArray: lastSessionRepsArray,
            smallestIncrement: smallestIncrement,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE,
            lastSessionDate: lastSessionDate,
            block: nil,
            today: today
        )

        let chosen: Double
        let source: String
        if blockResult.weight > 0 && rpeResult.weight > 0 {
            chosen = min(blockResult.weight, rpeResult.weight)
            source = chosen == blockResult.weight ? "block ceiling" : "rpe-driven"
        } else if blockResult.weight > 0 {
            chosen = blockResult.weight
            source = "block ceiling (rpe-no-history)"
        } else if rpeResult.weight > 0 {
            chosen = rpeResult.weight
            source = "rpe-driven (no-block-context)"
        } else {
            chosen = 0
            source = "no data"
        }

        return (
            weight: chosen,
            explanation: PrescriptionExplanation(
                lastSessionLine: rpeResult.explanation.lastSessionLine,
                formulaName: "Hybrid (block + RPE)",
                computedLine: "Block ceiling: \(Self.formattedKg(blockResult.weight)) kg | RPE target: \(Self.formattedKg(rpeResult.weight)) kg | Using: \(source) -> \(Self.formattedKg(chosen)) kg",
                roundedWeight: chosen,
                roundedLine: "-> \(Self.formattedKg(chosen)) kg (chose lower of block / RPE)",
                status: rpeResult.explanation.status,
                bumpOccurred: false,
                range: nil,
                phaseContextLine: blockResult.explanation.phaseContextLine,
                deloadNoteLine: blockResult.explanation.deloadNoteLine
            )
        )
    }
}

private extension HybridStrategy {
    static func formattedKg(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
