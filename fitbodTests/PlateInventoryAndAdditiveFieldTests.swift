//
//  PlateInventoryAndAdditiveFieldTests.swift
//  fitbodTests
//
//  PlateInventory round-trip and Phase 3 additive field defaults on the live schema.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("PlateInventoryAndAdditiveFields")
struct PlateInventoryAndAdditiveFieldTests {

    // MARK: - Helpers (used by round-trip tests)

    private func makeContext() throws -> ModelContext {
        let container = try InMemoryContainer.makeCurrent()
        return ModelContext(container)
    }

    // MARK: - 3. PlateInventory round-trip

    @Test("Current ModelContainer round-trips Phase 3 PlateInventory with plates")
    @MainActor
    func freshV3ContainerRoundTripsPlateInventory() throws {
        let ctx = try makeContext()

        let inv = PlateInventory()
        let plates: [PlateSpec] = [
            PlateSpec(weight: 20, countPerSide: 4),
            PlateSpec(weight: 5, countPerSide: 2),
        ]
        inv.availablePlates = plates
        ctx.insert(inv)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PlateInventory>())
        #expect(fetched.count == 1)
        let refetched = try #require(fetched.first)

        // availablePlates JSON round-trip must equal the input (Equatable).
        #expect(refetched.availablePlates == plates)

        // equipmentKind defaults to .barbell.
        #expect(refetched.equipmentKind == .barbell)

        // barWeight defaults to 20.0.
        #expect(refetched.barWeight == 20.0)
    }

    // MARK: - 4. Additive Phase 3 fields round-trip

    @Test("Additive Phase 3 fields round-trip with correct defaults in current schema")
    @MainActor
    func additiveFieldsRoundTrip() throws {
        let ctx = try makeContext()

        // UserSettings.default() must carry the two new Phase 3 fields.
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        let settingsFetched = try ctx.fetch(FetchDescriptor<UserSettings>())
        let s = try #require(settingsFetched.first)
        #expect(s.defaultIncrementKg == 2.5)
        #expect(s.minCalibrationSets == 10)

        // Exercise carries 3 new nullable fields defaulting to nil.
        let ex = Exercise()
        ctx.insert(ex)
        try ctx.save()

        let exFetched = try ctx.fetch(FetchDescriptor<Exercise>())
        let e = try #require(exFetched.first)
        #expect(e.smallestIncrement == nil)
        #expect(e.barWeightOverride == nil)
        #expect(e.unitOverrideRaw == nil)

        // SetEntry carries the new wasManualOverride flag defaulting to false.
        let entry = SetEntry()
        ctx.insert(entry)
        try ctx.save()

        let entryFetched = try ctx.fetch(FetchDescriptor<SetEntry>())
        let se = try #require(entryFetched.first)
        #expect(se.wasManualOverride == false)
    }
}
