//
//  InMemoryContainer.swift
//  fitbodTests
//
//  Shared test-target helper for in-memory `ModelContainer`s.
//
//  - `makeEmpty()` returns a freshly-built container with NO seeded
//    rows — the right choice for hermetic tests that need to count
//    inserts exactly (`SchemaV1Tests`, `CascadeRuleTests`,
//    `EnumPersistenceTests`, `UserSettingsTests`).
//
//  - `makeWithFixture()` re-exports the production
//    `PreviewModelContainer.make()` factory so tests that want the
//    deterministic 4-muscle / 2-exercise mini-fixture (e.g. future
//    Wave-3 library-view tests) can grab it without redeclaring the
//    seed logic.
//
//  Both variants use `ModelConfiguration(isStoredInMemoryOnly: true)`
//  so test runs never touch the on-disk store. SwiftTesting's `struct`
//  suites are instantiated per-test, so each `@Test` receives a fresh
//  container — no shared state, no test ordering pitfalls.
//

import Foundation
import SwiftData
@testable import fitbod

enum InMemoryContainer {
    /// Fresh empty in-memory container for hermetic tests.
    /// Throws if `ModelContainer` initialisation fails — Swift Testing
    /// surfaces the error in the test output verbatim.
    static func makeEmpty() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
    }

    /// Pre-seeded container reusing the production
    /// `PreviewModelContainer.make()` factory.
    static func makeWithFixture() -> ModelContainer {
        PreviewModelContainer.make(seedFixture: true)
    }
}
