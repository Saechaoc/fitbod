import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct PlateEntryTests {
    enum Failure: Error { case disk }

    @Test func rejectsInvalidAndDuplicateWeightsBeforeWriting() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let inventory = PlateInventory()
        context.insert(inventory)
        inventory.availablePlates = [PlateSpec(weight: 2.5, countPerSide: 2)]
        inventory.updatedAt = .distantPast
        try context.save()
        let original = inventory.availablePlatesData
        for weight in [0, -1, .nan, .infinity, 2.5] {
            #expect(throws: PlateEntryError.self) {
                try PlateInventoryEditor.addPlate(weight: weight, to: inventory, context: context)
            }
            #expect(inventory.availablePlatesData == original)
            #expect(inventory.updatedAt == .distantPast)
            #expect(!context.hasChanges)
        }
    }

    @Test func failedAddKeepsInventoryAndRetries() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let inventory = PlateInventory()
        context.insert(inventory)
        inventory.availablePlates = [PlateSpec(weight: 20, countPerSide: 4)]
        inventory.updatedAt = .distantPast
        try context.save()
        let original = inventory.availablePlatesData
        #expect(throws: Failure.self) {
            try PlateInventoryEditor.addPlate(weight: 3.75, to: inventory, context: context,
                save: { _ in throw Failure.disk })
        }
        #expect(!context.hasChanges)
        #expect(inventory.availablePlatesData == original)
        #expect(inventory.updatedAt == .distantPast)
        let saved = try #require(try ModelContext(context.container).fetch(FetchDescriptor<PlateInventory>()).first)
        #expect(saved.availablePlatesData == original)

        try PlateInventoryEditor.addPlate(weight: 3.75, to: inventory, context: context)
        let retried = try #require(try ModelContext(context.container).fetch(FetchDescriptor<PlateInventory>()).first)
        #expect(retried.availablePlates == [PlateSpec(weight: 20, countPerSide: 4), PlateSpec(weight: 3.75, countPerSide: 2)])
        #expect(retried.updatedAt > .distantPast)
    }

    @Test func legacyDuplicateRowsCombineWithoutWrites() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let inventory = PlateInventory()
        context.insert(inventory)
        let old = [PlateSpec(weight: 20, countPerSide: 4, color: "red"),
                   PlateSpec(weight: 20, countPerSide: 2), PlateSpec(weight: 0, countPerSide: 2),
                   PlateSpec(weight: 5, countPerSide: Int.max), PlateSpec(weight: 5, countPerSide: 1)]
        inventory.availablePlatesData = try JSONEncoder().encode(old)
        try context.save()
        let original = inventory.availablePlatesData
        #expect(inventory.availablePlates == [PlateSpec(weight: 20, countPerSide: 6, color: "red"),
                                             PlateSpec(weight: 5, countPerSide: Int.max)])
        #expect(Set(inventory.availablePlates.map(\.weight)).count == inventory.availablePlates.count)
        #expect(inventory.availablePlatesData == original)
        #expect(!context.hasChanges)
    }

    @Test func tinyPositivePlatesDoNotOverflowTheCalculator() {
        let plates = [(weight: 0.000_000_000_000_000_000_01, countPerSide: 2)]
        #expect(PlateCalculator.solve(target: 100, barWeight: 20, plates: plates) == nil)
        #expect(PlateCalculator.roundDown(target: 100, barWeight: 20, plates: plates) == 20)
    }
}
