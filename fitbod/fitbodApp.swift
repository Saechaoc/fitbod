//
//  fitbodApp.swift
//  fitbod
//
//  App entry point. Single shared `ModelContainer` wired with the
//  versioned schema (SchemaV4 — 16 entities: same entity count as V3
//  with PIVOT-03 reshaping the per-exercise intent + progressionKind
//  fields up to per-session) and the V1 → V2 → V3 → V4 migration
//  chain registered in `FitbodSchemaMigrationPlan` (FOUND-01 /
//  PITFALLS #2 / Phase 2 plan 00-02 / Phase 3 plan 03-01 / Phase 3.1
//  plans 01 + 02). The migration plan itself keeps every historical
//  schema (`SchemaV1.self` ... `SchemaV4.self`) registered so SwiftData
//  can open a pre-V4 on-disk store and walk it forward through the
//  appropriate lightweight + custom stages.
//
//  The container is constructed synchronously in `init()` per Apple's
//  recommended `ModelContainer` pattern (RESEARCH Code Example 1):
//  failing here means the on-disk store is unusable, which is unrecoverable
//  — so a `fatalError` on failure is correct rather than silently routing
//  the app to a degraded in-memory mode.
//
//  Views consume the container via `.modelContainer(_)` environment
//  injection, then use `@Query` / `@Bindable` directly against the schema
//  (MV-VM-lite per FOUND-06).
//

import SwiftUI
import SwiftData

@main
struct fitbodApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema(SchemaV6.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: FitbodSchemaMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
    }
}
