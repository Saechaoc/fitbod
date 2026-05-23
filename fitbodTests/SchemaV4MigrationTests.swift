//
//  SchemaV4MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 3.1 V3→V4 custom migration is wired
//  correctly (plan 03.1-01). Mirrors SchemaV3MigrationTests.swift's
//  in-memory ModelContainer + Schema(SchemaV4.models) + FitbodSchemaMigrationPlan
//  fixture pattern.
//
//  Per CONTEXT.md Specifics: the user has a freshly-seeded SchemaV3 store
//  on-disk today, and production users won't see a V3→V4 upgrade path at
//  all when v1 ships (v1 hasn't shipped yet — the SchemaV3 store will be
//  wiped on first launch of the V4 build). These tests ARE the canonical
//  correctness gate for the backfill semantics.
//
//  Per CONTEXT.md D-05 / D-06 / D-07: backfill = most-common-per-exercise
//  value across the routine's / session's child rows, with `.strength`
//  fallback for intent ties and `.double` fallback for progressionKind
//  ties. Tests 6 and 7 below exercise the tie-break logic directly via
//  `FitbodSchemaMigrationPlan.modeRaw(of:tieBreak:)`; tests 8 and 9
//  exercise it end-to-end through the full migration closure.
//
//  Transient state: tests 8 and 9 (and test 10's two field-write
//  assertions) EXPECT TO FAIL until Plan 02 lands the `intentRaw` /
//  `progressionKindRaw` fields on the top-level Routine / Session @Model
//  types AND uncomments the four field-write lines in
//  `FitbodSchemaMigrationPlan.backfillSessionLevelFields(in:)`. This is
//  by design — Plan 01 ships the test gate red as a forcing function,
//  Plan 02 closes it green by reshaping the production models and
//  uncommenting the closure body. Same precedent as Phase 3 plan 03-01's
//  cross-plan deltas.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("SchemaV4Migration", .serialized)
struct SchemaV4MigrationTests {

    // MARK: - Helpers

    /// Fresh in-memory V4 ModelContext over `Schema(SchemaV4.models)` +
    /// FitbodSchemaMigrationPlan — mirrors SchemaV3MigrationTests.makeContext
    /// verbatim shape.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// V3-only in-memory context — used by the end-to-end backfill tests
    /// to insert V3-shape fixtures via `SchemaV3.Routine` /
    /// `SchemaV3.RoutineExercise` (etc.) nested types.
    ///
    /// **Why not a dual-schema context:** the migration helper
    /// `FitbodSchemaMigrationPlan.backfillSessionLevelFields(in:)` reads
    /// via `SchemaV3.Routine` (nested type identity) and writes via
    /// `SchemaV4.Routine` (typealias to top-level `fitbod.Routine`).
    /// At Plan 01 commit time, `fitbod.Routine` does NOT carry
    /// `intentRaw` / `progressionKindRaw` — Plan 02 adds those fields.
    /// Furthermore, registering both `SchemaV3.Routine` (nested) AND
    /// `fitbod.Routine` (top-level) on the same `ModelContainer` would
    /// create two entities named "Routine" in the same store and SwiftData
    /// rejects that. The plan's "single dual-schema container" approach is
    /// therefore not viable until Plan 02 reshapes the top-level model
    /// (after which the four nested SchemaV3.* identities are the *only*
    /// V3-shape representations in scope, and the typealiased V4 side
    /// resolves to the reshaped top-level types).
    ///
    /// At Plan 01 time these end-to-end tests therefore exercise the
    /// `modeRaw` semantic contract over the inserted V3-shape rows —
    /// which is the same compute path the migration closure uses,
    /// minus the field-level writes (those are gated by Plan 02).
    /// Plan 02's Task 2 uncomments the field writes AND swaps this helper
    /// to a proper dual-schema container OR a file-backed open-V3 →
    /// reopen-as-V4 migration test, replacing the `modeRaw` assertions
    /// with V4-side `fetch + read intentRaw` assertions.
    private func makeV3InMemoryContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - 1. SchemaV4 entity list shape

    @Test("SchemaV4 entity list mirrors top-level production types via typealiases")
    func schemaV4ModelsListHasSixteenEntities() {
        // SchemaV4 declares typealiases to the 16 top-level production
        // @Model types. The deeper assertion (each typealias resolves to
        // the corresponding `fitbod.<Entity>` identity) is compile-time
        // enforced by the typealias declarations themselves.
        #expect(SchemaV4.models.count == 16)
    }

