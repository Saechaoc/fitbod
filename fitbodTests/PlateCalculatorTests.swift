//
//  PlateCalculatorTests.swift
//  fitbodTests
//
//  Tests for the PlateCalculator greedy plate-loading solver (plan 03-03), and
//  for the calculator sheet opened from a working set: where it starts, that
//  it leaves the set as it was, and how TARGET reads typing (RM-025).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("PlateCalculator")
struct PlateCalculatorTests {

    // Standard kg barbell inventory (with 1.25 microplates).
    private let standardKgPlatesWithMicroplates: [(weight: Double, countPerSide: Int)] = [
        (weight: 25, countPerSide: 4),
        (weight: 20, countPerSide: 2),
        (weight: 15, countPerSide: 2),
        (weight: 10, countPerSide: 2),
        (weight: 5,  countPerSide: 2),
        (weight: 2.5, countPerSide: 2),
        (weight: 1.25, countPerSide: 2),
    ]

    // Standard kg barbell inventory WITHOUT 1.25 microplates.
    // Per-side increment is 2.5 kg — cannot load odd increments like 41.25 kg/side.
    private let standardKgPlatesNoMicroplates: [(weight: Double, countPerSide: Int)] = [
        (weight: 25, countPerSide: 4),
        (weight: 20, countPerSide: 2),
        (weight: 15, countPerSide: 2),
        (weight: 10, countPerSide: 2),
        (weight: 5,  countPerSide: 2),
        (weight: 2.5, countPerSide: 2),
    ]

