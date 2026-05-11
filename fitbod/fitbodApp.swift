//
//  fitbodApp.swift
//  fitbod
//
//  App entry point. Single shared `ModelContainer` wired with the
//  versioned schema (SchemaV2 — 15 entities: 12 inherited from V1 plus
//  the 3 added in Phase 2 plan 00-01) and the V1 → V2 lightweight
//  migration step registered in `FitbodSchemaMigrationPlan`
//  (FOUND-01 / PITFALLS #2 / Phase 2 plan 00-02). The migration plan
//  itself keeps both `SchemaV1.self` and `SchemaV2.self` registered so
//  SwiftData can open a pre-V2 on-disk store and walk it forward in one
//  step.
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
        let schema = Schema(SchemaV2.models)
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
