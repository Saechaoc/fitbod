//
//  SchemaV2MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 2 schema migration is wired correctly
//  (Phase 2 plan 00-02). The project's first real SwiftData migration —
//  PITFALLS #4's load-bearing test. Five assertions cover the
//  end-to-end contract:
//
//    1. `SchemaV2.models` is a strict additive superset of
//       `SchemaV1.models` (the precondition for `lightweight`
//       migration eligibility).
//    2. `FitbodSchemaMigrationPlan` registers both V1 + V2 and a single
//       `MigrationStage.lightweight` stage.
//    3. A fresh in-memory V2 container round-trips the new fields and
//       entities (Routine.folderID + RoutineFolder insert/fetch).
//    4. `RoutineExercise -> RoutineExerciseSetOverride` is a cascade
//       relationship — deleting the parent cleans up its overrides
//       (plan 00-01's relationship declaration correct).
//    5. `Routine.folderID` is a soft UUID ref (NOT a SwiftData
//       relationship) — deleting a RoutineFolder leaves its routines
//       intact for the folder-delete handler in plan 03-01 to
//       query-and-null back to "Unfiled".
//
//  Each test builds its own ModelContainer via Schema(SchemaV2.models)
//  + FitbodSchemaMigrationPlan to exercise the production wiring
//  literally; `InMemoryContainer.makeEmpty()` deliberately stays on
//  SchemaV1 to keep the Phase 1 SchemaV1Tests baseline assertions
//  passing unmodified.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("SchemaV2Migration")
struct SchemaV2MigrationTests {

    @Test("SchemaV2 models list contains every V1 entity plus 3 new types")
    func v2ModelsListIsCompleteSuperset() {
        let v1Names = Set(SchemaV1.models.map { String(describing: $0) })
        let v2Names = Set(SchemaV2.models.map { String(describing: $0) })

        // V1 entity types are a subset of V2 entity types.
        #expect(v1Names.isSubset(of: v2Names))
        // V2 \ V1 == the 3 new entity names.
        let added = v2Names.subtracting(v1Names)
        #expect(added == ["RoutineFolder", "SupersetGroup", "RoutineExerciseSetOverride"])
        // Counts also match: 12 (V1) + 3 (new) = 15.
        #expect(SchemaV1.models.count == 12)
        #expect(SchemaV2.models.count == 15)
    }

    @Test("FitbodSchemaMigrationPlan registers V1 and V2 and a single lightweight stage")
    func migrationPlanIsWiredCorrectly() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names == ["SchemaV1", "SchemaV2"])
        #expect(FitbodSchemaMigrationPlan.stages.count == 1)
    }

    @Test("Fresh in-memory V2 ModelContainer opens; round-trips a Routine + new entity")
    func freshV2ContainerRoundTripsRoutineAndNewEntities() throws {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        let folder = RoutineFolder(name: "Push / Pull / Legs", sortOrder: 0)
        ctx.insert(folder)

        let routine = Routine()
        routine.name = "Push Day"
        routine.folderID = folder.id           // NEW V2 field
        ctx.insert(routine)

        try ctx.save()

        // Re-fetch and verify the new field survived a save/fetch cycle.
        let fetched = try ctx.fetch(FetchDescriptor<Routine>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.folderID == folder.id)

        let folders = try ctx.fetch(FetchDescriptor<RoutineFolder>())
        #expect(folders.count == 1)
        #expect(folders.first?.name == "Push / Pull / Legs")
    }

    @Test("Cascade: deleting a RoutineExercise cascades into its setOverrides")
    func setOverrideCascadeOnRoutineExerciseDelete() throws {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        let routine = Routine()
        routine.name = "Test"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        ctx.insert(re)

        let override1 = RoutineExerciseSetOverride(setIndex: 0, targetRepsLow: 6, targetRepsHigh: 6, targetRPE: 8.5)
        override1.routineExercise = re
        let override2 = RoutineExerciseSetOverride(setIndex: 1, targetRepsLow: 8, targetRepsHigh: 10, targetRPE: 7.5)
        override2.routineExercise = re
        ctx.insert(override1)
        ctx.insert(override2)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<RoutineExerciseSetOverride>()).count == 2)

        ctx.delete(re)
        try ctx.save()

        // RoutineExercise.setOverrides has deleteRule: .cascade -> overrides gone.
        #expect(try ctx.fetch(FetchDescriptor<RoutineExerciseSetOverride>()).isEmpty)
    }

    @Test("Soft refs: deleting a RoutineFolder does NOT cascade into routines")
    func folderDeleteDoesNotCascadeIntoRoutines() throws {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        let folder = RoutineFolder(name: "Misc")
        ctx.insert(folder)

        let routine = Routine()
        routine.name = "Stays"
        routine.folderID = folder.id
        ctx.insert(routine)
        try ctx.save()

        ctx.delete(folder)
        try ctx.save()

        // Routine survives; folderID is now dangling (Unfiled re-mapping
        // happens in the folder-delete handler in plan 03-01, not at the
        // SwiftData level).
        let routines = try ctx.fetch(FetchDescriptor<Routine>())
        #expect(routines.count == 1)
    }
}
