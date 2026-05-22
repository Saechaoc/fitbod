//
//  SchemaV3MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 3 schema migration is wired correctly
//  (Phase 3 plan 03-01). Mirrors SchemaV2MigrationTests.swift verbatim
//  shape. Four assertions cover the end-to-end contract:
//
//    1. `SchemaV3.models` is SchemaV2.models + [PlateInventory.self]
//       (strict additive superset — precondition for lightweight migration).
//    2. `FitbodSchemaMigrationPlan` registers V1, V2, and V3 with TWO
//       lightweight migration stages.
//    3. A fresh in-memory V3 container round-trips a PlateInventory with
//       a [PlateSpec] payload.
//    4. All additive Phase 3 fields (UserSettings, Exercise, SetEntry)
//       round-trip their new defaults correctly.
//
//  Each test that touches ModelContainer builds its own instance via
//  Schema(SchemaV3.models) + FitbodSchemaMigrationPlan to exercise the
//  production wiring literally.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("SchemaV3Migration")
struct SchemaV3MigrationTests {

    // MARK: - Helpers (used by round-trip tests)

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

    // MARK: - 1. Schema model list shape

    @Test("SchemaV3 models list equals SchemaV2.models + PlateInventory.self")
    func schemaV3ModelsListEqualsV2PlusPlateInventory() {
        // SchemaV3 must be a strict additive superset of SchemaV2.
        let v2Names = Set(SchemaV2.models.map { String(describing: $0) })
        let v3Names = Set(SchemaV3.models.map { String(describing: $0) })

        // Every V2 entity must be present in V3.
        #expect(v2Names.isSubset(of: v3Names))

        // V3 \ V2 == exactly the new entity.
        let added = v3Names.subtracting(v2Names)
        #expect(added == ["PlateInventory"])

        // Counts: V2 has 15 entities; V3 adds 1.
        #expect(SchemaV2.models.count == 15)
        #expect(SchemaV3.models.count == SchemaV2.models.count + 1)

        // PlateInventory.self must be explicitly present in SchemaV3.models.
        #expect(SchemaV3.models.contains(where: { $0 == PlateInventory.self }))
    }

    // MARK: - 2. Migration plan wiring (3 schemas, 2 stages)

    @Test("FitbodSchemaMigrationPlan registers V1+V2+V3 and TWO lightweight stages")
    func migrationPlanWiringIsV1V2V3() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3"])
        #expect(FitbodSchemaMigrationPlan.schemas.count == 3)
        #expect(FitbodSchemaMigrationPlan.stages.count == 2)
    }

    // MARK: - 3. PlateInventory round-trip

    @Test("Fresh in-memory V3 ModelContainer opens; round-trips PlateInventory with plates")
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

    @Test("Additive Phase 3 fields round-trip with correct defaults")
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
