//
//  FitbodSchemaMigrationPlan.swift
//  fitbod
//
//  The project's schema migration plan (FOUND-01 / PITFALLS #2). Phase 1
//  laid the V1 wrapper, Phase 2 added the lightweight V1→V2 stage, Phase 3
//  added the lightweight V2→V3 stage, and Phase 3.1 (PIVOT-03) adds the
//  V3→V4 CUSTOM stage that backfills `Routine.intentRaw` / `intentRaw` /
//  `progressionKindRaw` from the most-common per-exercise value across
//  each routine's / session's `RoutineExercise` / `SessionExercise` rows.
//
//  Why the V3↔V4 stage cannot be lightweight: Plan 02 REMOVES
//  `RoutineExercise.intentRaw` / `RoutineExercise.progressionKindRaw` /
//  `SessionExercise.intentRaw` / `SessionExercise.progressionKindRaw` and
//  ADDS `Routine.intentRaw` / `Routine.progressionKindRaw` /
//  `Session.intentRaw` / `Session.progressionKindRaw`. Lightweight
//  migrations can't transfer values between entities. The custom stage's
//  willMigrate closure reads V3-shape RE/SE rows via the
//  `SchemaV3.RoutineExercise` / `SchemaV3.SessionExercise` nested types
//  (see SchemaV3.swift) and writes V4-shape Routine / Session rows via
//  the `SchemaV4.Routine` / `SchemaV4.Session` typealiases.
//
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
//  [CITED: WWDC23 "Migrate to SwiftData" — namespaced @Model types per
//          VersionedSchema is Apple's documented pattern for migrations
//          that move fields between entities.]
//
//  Per CONTEXT.md Specifics: the user wiped + reseeded a fresh SchemaV3
//  database earlier today, so there are no real V3 rows that need
//  migrating for v1 ship — the production users won't have V3 stores at
//  all when v1 ships. SchemaV4MigrationTests is the canonical correctness
//  gate for the closure's semantics; the closure itself is exercised
//  literally in tests.
//
//  Per CONTEXT.md D-05: SINGLE custom stage covers all four field
//  additions + three field removals at once. No didMigrate.
//
//  Per CONTEXT.md D-06 / D-07: tie-break to `.strength` for intent and
//  `.double` for progressionKind when multiple per-exercise values tie
//  for most-common. The `modeRaw(of:tieBreak:)` helper implements the
//  rule and is shared between the willMigrate closure and unit tests.
//
//  Keeping `SchemaV1.self` / `SchemaV2.self` / `SchemaV3.self` in the
//  `schemas` array is non-negotiable — SwiftData needs every historical
//  schema registered so it can match an existing on-disk store at any
//  version and chain through the appropriate migration stages.
//

import Foundation
import SwiftData

