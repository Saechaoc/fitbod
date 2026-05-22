//
//  FitbodSchemaMigrationPlan.swift
//  fitbod
//
//  The project's first real schema migration (FOUND-01 / PITFALLS #2 /
//  Phase 2 plan 00-02). Wires V1 → V2 as a `MigrationStage.lightweight`
//  step — SwiftData handles every delta automatically because all
//  changes since V1 are additive (new entity types + new default-valued
//  fields on existing entities, landed in plan 00-01).
//
//  Per RESEARCH § Pattern 4 + Apple's documentation, additive entity
//  adds and additive default-valued field adds are explicitly eligible
//  for `MigrationStage.lightweight(fromVersion:toVersion:)`. No custom
//  willMigrate / didMigrate closures are needed.
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
//
//  Keeping `SchemaV1.self` in the `schemas` array is non-negotiable —
//  even after V2 ships, SwiftData needs the historical schema registered
//  so it can match an existing on-disk V1 store against the registered
//  version and pick the V1 → V2 migration path. Removing V1 here would
//  silently break upgrades from any device that ran a pre-V2 build.
//
//  Attached to `ModelContainer` in `fitbodApp.swift` via the
//  `migrationPlan: FitbodSchemaMigrationPlan.self` initializer parameter.
//

import SwiftData

public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
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
}
