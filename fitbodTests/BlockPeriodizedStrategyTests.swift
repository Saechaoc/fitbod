//
//  BlockPeriodizedStrategyTests.swift
//  fitbodTests
//
//  Phase 4 coverage for block-aware prescription math.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("BlockPeriodizedStrategy", .serialized)
struct BlockPeriodizedStrategyTests {
    private let day: TimeInterval = 86_400
    private let exactPlates: [(weight: Double, countPerSide: Int)] = [
        (weight: 0.5, countPerSide: 1_000)
    ]

    private func makeBlock(
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        phases: [(BlockPhaseKind, Int, Double, Double)] = [
            (.accumulation, 3, 1.0, 0.75),
            (.intensification, 2, 0.85, 0.88),
            (.realization, 1, 0.6, 0.97),
            (.deload, 1, 0.5, 0.75)
        ]
    ) -> Block {
        let block = Block()
        block.name = "Peak"
        block.startDate = startDate
        block.endDate = startDate.addingTimeInterval(Double(phases.reduce(0) { $0 + $1.1 } * 7) * day)
        block.phases = phases.enumerated().map { index, spec in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = spec.0.rawValue
            phase.weeks = spec.1
            phase.volumeMultiplier = spec.2
            phase.intensityMultiplier = spec.3
            return phase
        }
        return block
    }

    private func prescribe(
        block: Block?,
        today: Date,
        lastSessionWeight: Double?,
        lastSessionReps: Int? = 8
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        BlockPeriodizedStrategy().prescribe(
            history: [],
            targetRepsLow: 6,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 0.5,
            plates: exactPlates,
            barWeight: 0,
            unit: .kg,
            minCalibrationSets: 10,
            lastSessionWeight: lastSessionWeight,
            lastSessionReps: lastSessionReps,
            lastSessionRPE: 8.0,
            lastSessionDate: today.addingTimeInterval(-7 * day),
            block: block,
            today: today
        )
    }

    @Test("accumulation phase applies intensity multiplier")
    func accumulationPhaseAppliesIntensityMultiplier() {
        let block = makeBlock()
        let result = prescribe(block: block, today: block.startDate, lastSessionWeight: 100)

        #expect(result.weight == 75)
        #expect(result.explanation.formulaName == "Block periodized")
        #expect(result.explanation.computedLine?.contains("accumulation") == true)
    }

    @Test("intensification phase applies higher intensity")
    func intensificationPhaseAppliesHigherIntensity() {
        let block = makeBlock()
        let today = block.startDate.addingTimeInterval(3 * 7 * day)
        let result = prescribe(block: block, today: today, lastSessionWeight: 100)

        #expect(result.weight == 88)
        #expect(result.explanation.computedLine?.contains("0.88") == true)
    }

    @Test("realization phase applies peak intensity")
    func realizationPhaseAppliesPeakIntensity() {
        let block = makeBlock()
        let today = block.startDate.addingTimeInterval(5 * 7 * day)
        let result = prescribe(block: block, today: today, lastSessionWeight: 100)

        #expect(result.weight == 97)
        #expect(result.explanation.computedLine?.contains("realization") == true)
    }

    @Test("deload week holds baseline weight")
    func deloadWeekHoldsBaselineWeight() {
        let block = makeBlock()
        let today = block.startDate.addingTimeInterval(6 * 7 * day)
        let result = prescribe(block: block, today: today, lastSessionWeight: 100)

        #expect(result.weight == 100)
        #expect(result.explanation.computedLine?.hasPrefix("Deload week:") == true)
        #expect(result.explanation.deloadNoteLine != nil)
    }

    @Test("baseline falls back to last session")
    func baselineFallsBackToLastSession() {
        let block = makeBlock()
        let result = prescribe(block: block, today: block.startDate, lastSessionWeight: 95)

        #expect(result.weight == 71)
        #expect(result.explanation.computedLine?.contains("95") == true)
    }

    @Test("no baseline returns zero with log prompt")
    func noBaselineReturnsZeroWithLogPrompt() {
        let block = makeBlock()
        let result = prescribe(block: block, today: block.startDate, lastSessionWeight: nil)

        #expect(result.weight == 0)
        #expect(result.explanation.computedLine == "No prior data - log a baseline session first.")
    }

    @Test("no block returns baseline with degraded explanation")
    func noBlockReturnsBaselineWithDegradedExplanation() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let result = prescribe(block: nil, today: today, lastSessionWeight: 100)

        #expect(result.weight == 100)
        #expect(result.explanation.computedLine == "No block context - using baseline.")
        #expect(result.explanation.phaseContextLine == nil)
    }

    @Test("past end of block is treated as no block context")
    func pastEndOfBlockTreatedAsNoBlockContext() throws {
        let block = makeBlock()
        let endDate = try #require(block.endDate)
        let result = prescribe(
            block: block,
            today: endDate.addingTimeInterval(day),
            lastSessionWeight: 100
        )

        #expect(result.weight == 100)
        #expect(result.explanation.computedLine == "No block context - using baseline.")
    }

    @Test("phase context line set when block present")
    func phaseContextLineSetWhenBlockPresent() {
        let block = makeBlock()
        let result = prescribe(block: block, today: block.startDate, lastSessionWeight: 100)

        let line = result.explanation.phaseContextLine ?? ""
        #expect(line.contains("accumulation"))
        #expect(line.contains("Week"))
        #expect(line.contains("of"))
    }

    @Test("multiplier rounds down to plates")
    func multiplierRoundsDownToPlates() {
        let block = makeBlock(phases: [(.intensification, 1, 0.85, 0.883)])
        let result = prescribe(block: block, today: block.startDate, lastSessionWeight: 100)

        #expect(result.weight == 88)
        #expect(result.explanation.roundedLine.contains("88"))
    }
}
