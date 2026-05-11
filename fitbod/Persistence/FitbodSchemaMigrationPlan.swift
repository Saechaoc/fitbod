//
//  FitbodSchemaMigrationPlan.swift
//  fitbod
//
//  Empty Day-1 migration plan scaffold (FOUND-01 / PITFALLS #2).
//
//  `stages` is intentionally empty for v1 — no migrations have happened yet.
//  When `SchemaV2` is introduced (e.g., a rename / split in a future phase),
//  a `MigrationStage` is appended here and `schemas` grows to include the
//  new version. This is the cheapest insurance policy in the codebase.
//
//  Attached to `ModelContainer` in `fitbodApp.swift` via the
//  `migrationPlan: FitbodSchemaMigrationPlan.self` initializer parameter.
//

import SwiftData

public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }

    public static var stages: [MigrationStage] { [] }
}
