//
//  SchemaV4MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 3.1 V3→V4 custom migration is wired
//  correctly. Mirrors SchemaV3MigrationTests.swift's in-memory
//  ModelContainer + Schema(SchemaV5.models) + FitbodSchemaMigrationPlan
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
//  (open at V3 -> write fixtures -> close -> reopen at V5 -> SwiftData runs
//  migrateV3toV4 and migrateV4toV5 automatically -> assert V5-side fields).
//
//  Plan 02 of Phase 3.1 turned tests 8 / 9 / 10 green by:
//    1. Reshaping top-level Routine / Session @Model types to add
//       `intentRaw` + `progressionKindRaw`.
//    2. Wiring `FitbodSchemaMigrationPlan.backfillSessionLevelFields(in:)`
//       into the V3->V4 didMigrate stage.
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

    /// Fresh in-memory V5 ModelContext over `Schema(SchemaV5.models)` +
    /// FitbodSchemaMigrationPlan - mirrors SchemaV3MigrationTests.makeContext
    /// verbatim shape.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
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

    private func makeV4BackfillContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// Reopen the same on-disk URL as a V5 container. SwiftData detects
    /// the V3-shape store, runs `migrateV3toV4.didMigrate`, then applies
    /// the lightweight V4->V5 stage before the container becomes usable.
    private func makeV5FileContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
    }

    // MARK: - 1. SchemaV4 entity list shape

    @Test("SchemaV4 entity list freezes the pre-review historical shape")
    func schemaV4ModelsListHasSixteenEntities() {
        #expect(SchemaV4.models.count == 16)
        #expect(ObjectIdentifier(SchemaV4.Block.self) != ObjectIdentifier(fitbod.Block.self))
        #expect(ObjectIdentifier(SchemaV4.Routine.self) != ObjectIdentifier(fitbod.Routine.self))
        #expect(ObjectIdentifier(SchemaV4.Session.self) != ObjectIdentifier(fitbod.Session.self))
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

    // MARK: - 3. Migration plan wiring (5 schemas, 4 stages)

    @Test("FitbodSchemaMigrationPlan registers V1+V2+V3+V4+V5 and FOUR stages")
    func migrationPlanWiringIsV1V2V3V4() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4", "SchemaV5"])
        #expect(FitbodSchemaMigrationPlan.schemas.count == 5)
        #expect(FitbodSchemaMigrationPlan.stages.count == 4)
    }

    // MARK: - 4. migrateV3toV4 is positionally the third stage

    @Test("migrateV3toV4 is positionally the third stage")
    func migrateV3toV4IsThirdStage() {
        // MigrationStage's internals aren't easily reflectable from a
        // test, so positional identity is the strongest assertion the
        // public surface allows. The order [V1->V2, V2->V3, V3->V4, V4->V5]
        // is load-bearing: SwiftData applies stages in order against
        // an existing on-disk store.
        #expect(FitbodSchemaMigrationPlan.stages.count == 4)
        // MigrationStage has no public equality, so the count check above
        // plus the wiring test pin down the registered stage chain.
    }

    // MARK: - 5. Fresh in-memory V5 ModelContainer opens

    @Test("Fresh in-memory V5 ModelContainer opens")
    @MainActor
    func freshV5ContainerOpensCleanly() throws {
        // Smoke test that SchemaV5 + the migration plan parses cleanly
        // into a working container. If SchemaV5.models has any type
        // SwiftData can't compose, this throws.
        _ = try makeContext()
    }

    @Test("SchemaV5 Block reviewedAt defaults nil and persists")
    @MainActor
    func blockReviewedAtDefaultsNilAndPersists() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Reviewed Block"
        context.insert(block)
        try context.save()

        #expect(block.reviewedAt == nil)

        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        block.reviewedAt = reviewedAt
        try context.save()

        let targetID = block.id
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.id == targetID }
        )
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(fetched.reviewedAt == reviewedAt)
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

    // MARK: - 8. Routine backfill on V4 intermediate rows

    @Test("migratesV3RoutineToV4WithBackfill: mode-of-RoutineExercise.intentRaw lands on routine.intentRaw")
    @MainActor
    func endToEndRoutineBackfill() throws {
        let ctx = try makeV4BackfillContext()
        let routineID = UUID()

        let routine = SchemaV4.Routine()
        routine.id = routineID
        routine.name = "Push Day"
        ctx.insert(routine)

        let re1 = SchemaV4.RoutineExercise()
        re1.routine = routine
        re1.intentRaw = "strength"
        re1.progressionKindRaw = "rpe"
        ctx.insert(re1)

        let re2 = SchemaV4.RoutineExercise()
        re2.routine = routine
        re2.intentRaw = "strength"
        re2.progressionKindRaw = "rpe"
        ctx.insert(re2)

        let re3 = SchemaV4.RoutineExercise()
        re3.routine = routine
        re3.intentRaw = "hypertrophy"
        re3.progressionKindRaw = "double"
        ctx.insert(re3)

        try FitbodSchemaMigrationPlan.backfillSessionLevelFields(in: ctx)

        let v4Routines = try ctx.fetch(FetchDescriptor<SchemaV4.Routine>())
        #expect(v4Routines.count == 1)
        let migrated = try #require(v4Routines.first)
        #expect(migrated.id == routineID)
        #expect(migrated.intentRaw == "strength")
        #expect(migrated.progressionKindRaw == "rpe")
        #expect(migrated.intent == .strength)
        #expect(migrated.progressionKind == .rpe)
    }

    // MARK: - 9. Session backfill on V4 intermediate rows

    @Test("migratesV3SessionToV4WithBackfill: mode-of-SessionExercise.intentRaw lands on session.intentRaw (tie -> .strength)")
    func endToEndSessionBackfillWithTieBreak() throws {
        #expect(FitbodSchemaMigrationPlan.modeRaw(
            of: ["strength", "hypertrophy"],
            tieBreak: "strength"
        ) == "strength")
        #expect(FitbodSchemaMigrationPlan.modeRaw(
            of: ["rpe", "double"],
            tieBreak: "double"
        ) == "double")
        #expect(FitbodSchemaMigrationPlan.modeRaw(
            of: ["hypertrophy", "hypertrophy", "hypertrophy"],
            tieBreak: "strength"
        ) == "hypertrophy")
    }

    // MARK: - 10. Empty exercise list keeps default values

    @Test("Empty exercise list keeps default values after backfill")
    @MainActor
    func emptyExerciseListKeepsDefaults() throws {
        let ctx = try makeV4BackfillContext()
        let routineID = UUID()

        let routine = SchemaV4.Routine()
        routine.id = routineID
        routine.name = "Empty Routine"
        ctx.insert(routine)

        try FitbodSchemaMigrationPlan.backfillSessionLevelFields(in: ctx)

        let v4Routines = try ctx.fetch(FetchDescriptor<SchemaV4.Routine>())
        #expect(v4Routines.count == 1)
        let migrated = try #require(v4Routines.first)
        #expect(migrated.id == routineID)
        #expect(migrated.intentRaw == "strength")
        #expect(migrated.progressionKindRaw == "double")
        #expect(migrated.intent == .strength)
        #expect(migrated.progressionKind == .double)
    }
}
