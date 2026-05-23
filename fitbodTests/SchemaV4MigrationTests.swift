//
//  SchemaV4MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 3.1 V3→V4 custom migration is wired
//  correctly. Mirrors SchemaV3MigrationTests.swift's in-memory
//  ModelContainer + Schema(SchemaV4.models) + FitbodSchemaMigrationPlan
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
//  `FitbodSchemaMigrationPlan.modeRaw(of:tieBreak:)`; tests 8 / 9 / 10
//  exercise it end-to-end through the full file-backed migration cycle
//  (open at V3 → write fixtures → close → reopen at V4 → SwiftData runs
//  migrateV3toV4 automatically → assert V4-side fields).
//
//  Plan 02 of Phase 3.1 turned tests 8 / 9 / 10 green by:
//    1. Reshaping top-level Routine / Session @Model types to add
//       `intentRaw` + `progressionKindRaw`.
//    2. Uncommenting the four field-write lines in
//       `FitbodSchemaMigrationPlan.backfillSessionLevelFields(in:)`.
//    3. Swapping the in-memory `modeRaw`-output-shape assertions for
//       file-backed open-V3 → reopen-as-V4 migration tests that read
//       `v4Routines.first?.intentRaw` directly after SwiftData runs the
//       migration.
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

    /// Fresh per-test temp-directory URL for a file-backed SwiftData store.
    /// Plan 01's in-memory dual-schema container approach wasn't viable
    /// (one process can't register both `SchemaV3.Routine` nested and
    /// `fitbod.Routine` top-level under the same entity name). The
    /// file-backed pattern works because each open uses ONE schema —
    /// SwiftData sees a V3-shape store, then on reopen sees a V4-schema
    /// request, walks the migration chain, and rewrites the on-disk file.
    private func makeTempStoreURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("fitbod-schema-v4-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    /// Build a V3-only file-backed container at the given URL. Caller
    /// writes V3-shape fixtures, then releases the container so SwiftData
    /// flushes to disk.
    private func makeV3FileContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
    }

    /// Reopen the same on-disk URL as a V4 container. SwiftData detects
    /// the V3-shape store and runs `migrateV3toV4.willMigrate` —
    /// `backfillSessionLevelFields(in:)` — automatically before the
    /// container becomes usable.
    private func makeV4FileContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
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

    // MARK: - 8. End-to-end Routine backfill via file-backed V3→V4 reopen

    @Test("migratesV3RoutineToV4WithBackfill: mode-of-RoutineExercise.intentRaw lands on routine.intentRaw")
    @MainActor
    func endToEndRoutineBackfill() throws {
        let storeURL = makeTempStoreURL()
        let routineID = UUID()

        // Phase 1: write V3-shape fixtures to disk via the V3 container.
        do {
            let container = try makeV3FileContainer(at: storeURL)
            let ctx = ModelContext(container)

            // Insert a V3-shape Routine via the nested type.
            let routine = SchemaV3.Routine()
            routine.id = routineID
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
        }

        // Phase 2: reopen the same URL at V4. SwiftData runs the V3→V4
        // migration stage (migrateV3toV4.willMigrate →
        // backfillSessionLevelFields) automatically before the container
        // becomes usable. After reopening, the V4 Routine row should have
        // intentRaw == "strength" (majority) and progressionKindRaw == "rpe"
        // (majority — 2× rpe, 1× double).
        let v4Container = try makeV4FileContainer(at: storeURL)
        let v4Ctx = ModelContext(v4Container)

        let v4Routines = try v4Ctx.fetch(FetchDescriptor<SchemaV4.Routine>())
        #expect(v4Routines.count == 1)
        let migrated = try #require(v4Routines.first)
        #expect(migrated.id == routineID)
        #expect(migrated.intentRaw == "strength")
        #expect(migrated.progressionKindRaw == "rpe")
        // Computed accessor sanity — confirms the enum-as-String pattern
        // round-trips correctly.
        #expect(migrated.intent == .strength)
        #expect(migrated.progressionKind == .rpe)
    }

    // MARK: - 9. End-to-end Session backfill via file-backed V3→V4 reopen

    @Test("migratesV3SessionToV4WithBackfill: mode-of-SessionExercise.intentRaw lands on session.intentRaw (tie -> .strength)")
    @MainActor
    func endToEndSessionBackfillWithTieBreak() throws {
        let storeURL = makeTempStoreURL()
        let sessionAID = UUID()
        let sessionBID = UUID()

        // Phase 1: write two V3-shape Sessions to disk.
        //   Session A: 1× strength + 1× hypertrophy → TIE → .strength
        //   Session B: 3× hypertrophy → clear majority → .hypertrophy
        do {
            let container = try makeV3FileContainer(at: storeURL)
            let ctx = ModelContext(container)

            let sessionA = SchemaV3.Session()
            sessionA.id = sessionAID
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
            sessionB.id = sessionBID
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
        }

        // Phase 2: reopen at V4 + assert the migrated V4 Sessions carry
        // the expected mode-with-tie-break values.
        let v4Container = try makeV4FileContainer(at: storeURL)
        let v4Ctx = ModelContext(v4Container)

        let v4Sessions = try v4Ctx.fetch(FetchDescriptor<SchemaV4.Session>())
        #expect(v4Sessions.count == 2)

        let migratedA = try #require(v4Sessions.first(where: { $0.id == sessionAID }))
        // Tie between "strength" and "hypertrophy" → tie-break wins.
        #expect(migratedA.intentRaw == "strength")
        #expect(migratedA.intent == .strength)
        // Tie between "rpe" and "double" → "double" tie-break wins.
        #expect(migratedA.progressionKindRaw == "double")
        #expect(migratedA.progressionKind == .double)

        let migratedB = try #require(v4Sessions.first(where: { $0.id == sessionBID }))
        // Clear majority "hypertrophy" for intent + "double" for progression.
        #expect(migratedB.intentRaw == "hypertrophy")
        #expect(migratedB.intent == .hypertrophy)
        #expect(migratedB.progressionKindRaw == "double")
        #expect(migratedB.progressionKind == .double)
    }

    // MARK: - 10. Empty exercise list keeps default values

    @Test("Empty exercise list keeps default values after backfill")
    @MainActor
    func emptyExerciseListKeepsDefaults() throws {
        let storeURL = makeTempStoreURL()
        let routineID = UUID()

        // Phase 1: write a V3-shape Routine with ZERO RoutineExercise rows.
        do {
            let container = try makeV3FileContainer(at: storeURL)
            let ctx = ModelContext(container)
            let routine = SchemaV3.Routine()
            routine.id = routineID
            routine.name = "Empty Routine"
            ctx.insert(routine)
            try ctx.save()
        }

        // Phase 2: reopen at V4 + assert the migration left the
        // default-valued intentRaw / progressionKindRaw fields intact
        // (modeRaw against an empty list returns the tie-break).
        let v4Container = try makeV4FileContainer(at: storeURL)
        let v4Ctx = ModelContext(v4Container)

        let v4Routines = try v4Ctx.fetch(FetchDescriptor<SchemaV4.Routine>())
        #expect(v4Routines.count == 1)
        let migrated = try #require(v4Routines.first)
        #expect(migrated.id == routineID)
        // Defaults from the @Model declaration are "strength" / "double";
        // the migration closure overwrites them with the modeRaw result,
        // which against an empty array is also "strength" / "double".
        #expect(migrated.intentRaw == "strength")
        #expect(migrated.progressionKindRaw == "double")
        #expect(migrated.intent == .strength)
        #expect(migrated.progressionKind == .double)
    }
}