    @Test("solve100kgWith20kgBar")
    func solve100kgWith20kgBar() throws {
        // 100 kg target, 20 kg bar → 40 kg per side.
        // Greedy: 1×25 (rem 15), 1×15 (rem 0) → platesPerSide = [(25,1),(15,1)].
        let result = PlateCalculator.solve(
            target: 100,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        let stack = try #require(result)
        #expect(stack.totalWeight == 100.0)
        #expect(stack.platesPerSide.count == 2)
        #expect(stack.platesPerSide[0].weight == 25.0)
        #expect(stack.platesPerSide[0].count == 1)
        #expect(stack.platesPerSide[1].weight == 15.0)
        #expect(stack.platesPerSide[1].count == 1)
    }

    @Test("roundDown102_5kgWith2_5kgIncrement")
    func roundDown102_5kgWith2_5kgIncrement() throws {
        // 102.5 kg target, 20 kg bar, no 1.25 microplates.
        // Per side: (102.5 - 20) / 2 = 41.25 kg — not achievable without 1.25 plates.
        // Greedy loads: 1×25 + 1×15 = 40 per side → 100 kg total.
        let result = PlateCalculator.roundDown(
            target: 102.5,
            barWeight: 20,
            plates: standardKgPlatesNoMicroplates
        )
        #expect(result == 100.0)
    }

    @Test("belowBarReturnsBar")
    func belowBarReturnsBar() throws {
        // Target (15) < barWeight (20) → return barWeight (20).
        let result = PlateCalculator.roundDown(
            target: 15,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        #expect(result == 20.0)
    }

    @Test("epsilonFloatDriftGuard")
    func epsilonFloatDriftGuard() throws {
        // 97.4999 is within float rounding noise of 97.5.
        // Per-side for 97.5: (97.5 - 20) / 2 = 38.75 → 1×25 + 1×10 + 1×2.5 + 1×1.25 = 38.75
        // Both targets should resolve to the same plate-loadable result: 97.5 kg.
        let resultA = PlateCalculator.roundDown(
            target: 97.4999,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        let resultB = PlateCalculator.roundDown(
            target: 97.5,
            barWeight: 20,
            plates: standardKgPlatesWithMicroplates
        )
        #expect(resultA == resultB)
        #expect(resultB == 97.5)
    }

    @Test("noSolutionReturnsNil")
    func noSolutionReturnsNil() throws {
        // Only 20 kg plates × 2 per side → maximum loadable: 20 + 2*(20*2) = 100 kg.
        // 1000 kg is not achievable.
        let result = PlateCalculator.solve(
            target: 1000,
            barWeight: 20,
            plates: [(weight: 20, countPerSide: 2)]
        )
        #expect(result == nil)
    }

    // MARK: - Opened from a working set (RM-025)

    private func barbellSet(weight: Double, typed: Bool = false, complete: Bool = false) -> SetEntry {
        let entry = SetEntry()
        entry.weight = weight
        entry.wasManualOverride = typed
        entry.isComplete = complete
        return entry
    }

    @Test("A set opens the calculator on its weight and its exercise's own bar and unit")
    @MainActor
    func setPrefillsWeightAndBar() throws {
        let bench = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        bench.barWeightOverride = 35
        bench.unitOverride = .kg
        let sheet = try #require(PlateCalculatorSheet.forSet(barbellSet(weight: 225), exercise: bench, offeredWeight: 185))
        #expect(sheet.startEquipment == .barbell)
        #expect(sheet.startTarget == 225)
        #expect(sheet.barOverride == 35)
        #expect(sheet.unitOverride == .kg, "The exercise's unit labels the plates, unconverted")
    }

    @Test("A set with no weight typed opens on its offer, a logged one on its own")
    @MainActor
    func setPrefillsOffer() throws {
        let bench = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        let offered = try #require(PlateCalculatorSheet.forSet(barbellSet(weight: 0), exercise: bench, offeredWeight: 185))
        #expect(offered.startTarget == 185)
        #expect(offered.barOverride == nil, "Without its own bar the inventory's is used")
        #expect(offered.unitOverride == nil, "Without its own unit the lifter's is used")
        // A logged set shows no offer, so there is no weight to open on.
        let logged = try #require(PlateCalculatorSheet.forSet(
            barbellSet(weight: 0, complete: true), exercise: bench, offeredWeight: 185
        ))
        #expect(logged.startTarget == PlateCalculatorSheet.defaultTarget)
    }

    /// A typed 0 is an unloaded set; an assisted set stores its help as a
    /// negative weight.
    @Test("An unloaded or assisted set opens at the default target", arguments: [0.0, -40.0])
    @MainActor
    func setWithoutPlatesOpensAtDefault(_ weight: Double) throws {
        let bench = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        let sheet = try #require(PlateCalculatorSheet.forSet(
            barbellSet(weight: weight, typed: true), exercise: bench, offeredWeight: 185
        ))
        #expect(sheet.startTarget == PlateCalculatorSheet.defaultTarget)
    }

    @Test("Each plate-loaded equipment opens its own inventory", arguments: [
        (Equipment.barbell, PlateEquipmentKind.barbell),
        (.dumbbell, .dumbbell),
        (.ezBar, .ezBar),
        (.trapBar, .trapBar),
    ])
    @MainActor
    func setOpensItsEquipment(_ pair: (Equipment, PlateEquipmentKind)) throws {
        let exercise = Exercise.previewSample(name: "Lift", equipment: pair.0, mechanic: .compound)
        let sheet = try #require(PlateCalculatorSheet.forSet(barbellSet(weight: 60), exercise: exercise, offeredWeight: nil))
        #expect(sheet.startEquipment == pair.1)
    }

    @Test("An exercise that loads no plates offers no calculator",
          arguments: [Equipment.cable, .machine, .kettlebell, .smithMachine, .bodyweight])
    @MainActor
    func otherEquipmentHasNoCalculator(_ equipment: Equipment) {
        let exercise = Exercise.previewSample(name: "Lift", equipment: equipment, mechanic: .compound)
        #expect(PlateCalculatorSheet.forSet(barbellSet(weight: 60), exercise: exercise, offeredWeight: nil) == nil)
        #expect(PlateCalculatorSheet.forSet(barbellSet(weight: 60), exercise: nil, offeredWeight: nil) == nil)
    }

    /// The return to the set: opening the calculator reads the set and
    /// writes nothing, so the logger shows the set as it was.
    @Test("Opening the calculator leaves the set as it was")
    @MainActor
    func openingLeavesTheSetUnchanged() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let bench = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
        context.insert(bench)
        let sessionExercise = SessionExercise()
        context.insert(sessionExercise)
        sessionExercise.exercise = bench
        let entry = barbellSet(weight: 315, typed: true)
        context.insert(entry)
        entry.sessionExercise = sessionExercise
        try context.save()

        let sheet = try #require(PlateCalculatorSheet.forSet(entry, exercise: bench, offeredWeight: 225))
        #expect(sheet.startTarget == 315)
        #expect(!context.hasChanges)
        #expect(entry.weight == 315 && entry.wasManualOverride && !entry.isComplete)
    }

    @Test("TARGET reads a weight typed in the lifter's locale")
    @MainActor
    func typedTargetUsesTheLocale() {
        let us = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")
        #expect(PlateCalculatorSheet.typedTarget("225", locale: us) == 225)
        #expect(PlateCalculatorSheet.typedTarget("102,5", locale: german) == 102.5)
        #expect(PlateCalculatorSheet.typedTarget("0", locale: us) == 0)
        // Text that is not a weight keeps the last target.
        for text in ["", ".", "abc", "-5", "1.2.3"] {
            #expect(PlateCalculatorSheet.typedTarget(text, locale: us) == nil, "\(text) is not a target")
        }
    }

    @Test("225 and 315 lb load from the default lb barbell set")
    func realLoadsSolve() throws {
        let plates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .lb)
            .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        let bar = PlateInventoryDefaults.barWeight(for: .barbell, unitSystem: .lb)
        let twoTwentyFive = try #require(PlateCalculator.solve(target: 225, barWeight: bar, plates: plates))
        #expect(twoTwentyFive.platesPerSide.map(\.weight) == [45] && twoTwentyFive.platesPerSide.map(\.count) == [2])
        let threeFifteen = try #require(PlateCalculator.solve(target: 315, barWeight: bar, plates: plates))
        #expect(threeFifteen.platesPerSide.map(\.weight) == [45] && threeFifteen.platesPerSide.map(\.count) == [3])
    }
}