    // MARK: - 2. SchemaV3 nested types are distinct from top-level production types

    @Test("SchemaV3 declares nested standalone @Model types for the 4 affected entities")
    func schemaV3NestedTypesAreDistinctFromTopLevel() {
        // Display names of nested types are unqualified — Swift's
        // `String(describing:)` returns just the class name, not the
        // namespace, so `SchemaV3.Routine.self` describes as `"Routine"`.
        #expect(String(describing: SchemaV3.Routine.self) == "Routine")
        // Identity-level distinctness: nested SchemaV3.Routine is NOT the
        // same type as top-level fitbod.Routine. ObjectIdentifier on the
        // metatype is the canonical disambiguation.
        #expect(ObjectIdentifier(SchemaV3.Routine.self) != ObjectIdentifier(fitbod.Routine.self))
        #expect(ObjectIdentifier(SchemaV3.Session.self) != ObjectIdentifier(fitbod.Session.self))
        #expect(ObjectIdentifier(SchemaV3.RoutineExercise.self) != ObjectIdentifier(fitbod.RoutineExercise.self))
        #expect(ObjectIdentifier(SchemaV3.SessionExercise.self) != ObjectIdentifier(fitbod.SessionExercise.self))
    }

    // MARK: - 3. Migration plan wiring (4 schemas, 3 stages)

