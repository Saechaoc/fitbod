//
//  HybridStrategyTests.swift
//  fitbodTests
//
//  Phase 4 coverage for block ceiling + RPE autoregulation composition.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("HybridStrategy", .serialized)
struct HybridStrategyTests {
    private let day: TimeInterval = 86_400
    private let exactPlates: [(weight: Double, countPerSide: Int)] = [
        (weight: 0.5, countPerSide: 1_000)
    ]

    private func makeBlock(
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        kind: BlockPhaseKind = .accumulation,
        intensity: Double = 1.0
    ) -> Block {
        let block = Block()
        block.name = "Hybrid Block"
        block.startDate = startDate
        block.endDate = startDate.addingTimeInterval(7 * day)

        let phase = BlockPhase()
        phase.block = block
        phase.orderIndex = 0
        phase.nameRaw = kind.rawValue
        phase.weeks = 1
        phase.volumeMultiplier = kind == .deload ? 0.5 : 1.0
        phase.intensityMultiplier = intensity
        block.phases = [phase]
        return block
    }

    private func callHybrid(
        block: Block?,
        today: Date,
        targetRPE: Double? = 8.0,
        history: [HistoryPoint] = [],
        lastSessionWeight: Double?,
        lastSessionReps: Int? = 8,
        lastSessionRPE: Double? = 8.0,
        minCalibrationSets: Int = 10
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        HybridStrategy().prescribe(
            history: history,
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: targetRPE,
            lastSessionRepsArray: nil,
            smallestIncrement: 0.5,
            plates: exactPlates,
            barWeight: 0,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE,
            lastSessionDate: today.addingTimeInterval(-7 * day),
            block: block,
            today: today
        )
    }

