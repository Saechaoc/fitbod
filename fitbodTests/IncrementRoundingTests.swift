import Foundation
import Testing
@testable import fitbod

@Suite("Explicit increment rounding")
struct IncrementRoundingTests {
    private static let today = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Explicit increments use their grid and an exercise's bar override")
    func incrementGridAndBarAnchor() {
        #expect(PlateCalculator.roundDown(target: 26, barWeight: 0,
            plates: [(weight: 10, countPerSide: 1)], increment: 2.5) == 25)
        #expect(abs(PlateCalculator.roundDown(target: 0.3, barWeight: 0,
            plates: [], increment: 0.1) - 0.3) < 1e-12)
        #expect(PlateCalculator.roundDown(target: 24.999, barWeight: 0,
            plates: [], increment: 2.5) == 22.5)
        #expect(PlateCalculator.roundDown(target: 29.9, barWeight: 7,
            plates: [], increment: 5) == 27)
        #expect(PlateCalculator.roundDown(target: 5, barWeight: 7,
            plates: [], increment: 5) == 7)
    }

    @Test("Empty plate inventories retain legacy behavior unless increment mode is explicit")
    func emptyInventoryDoesNotImplyIncrementMode() {
        #expect(PlateCalculator.roundDown(target: 100, barWeight: 45, plates: []) == 45)
        #expect(PlateCalculator.roundDown(target: 25, barWeight: 0, plates: []) == 0)
    }

    @Test("Double progression rounds both held and bumped weights to the increment")
    func doubleProgressionRoundsHoldAndBump() {
        let strategy = DoubleProgressionStrategy(roundingIncrement: 5)
        let held = prescribe(strategy, reps: [8, 7])
        #expect(held.weight == 25)
        #expect(held.explanation.roundedWeight == 25)
        #expect(!held.explanation.bumpOccurred)
        let bumped = prescribe(strategy, reps: [8, 8])
        #expect(bumped.weight == 30)
        #expect(bumped.explanation.bumpOccurred)
    }

    @Test("Calibrating RPE rounds its point and both range endpoints")
    func calibratingRPERoundsPointAndRange() throws {
        let result = prescribe(RPEAutoregStrategy(roundingIncrement: 5))
        #expect(result.weight == 25)
        #expect(result.explanation.roundedWeight == 25)
        #expect(result.explanation.status == .calibrating(current: 0, threshold: 10))
        let range = try #require(result.explanation.range)
        #expect(range.lowerBound == 25)
        #expect(range.upperBound == 30)
    }

    @Test("Calibrated RPE rounds the predicted point with the same increment")
    func calibratedRPERoundsPoint() throws {
        let percent = try #require(TuchschererTable.percent(reps: 8, rpe: 8))
        let history = [HistoryPoint(e1RM: 29.9 / percent, date: Self.today)]
        let result = prescribe(RPEAutoregStrategy(roundingIncrement: 5),
                               history: history, minimumCalibrationSets: 1)
        #expect(result.weight == 25)
        #expect(result.explanation.roundedWeight == 25)
        #expect(result.explanation.status == .calibrated)
        #expect(result.explanation.range == nil)
    }

    // Block and BlockPhase are transient SwiftData models; keep their access on the main actor.
    @MainActor
    @Test("Block baseline and deload paths honor explicit increment rounding")
    func blockBaselinePathsRound() {
        let strategy = BlockPeriodizedStrategy(roundingIncrement: 5)
        #expect(prescribe(strategy).weight == 25)
        let deload = makeBlock(kind: .deload, intensity: 0.5)
        let result = prescribe(strategy, block: deload)
        #expect(result.weight == 25)
        #expect(result.explanation.roundedWeight == 25)
        #expect(result.explanation.deloadNoteLine != nil)
    }

    // Block and BlockPhase are transient SwiftData models; keep their access on the main actor.
    @MainActor
    @Test("Block intensity multiplies the original baseline before rounding")
    func blockIntensityUsesUnroundedBaseline() {
        let block = makeBlock(kind: .intensification, intensity: 1.2)
        let result = prescribe(BlockPeriodizedStrategy(roundingIncrement: 5), block: block)
        // 29.9 x 1.2 = 35.88 -> 35; rounding the baseline first would produce 30.
        #expect(result.weight == 35)
        #expect(result.explanation.roundedWeight == 35)
    }

    // The block fixture reads transient SwiftData relationships on the main actor.
    @MainActor
    @Test("Hybrid forwards increment mode to both child strategies")
    func hybridForwardsIncrementToBothBranches() {
        let block = makeBlock(kind: .intensification, intensity: 1.2)
        let strategy = HybridStrategy(roundingIncrement: 5)
        // RPE's rounded 25 is below the block's rounded 35.
        #expect(prescribe(strategy, block: block).weight == 25)
        // Without an RPE, the rounded block branch must supply the weight.
        #expect(prescribe(strategy, lastRPE: nil, block: block).weight == 35)
    }

    @Test("Increment mode keeps first-session prescriptions at zero", arguments: [
        ProgressionKind.double, .rpe, .block, .hybrid
    ])
    func noHistoryStillReturnsZero(kind: ProgressionKind) {
        var strategy = ProgressionStrategyFactory.make(for: kind)
        strategy.roundingIncrement = 5
        let result = prescribe(strategy, lastWeight: nil)
        #expect(result.weight == 0)
        #expect(result.explanation.roundedWeight == 0)
    }

    private func prescribe(
        _ strategy: any ProgressionStrategy,
        lastWeight: Double? = 29.9,
        reps: [Int]? = nil,
        lastRPE: Double? = 8,
        history: [HistoryPoint] = [],
        minimumCalibrationSets: Int = 10,
        block: Block? = nil
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        strategy.prescribe(
            history: history, targetRepsLow: 6, targetRepsHigh: 8, targetRPE: 8,
            lastSessionRepsArray: reps, smallestIncrement: 5, plates: [], barWeight: 0,
            unit: .lb, minCalibrationSets: minimumCalibrationSets,
            lastSessionWeight: lastWeight, lastSessionReps: 8, lastSessionRPE: lastRPE,
            lastSessionDate: Self.today.addingTimeInterval(-86_400), block: block, today: Self.today
        )
    }

    // Mirrors the existing pure strategy fixtures; these models are never persisted.
    @MainActor
    private func makeBlock(kind: BlockPhaseKind, intensity: Double) -> Block {
        let block = Block()
        block.startDate = Self.today
        let phase = BlockPhase()
        phase.nameRaw = kind.rawValue
        phase.weeks = 1
        phase.intensityMultiplier = intensity
        phase.block = block
        block.phases = [phase]
        return block
    }
}