public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6]
    }

    /// Lightweight: SwiftData handles all schema deltas automatically.
    /// Plan 00-01's deltas are all additive (new entity types + new
    /// default-valued fields) — explicitly eligible per Apple's
    /// documentation. No willMigrate / didMigrate closures needed.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    /// Lightweight: Plan 03-01's deltas are all additive (1 new entity type
    /// PlateInventory + 7 default-valued fields on existing entities) —
    /// explicitly eligible per Apple's documentation. No willMigrate /
    /// didMigrate closures needed.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    /// Lightweight: Phase 4 SchemaV5 adds `Block.reviewedAt: Date? =
    /// nil` (D-26 / D-21 — end-of-block review timestamp). The delta is
    /// a single additive Optional<Date> field on an existing @Model
    /// with a nil default — Apple's lightweight migration handles
    /// additive optional fields without a willMigrate closure.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    /// Custom: Phase 5 SchemaV6 adds 8 additive default-valued fields AND
    /// retroactively bumps `UserSettings.plateauTolerance` from 0.005 to
    /// 0.02 (D-12). The additive fields are lightweight-eligible, but the
    /// default-bump nuance forces a custom stage because lightweight
    /// migration does NOT rewrite existing rows when a `@Model` default
    /// changes (per RESEARCH §9.2). The willMigrate closure fetches the
    /// singleton UserSettings and bumps `plateauTolerance` if and only if
    /// it equals the prior default (0.005); user-edited values like 0.015
    /// fail the float-equality check and are preserved verbatim.
    ///
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
    public static let migrateV5toV6 = MigrationStage.custom(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self,
        willMigrate: { context in
            try Self.bumpPlateauToleranceDefault(in: context)
        },
        didMigrate: nil
    )

    /// Extracted bump body — same logic the willMigrate closure delegates to.
    /// `internal static` so both the migration stage AND `SchemaV6MigrationTests`
    /// can call it directly (MigrationStage closures aren't invokable from
    /// fixture tests; tests drive the semantics through this helper after
    /// SwiftData runs the open-V5 → reopen-V6 cycle).
    internal static func bumpPlateauToleranceDefault(in context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        for row in settings {
            // Compare against the OLD V5 default (0.005). User-edited values
            // (e.g., 0.015) fail this check and are preserved.
            if abs(row.plateauTolerance - 0.005) < 1e-9 {
                row.plateauTolerance = 0.02
            }
        }
        try? context.save()
    }

    /// Custom: Phase 3.1 PIVOT-03 moves intent + progressionKind from
    /// per-exercise (RoutineExercise / SessionExercise) to per-session
    /// (Routine / Session). The didMigrate closure reads V4 intermediate
    /// RE/SE rows via `SchemaV4.RoutineExercise` / `SchemaV4.SessionExercise`
    /// (which still retain the child raw fields) and computes the
    /// most-common-with-tie-break value per Routine and per Session, then
    /// writes those values onto V4-shape Routine / Session rows via the
    /// `SchemaV4.Routine` / `SchemaV4.Session` typealiases.
    ///
    /// PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
    /// tie-break. Reads via SchemaV3 nested types (V3 shape); writes via
    /// SchemaV4 typealiased types (V4 shape). The four field-writes
    /// landed in Plan 02 of Phase 3.1 alongside the model reshape.
    ///
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
    public static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self,
        willMigrate: nil,
        didMigrate: { context in
            try Self.backfillSessionLevelFields(in: context)
        }
    )

    /// Extracted backfill body — same logic the willMigrate closure
    /// delegates to. `internal static` so both the migration stage AND
    /// `SchemaV4MigrationTests` can call it (MigrationStage's willMigrate
    /// closure isn't directly invokable from a test fixture, so the test
    /// suite drives the migration semantics by calling this helper
    /// directly against an in-memory ModelContext registered with both
    /// SchemaV3 nested types and SchemaV4 typealiases).
    ///
    /// PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
    /// tie-break. Reads via SchemaV4 intermediate child rows; writes via
    /// SchemaV4 parent rows after the V3->V4 mapping has completed.
    internal static func backfillSessionLevelFields(in context: ModelContext) throws {
        // Fetch V4 intermediate child rows. They still carry the
        // deprecated intentRaw / progressionKindRaw fields so this didMigrate
        // closure can backfill the new parent-level fields.
        let v4REs = try context.fetch(FetchDescriptor<SchemaV4.RoutineExercise>())
        let v4SEs = try context.fetch(FetchDescriptor<SchemaV4.SessionExercise>())

        // Fetch V4-shape Routine + Session rows via the typealiases.
        // After Plan 02 these rows have new intent / progressionKind
        // fields with default values; the closure overwrites those
        // defaults with the backfilled mode-of-children value.
        let v4Routines = try context.fetch(FetchDescriptor<SchemaV4.Routine>())
        let v4Sessions = try context.fetch(FetchDescriptor<SchemaV4.Session>())

        for routine in v4Routines {
            let routineV4REs = v4REs.filter { $0.routine?.id == routine.id }
            let intents = routineV4REs.map { $0.intentRaw }
            let progressions = routineV4REs.map { $0.progressionKindRaw }
            // PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
            // tie-break. Reads via SchemaV3 nested types (V3 shape); writes
            // via SchemaV4 typealiased types (V4 shape).
            routine.intentRaw = Self.modeRaw(of: intents, tieBreak: "strength")
            routine.progressionKindRaw = Self.modeRaw(of: progressions, tieBreak: "double")
        }

        for session in v4Sessions {
            let sessionV4SEs = v4SEs.filter { $0.session?.id == session.id }
            let sessionIntents = sessionV4SEs.map { $0.intentRaw }
            let sessionProgressions = sessionV4SEs.map { $0.progressionKindRaw }
            // PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
            // tie-break. Reads via SchemaV3 nested types (V3 shape); writes
            // via SchemaV4 typealiased types (V4 shape).
            session.intentRaw = Self.modeRaw(of: sessionIntents, tieBreak: "strength")
            session.progressionKindRaw = Self.modeRaw(of: sessionProgressions, tieBreak: "double")
        }

        try context.save()
    }

    // MARK: - Migration helpers

    /// Deterministic mode-with-tie-break used by the V3→V4 backfill and by
    /// `SchemaV4MigrationTests`. Behavior:
    ///   - empty input → returns `tieBreak`
    ///   - single most-common value → returns it
    ///   - multiple values tied for most-common → returns `tieBreak` if it
    ///     is one of the top keys, otherwise the alphabetically-first top key
    ///
    /// `internal` (not `private`) so both the willMigrate closure above and
    /// the test suite can call it directly. Exposed as `static` so callers
    /// don't have to instantiate the enum case (which is impossible anyway).
    internal static func modeRaw(of values: [String], tieBreak: String) -> String {
        guard !values.isEmpty else { return tieBreak }
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        let maxCount = counts.values.max() ?? 0
        let topKeys = counts.filter { $0.value == maxCount }.map { $0.key }
        if topKeys.contains(tieBreak) { return tieBreak }
        return topKeys.sorted().first ?? tieBreak
    }
}
