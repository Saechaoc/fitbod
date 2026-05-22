//
//  PlateInventoryTests.swift
//  fitbodTests
//
//  Four @Test functions covering the PlateInventory model shipped by
//  plan 03-01 (Phase 3 schema scaffold):
//
//    1. jsonRoundTripPreservesAllFields — [PlateSpec] JSON accessor
//       round-trips weight, countPerSide, and color correctly.
//    2. emptyPlateArraySerializesAsEmptyJSON — empty [] assignment
//       decodes back to an empty array (not nil).
//    3. equipmentKindAccessorFallbackOnBadRaw — unknown raw value
//       falls back to .barbell gracefully.
//    4. equipmentKindAccessorRoundTrip — get/set pair is symmetric.
//
//  The JSON round-trip tests operate on PlateInventory instances without
//  a ModelContext (the computed accessor is pure in-memory encode/decode).
//  The accessor tests are also context-free — they only touch computed
//  properties on the @Model class.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PlateInventory", .serialized)
struct PlateInventoryTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - 1. JSON round-trip (all fields)

    @Test("jsonRoundTripPreservesAllFields — weight, countPerSide, color survive encode/decode")
    func jsonRoundTripPreservesAllFields() throws {
        let ctx = try makeContext()
        let inv = PlateInventory()
        ctx.insert(inv)

        let input: [PlateSpec] = [
            PlateSpec(weight: 25, countPerSide: 4, color: "red"),
            PlateSpec(weight: 2.5, countPerSide: 2, color: nil),
        ]
        inv.availablePlates = input

        // Verify the Data accessor is non-empty after setting.
        #expect(inv.availablePlatesData.count > 0)

        // Verify the round-trip returns Equatable-equal values.
        #expect(inv.availablePlates == input)
    }

    // MARK: - 2. Empty array serialises as empty (not nil)

    @Test("emptyPlateArraySerializesAsEmptyJSON — empty assignment decodes back to []")
    func emptyPlateArraySerializesAsEmptyJSON() throws {
        let ctx = try makeContext()
        let inv = PlateInventory()
        ctx.insert(inv)

        inv.availablePlates = []

        // availablePlatesData must be set (not the default Data()).
        // An empty JSON array "[]" encodes to non-empty Data.
        #expect(!inv.availablePlatesData.isEmpty)

        // The round-trip must decode back to an empty array (not nil, not [PlateSpec](...)).
        #expect(inv.availablePlates == [])

        // Confirm by decoding the raw Data directly.
        let decoded = try JSONDecoder().decode([PlateSpec].self, from: inv.availablePlatesData)
        #expect(decoded.isEmpty)
    }

    // MARK: - 3. Graceful fallback on bad equipmentKindRaw

    @Test("equipmentKindAccessorFallbackOnBadRaw — unknown raw value returns .barbell")
    func equipmentKindAccessorFallbackOnBadRaw() throws {
        let ctx = try makeContext()
        let inv = PlateInventory()
        ctx.insert(inv)

        // Inject a value that does not correspond to any PlateEquipmentKind case.
        inv.equipmentKindRaw = "nonsense_kind"

        // Accessor must return .barbell (the graceful fallback).
        #expect(inv.equipmentKind == .barbell)
    }

    // MARK: - 4. equipmentKind get/set round-trip

    @Test("equipmentKindAccessorRoundTrip — set .ezBar writes 'ez_bar' raw; get returns .ezBar")
    func equipmentKindAccessorRoundTrip() throws {
        let ctx = try makeContext()
        let inv = PlateInventory()
        ctx.insert(inv)

        // Set via the computed accessor.
        inv.equipmentKind = .ezBar

        // The raw string must match the enum's rawValue.
        #expect(inv.equipmentKindRaw == "ez_bar")

        // The computed getter must return the same case.
        #expect(inv.equipmentKind == .ezBar)
    }
}