    private func callBlock(
        block: Block?,
        today: Date,
        lastSessionWeight: Double?
    ) -> Double {
        BlockPeriodizedStrategy().prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 0.5,
            plates: exactPlates,
            barWeight: 0,
            minCalibrationSets: 10,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: 8,
            lastSessionRPE: 8.0,
            lastSessionDate: today.addingTimeInterval(-7 * day),
            block: block,
            today: today
        ).weight
    }

    private func callRPE(
        today: Date,
        targetRPE: Double? = 8.0,
        history: [HistoryPoint] = [],
        lastSessionWeight: Double?,
        lastSessionReps: Int? = 8,
        lastSessionRPE: Double? = 8.0,
        minCalibrationSets: Int = 10
    ) -> Double {
        RPEAutoregStrategy().prescribe(
            history: history,
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: targetRPE,
            lastSessionRepsArray: nil,
            smallestIncrement: 0.5,
            plates: exactPlates,
            barWeight: 0,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE,
            lastSessionDate: today.addingTimeInterval(-7 * day)
        ).weight
    }

    @Test("hybrid chooses lower of block and RPE")
    func hybridChoosesLowerOfBlockAndRPE() {
        let block = makeBlock(intensity: 0.75)
        let today = block.startDate
        let result = callHybrid(block: block, today: today, lastSessionWeight: 120)

        let blockWeight = callBlock(block: block, today: today, lastSessionWeight: 120)
        let rpeWeight = callRPE(today: today, lastSessionWeight: 120)

        #expect(result.weight == min(blockWeight, rpeWeight))
        #expect(result.weight == blockWeight)
        #expect(result.explanation.computedLine?.contains("block ceiling") == true)
    }

    @Test("hybrid chooses RPE when lower on fatigue")
    func hybridChoosesRPEWhenLowerOnFatigue() {
        let block = makeBlock(intensity: 1.0)
        let today = block.startDate
        let result = callHybrid(block: block, today: today, targetRPE: 6.0, lastSessionWeight: 120)

        let blockWeight = callBlock(block: block, today: today, lastSessionWeight: 120)
        let rpeWeight = callRPE(today: today, targetRPE: 6.0, lastSessionWeight: 120)

        #expect(result.weight == min(blockWeight, rpeWeight))
        #expect(result.weight == rpeWeight)
        #expect(result.explanation.computedLine?.contains("rpe-driven") == true)
    }

    @Test("hybrid never exceeds either branch when both are nonzero")
    func blockNeverExceededByRPE() {
        for index in 0..<10 {
            let intensity = 0.72 + (Double(index) * 0.03)
            let lastWeight = 90.0 + Double(index * 5)
            let targetRPE = 6.0 + Double(index % 4)
            let block = makeBlock(intensity: intensity)
            let today = block.startDate

            let result = callHybrid(
                block: block,
                today: today,
                targetRPE: targetRPE,
                lastSessionWeight: lastWeight
            )
            let blockWeight = callBlock(block: block, today: today, lastSessionWeight: lastWeight)
            let rpeWeight = callRPE(today: today, targetRPE: targetRPE, lastSessionWeight: lastWeight)

            if blockWeight > 0 && rpeWeight > 0 {
                #expect(result.weight <= blockWeight)
                #expect(result.weight <= rpeWeight)
            }
        }
    }

    @Test("hybrid falls back to block when RPE has no calibration input")
    func hybridFallsBackToBlockWhenRPEHasNoHistory() {
        let block = makeBlock(intensity: 0.75)
        let result = callHybrid(
            block: block,
            today: block.startDate,
            lastSessionWeight: 100,
            lastSessionReps: nil,
            lastSessionRPE: nil
        )

        #expect(result.weight == callBlock(block: block, today: block.startDate, lastSessionWeight: 100))
        #expect(result.explanation.computedLine?.contains("rpe-no-history") == true)
    }

    @Test("hybrid falls back to RPE when no block baseline exists")
    func hybridFallsBackToRPEWhenNoBlockBaselineExists() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let history = (0..<10).map { index in
            HistoryPoint(e1RM: 140, date: today.addingTimeInterval(-Double(index) * day))
        }
        let result = callHybrid(
            block: nil,
            today: today,
            history: history,
            lastSessionWeight: nil,
            lastSessionReps: nil,
            lastSessionRPE: nil,
            minCalibrationSets: 10
        )

        #expect(result.weight > 0)
        #expect(result.explanation.computedLine?.contains("no-block-context") == true)
    }

    @Test("hybrid returns zero when both branches are empty")
    func hybridReturnsZeroWhenBothBranchesEmpty() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let result = callHybrid(block: nil, today: today, lastSessionWeight: nil)

        #expect(result.weight == 0)
        #expect(result.explanation.computedLine?.contains("no data") == true)
    }

    @Test("hybrid forwards calibration status")
    func hybridForwardsCalibrationStatus() {
        let block = makeBlock(intensity: 1.0)
        let history = (0..<5).map { HistoryPoint(e1RM: 130, date: block.startDate.addingTimeInterval(-Double($0) * day)) }
        let result = callHybrid(
            block: block,
            today: block.startDate,
            history: history,
            lastSessionWeight: 100,
            minCalibrationSets: 10
        )

        #expect(result.explanation.status == .calibrating(current: 5, threshold: 10))
    }

    @Test("hybrid deload note passes through")
    func hybridDeloadNotePassesThrough() {
        let block = makeBlock(kind: .deload, intensity: 0.75)
        let result = callHybrid(block: block, today: block.startDate, lastSessionWeight: 100)

        #expect(result.weight == 100)
        #expect(result.explanation.deloadNoteLine != nil)
    }

    @Test("factory returns hybrid for hybrid kind")
    func factoryReturnsHybridForHybridKind() {
        #expect(ProgressionStrategyFactory.make(for: .hybrid) is HybridStrategy)
    }

    @Test("factory returns block-periodized for block kind")
    func factoryReturnsBlockPeriodizedForBlockKind() {
        #expect(ProgressionStrategyFactory.make(for: .block) is BlockPeriodizedStrategy)
    }
}
