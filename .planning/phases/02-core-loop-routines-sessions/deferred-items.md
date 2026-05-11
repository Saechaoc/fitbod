# Phase 2 — Deferred Items

Out-of-scope discoveries logged during plan execution per executor SCOPE BOUNDARY rule. Each entry documents a finding that should be addressed separately rather than absorbed into the current plan.

## From plan 00-02 (2026-05-11)

- **Uncommitted dirty change in `fitbodTests/FilterStatePredicateTests.swift`** — Found a pre-existing working-tree modification at executor start that was not introduced by this plan: the `@Suite` decorator gains a `.serialized` trait and the header comment is rewritten to explain why ("SwiftData-backed tests in this project otherwise run concurrently inside the app-hosted test process and can trap before individual assertions run"). Out of scope for this schema-migration plan. Likely a leftover from a previous session that diagnosed Swift Testing parallelism vs. SwiftData. Worth committing as a standalone `test(...)` change in a follow-up, possibly with the same `.serialized` trait applied to the other SwiftData-touching suites (`SchemaV1Tests`, `CascadeRuleTests`, `EnumPersistenceTests`, `UserSettingsTests`, `SeedTests`, `IndexedQueryTests`, `CustomExerciseDeleteCascadeTests`, `EmptyStateTests`, `SettingsUnitsIntegrationTests`, and the new `SchemaV2MigrationTests`) if the same parallelism trap reproduces there. Leaving the file in its dirty state in the working tree so the next executor can audit and decide.