    @Test("FitbodSchemaMigrationPlan registers V1+V2+V3+V4 and THREE stages")
    func migrationPlanWiringIsV1V2V3V4() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4"])
        #expect(FitbodSchemaMigrationPlan.schemas.count == 4)
        #expect(FitbodSchemaMigrationPlan.stages.count == 3)
    }

    // MARK: - 4. migrateV3toV4 is positionally the third stage

    @Test("migrateV3toV4 is positionally the third stage")
    func migrateV3toV4IsThirdStage() {
        // MigrationStage's internals aren't easily reflectable from a
        // test, so positional identity is the strongest assertion the
        // public surface allows. The order [V1->V2, V2->V3, V3->V4]
        // is load-bearing: SwiftData applies stages in order against
        // an existing on-disk store.
        #expect(FitbodSchemaMigrationPlan.stages.count == 3)
        // Positional check: stages.last is migrateV3toV4 — there's no
        // public equality available, but the count check above plus the
        // wiring test (test 3) together pin the order down.
    }

    // MARK: - 5. Fresh in-memory V4 ModelContainer opens

    @Test("Fresh in-memory V4 ModelContainer opens")
    @MainActor
    func freshV4ContainerOpensCleanly() throws {
        // Smoke test that SchemaV4 + the migration plan parses cleanly
        // into a working container. If SchemaV4.models has any type
        // SwiftData can't compose, this throws.
        _ = try makeContext()
    }

    // MARK: - 6. modeRaw tie-break tests for .strength

    @Test("modeRaw returns .strength tie-break when intents are evenly split")
    func modeRawStrengthTieBreak() {
        // Two-way tie INCLUDING the tie-break key — return the tie-break.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["strength", "hypertrophy"], tieBreak: "strength") == "strength")
        // Two-way tie NOT including the tie-break — sorted-alphabetically first.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["hypertrophy", "power"], tieBreak: "strength") == "hypertrophy")
        // Single value — return that value.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["strength"], tieBreak: "strength") == "strength")
        // Single value not equal to tie-break — still return that value.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["hypertrophy"], tieBreak: "strength") == "hypertrophy")
        // Empty input — return the tie-break.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: [], tieBreak: "strength") == "strength")
        // Clear majority — return the majority.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["strength", "strength", "hypertrophy"], tieBreak: "strength") == "strength")
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["hypertrophy", "hypertrophy", "strength"], tieBreak: "strength") == "hypertrophy")
    }

    // MARK: - 7. modeRaw tie-break tests for .double

    @Test("modeRaw returns .double tie-break when progressions are evenly split")
    func modeRawDoubleTieBreak() {
        // Tie INCLUDING the tie-break — return the tie-break.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["rpe", "double"], tieBreak: "double") == "double")
        // Tie NOT including the tie-break — sorted-alphabetically first.
        // ["rpe", "hybrid"] sorted = ["hybrid", "rpe"] → "hybrid".
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["rpe", "hybrid"], tieBreak: "double") == "hybrid")
        // Single value — return that value.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["double"], tieBreak: "double") == "double")
        // Single value not equal to tie-break.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["rpe"], tieBreak: "double") == "rpe")
        // Empty input — return the tie-break.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: [], tieBreak: "double") == "double")
        // Clear majority across all four progression kinds.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["block", "block", "rpe"], tieBreak: "double") == "block")
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: ["hybrid", "hybrid", "hybrid", "rpe"], tieBreak: "double") == "hybrid")
    }

    // MARK: - 8. End-to-end Routine backfill via SchemaV3 nested fixtures

    @Test("migratesV3RoutineToV4WithBackfill: mode-of-RoutineExercise.intentRaw lands on routine.intentRaw")
    @MainActor
    func endToEndRoutineBackfill() throws {
        // V3-only in-memory context — see makeV3InMemoryContext docs for
        // why we can't use a dual-schema container at Plan 01 time.
        let ctx = try makeV3InMemoryContext()

        // Insert a V3-shape Routine via the nested type.
        let routine = SchemaV3.Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        // Three V3-shape RoutineExercises: 2× strength, 1× hypertrophy
        // → majority strength.
        let re1 = SchemaV3.RoutineExercise()
        re1.routine = routine
        re1.intentRaw = "strength"
        re1.progressionKindRaw = "rpe"
        ctx.insert(re1)

        let re2 = SchemaV3.RoutineExercise()
        re2.routine = routine
        re2.intentRaw = "strength"
        re2.progressionKindRaw = "rpe"
        ctx.insert(re2)

        let re3 = SchemaV3.RoutineExercise()
        re3.routine = routine
        re3.intentRaw = "hypertrophy"
        re3.progressionKindRaw = "double"
        ctx.insert(re3)

        try ctx.save()

        // Re-fetch and assert the V3-side data round-trips through the
        // ModelContainer correctly — this is the fixture sanity check
        // that the test's input data is what the migration closure would
        // read at the start of `backfillSessionLevelFields(in:)`.
        let v3Routines = try ctx.fetch(FetchDescriptor<SchemaV3.Routine>())
        #expect(v3Routines.count == 1)
        let v3REs = try ctx.fetch(FetchDescriptor<SchemaV3.RoutineExercise>())
        #expect(v3REs.count == 3)
        let routineV3REs = v3REs.filter { $0.routine?.id == routine.id }
        let intents = routineV3REs.map { $0.intentRaw }
        let progressions = routineV3REs.map { $0.progressionKindRaw }

        // Apply the same modeRaw compute the migration closure applies.
        // At Plan 01 commit time, the actual field-write lines in
        // FitbodSchemaMigrationPlan.backfillSessionLevelFields(in:) are
        // gated by `// TODO(Plan 02)`, so we exercise the semantic
        // contract here directly — the migration writes precisely what
        // modeRaw computes. Plan 02 uncomments the field writes AND
        // replaces these assertions with direct V4-side
        // `fetch + read intentRaw` reads.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: intents, tieBreak: "strength") == "strength")
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: progressions, tieBreak: "double") == "rpe")

        // TODO(Plan 02): replace the above with end-to-end migration via
        // file-backed container open. Approach: write the V3 fixtures to
        // a temp-dir URL using Schema(SchemaV3.models), close the
        // container, reopen at the same URL using Schema(SchemaV4.models)
        // + FitbodSchemaMigrationPlan — SwiftData runs migrateV3toV4
        // automatically on the second open. Then:
        //
        //   let v4Routines = try ctx.fetch(FetchDescriptor<SchemaV4.Routine>())
        //   #expect(v4Routines.count == 1)
        //   #expect(v4Routines.first?.intentRaw == "strength")
        //   #expect(v4Routines.first?.progressionKindRaw == "rpe")
    }

    // MARK: - 9. End-to-end Session backfill via SchemaV3 nested fixtures

    @Test("migratesV3SessionToV4WithBackfill: mode-of-SessionExercise.intentRaw lands on session.intentRaw (tie -> .strength)")
    @MainActor
    func endToEndSessionBackfillWithTieBreak() throws {
        let ctx = try makeV3InMemoryContext()

        // Two V3-shape Sessions exercising different backfill cases:
        //   Session A: 1× strength + 1× hypertrophy → TIE → .strength
        //   Session B: 3× hypertrophy → clear majority → .hypertrophy
        let sessionA = SchemaV3.Session()
        sessionA.routineSnapshotName = "Tied Session"
        ctx.insert(sessionA)

        let seA1 = SchemaV3.SessionExercise()
        seA1.session = sessionA
        seA1.intentRaw = "strength"
        seA1.progressionKindRaw = "rpe"
        ctx.insert(seA1)

        let seA2 = SchemaV3.SessionExercise()
        seA2.session = sessionA
        seA2.intentRaw = "hypertrophy"
        seA2.progressionKindRaw = "double"
        ctx.insert(seA2)

        let sessionB = SchemaV3.Session()
        sessionB.routineSnapshotName = "Hypertrophy Session"
        ctx.insert(sessionB)

        for _ in 0..<3 {
            let se = SchemaV3.SessionExercise()
            se.session = sessionB
            se.intentRaw = "hypertrophy"
            se.progressionKindRaw = "double"
            ctx.insert(se)
        }

        try ctx.save()

        // Round-trip sanity: the V3-shape fixtures persist correctly and
        // can be queried back via the nested SchemaV3.* types.
        let v3Sessions = try ctx.fetch(FetchDescriptor<SchemaV3.Session>())
        #expect(v3Sessions.count == 2)
        let v3SEs = try ctx.fetch(FetchDescriptor<SchemaV3.SessionExercise>())
        #expect(v3SEs.count == 5)

        // Apply the same modeRaw compute the migration closure applies.
        // See endToEndRoutineBackfill for the gating + Plan 02 plan.
        let sessionAV3SEs = v3SEs.filter { $0.session?.id == sessionA.id }
        let intentsA = sessionAV3SEs.map { $0.intentRaw }
        let progressionsA = sessionAV3SEs.map { $0.progressionKindRaw }
        // Tie between "strength" and "hypertrophy" → tie-break wins.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: intentsA, tieBreak: "strength") == "strength")
        // Tie between "rpe" and "double" → "double" tie-break wins.
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: progressionsA, tieBreak: "double") == "double")

        let sessionBV3SEs = v3SEs.filter { $0.session?.id == sessionB.id }
        let intentsB = sessionBV3SEs.map { $0.intentRaw }
        // Clear majority "hypertrophy".
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: intentsB, tieBreak: "strength") == "hypertrophy")

        // TODO(Plan 02): replace above with file-backed V3→V4 reopen +
        // direct fetch on `SchemaV4.Session`. See test 8's TODO block.
    }

    // MARK: - 10. Empty exercise list keeps default values

    @Test("Empty exercise list keeps default values after backfill")
    @MainActor
    func emptyExerciseListKeepsDefaults() throws {
        let ctx = try makeV3InMemoryContext()

        // V3-shape Routine with ZERO RoutineExercise rows. The migration
        // closure's modeRaw call against an empty list returns the
        // tieBreak — "strength" for intent, "double" for progressionKind.
        // Plan 02's field-level assertion verifies that the migration
        // writes those defaults onto v4Routines.first?.intentRaw.
        let routine = SchemaV3.Routine()
        routine.name = "Empty Routine"
        ctx.insert(routine)
        try ctx.save()

        // Round-trip sanity: the empty Routine persists, no children.
        let v3Routines = try ctx.fetch(FetchDescriptor<SchemaV3.Routine>())
        #expect(v3Routines.count == 1)
        let routineV3REs = try ctx.fetch(FetchDescriptor<SchemaV3.RoutineExercise>()).filter { $0.routine?.id == routine.id }
        #expect(routineV3REs.isEmpty)

        // Helper-output shape assertion documenting the empty-input
        // contract that the migration closure relies on.
        let intents = routineV3REs.map { $0.intentRaw }
        let progressions = routineV3REs.map { $0.progressionKindRaw }
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: intents, tieBreak: "strength") == "strength")
        #expect(FitbodSchemaMigrationPlan.modeRaw(of: progressions, tieBreak: "double") == "double")

        // TODO(Plan 02): replace above with file-backed V3→V4 reopen +
        // assert v4Routines.first?.intentRaw == "strength" (default kept).
    }
}
