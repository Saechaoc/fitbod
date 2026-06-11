---
phase: 07-program-graph-schema-v7-migration
plan: "07"
subsystem: persistence/schema
tags: [swiftdata, schema-migration, nullify, delete-rules, test-determinism, v5-chain]
dependency_graph:
  requires: ["07-03", "07-04", "07-05", "07-06"]
  provides: ["SPEC-7-DELETE-RULES", "SPEC-7-MIGRATION", "SPEC-7-TESTS"]
  affects: ["fitbod/Models/Block.swift", "fitbod/Models/SplitSessionSlot.swift", "fitbod/Models/Session.swift", "fitbod/Models/SessionTemplate.swift", "fitbod/Persistence/SchemaV5.swift", "fitbod/Persistence/FitbodSchemaMigrationPlan.swift", "fitbodTests/Persistence/SchemaV7MigrationTests.swift", "fitbodTests/Persistence/SchemaV6MigrationTests.swift"]
tech_stack:
  added: []
  patterns: ["SwiftData nullify inverse (to-many owns the rule)", "nested @Model CR-01 pattern extended to V5", "schema dedup by ObjectIdentifier for combined test container"]
key_files:
  created: []
  modified:
    - fitbod/Models/Block.swift
    - fitbod/Models/SplitSessionSlot.swift
    - fitbod/Models/Session.swift
    - fitbod/Models/SessionTemplate.swift
    - fitbod/Persistence/SchemaV5.swift
    - fitbod/Persistence/FitbodSchemaMigrationPlan.swift
    - fitbodTests/Persistence/SchemaV7MigrationTests.swift
    - fitbodTests/Persistence/SchemaV6MigrationTests.swift
decisions:
  - "Named the Block inverse `legacyTemplates` (not `routines`) — keeps the removed Block.routines public name permanently dead while restoring the nullify contract"
  - "SplitSessionSlot.sessions carries the nullify delete-rule (to-many side) per the single-sided inverse convention used throughout the codebase (Split.slots owns SplitSessionSlot.split, Block.sessions owns Session.block)"
  - "Combined test container uses ObjectIdentifier dedup rather than a Set to preserve order — SchemaV6 shape appears first so nested types are registered before the V7 typealiases that resolve to the same metatype"
  - "Entry-reset in stashV6Routines() (both stash vars cleared before fetch) is belt-and-suspenders with the existing end-of-materializeSessionTemplates clear — both kept; entry-reset is the idempotency contract for in-process re-entry"
  - "V5 nested Routine/RoutineExercise shape is verbatim from SchemaV6: V5→V6 was additive on OTHER entities only, confirming no field drift between the two eras"
metrics:
  duration_minutes: 90
  completed_date: "2026-06-11"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 8
---

# Phase 7 Plan 07: Gap Closure (Nullify Rules + Migration Determinism + V5 Chain) Summary

Closed three verified regressions blocking Phase 7's named deliverable ("SchemaV7MigrationTests green"): wired two missing nullify delete-rule inverses, made the migration test suite deterministic by fixing the V7-only test container that silently discarded all seeded rows, and restored the V5 schema chain by replacing renamed typealiases with proper nested @Model types.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wire nullify delete-rules for Session.slot and legacy SessionTemplate.block | a53b59c | Block.swift, SplitSessionSlot.swift, Session.swift, SessionTemplate.swift |
| 2 | Make migration suite deterministic + fix V6 count-pin | aa0a072 | SchemaV7MigrationTests.swift, SchemaV6MigrationTests.swift, FitbodSchemaMigrationPlan.swift |
| 3 | Restore V5 chain with nested Routine/RoutineExercise @Model types | b2d14a8 | SchemaV5.swift |

## What Was Built

**Task 1 — Nullify delete-rules (CR-02 carry-over)**

Added `Block.legacyTemplates: [SessionTemplate]?` with `@Relationship(deleteRule: .nullify, inverse: \SessionTemplate.block)`. This restores the nullify-on-block-delete contract that `Block.routines` provided before its removal in 07-03. The name `legacyTemplates` keeps the removed `routines` public name permanently dead. Phase 8 carry-over documented in both Block.swift and SessionTemplate.swift: both `SessionTemplate.block` and `Block.legacyTemplates` die when SessionFactory migrates off `template.block`.

Added `SplitSessionSlot.sessions: [Session]?` with `@Relationship(deleteRule: .nullify, inverse: \Session.slot)` so deleting a slot sets `Session.slot = nil` on every referencing session; session rows and their SetEntry history survive. Uses the single-sided convention: the to-many side owns the rule, the to-one side (`Session.slot`) remains a plain var.

**Task 2 — Migration test determinism**

Root cause of `refRemapping` 0-row failure (verified and documented): `makeContext()` built `Schema(SchemaV7.models)`. SchemaV7.models does NOT register `SchemaV6.Routine`. Inserting `SchemaV6.Routine()` into a V7-only container is a silent no-op — `FetchDescriptor<SchemaV6.Routine>()` returns 0. Fix: compose `SchemaV6.models + SchemaV7.models` and dedup by `ObjectIdentifier` (the two arrays share ~14 production typealiases that resolve to the same metatype; raw concat would register duplicates and SwiftData would reject the schema).

Added entry-reset (`v6RoutineStash = []; v6SessionStash = []`) at the top of `stashV6Routines()` so serialized test suite re-entry always starts from a clean stash — eliminates `templateNameBackfill` order-dependence.

Fixed `SchemaV6MigrationTests.schemaV6ModelsCountMatchesV5`: changed `== SchemaV5.models.count + 2` to `== SchemaV5.models.count`. Both are 16: the nested-substitution invariant means both schemas carry exactly 2 nested migration shapes substituting for the 2 renamed entities, so the entity COUNT is preserved across V5↔V6 even though entity NAMES differ.

**Task 3 — V5 chain restoration (CR-01 for V5)**

`typealias Routine = fitbod.SessionTemplate` resolved the entity NAME to "SessionTemplate" — not "Routine". A V5 on-disk store's entities are named "Routine"/"RoutineExercise". SwiftData cannot match → refuses to open / corrupts the walk at V5.

Fix mirrors the CR-01 pattern the reviewer applied to V1/V2 (already applied to V3/V4/V6): removed both typealiases and replaced them with nested standalone `@Model` classes `SchemaV5.Routine` and `SchemaV5.RoutineExercise` carrying the V5-era on-disk shape. V5-era shape is IDENTICAL to SchemaV6 nested shape — V5→V6 never touched Routine/RoutineExercise. `String(describing: SchemaV5.Routine.self)` now resolves to "Routine". Count stays 16 (14 production typealiases + 2 nested).

**Schema-chain audit result:** V1 (nested — safe), V2 (nested — safe), V3 (nested — safe), V4 (nested — safe), V6 (nested — safe). Only V5 had the unfixed CR-01 break; now fixed.

## Exit Gate

Six-suite exit gate run TWICE consecutively:

**Run 1:** `** TEST FAILED **` — sole failure: `BlocksSectionTests/copyAnchorsExistInRoutinesListView()` (pre-existing BRU source-introspection test; target source `RoutinesListView.swift` not in this plan's scope; classified PRE-EXISTING in VERIFICATION.md adjudication table).

**Run 2:** Identical result — same single pre-existing failure, all migration-related tests pass deterministically.

All phase-7-introduced regressions confirmed closed:
- `SchemaV7MigrationTests/slotNullifyHistoryIntact` — PASS (Session.slot nullified on slot delete)
- `SchemaV7MigrationTests/refRemapping` — PASS (2 templates seeded and fetched)
- `SchemaV7MigrationTests/templateNameBackfill` — PASS (order-independent after entry-reset)
- `SchemaV6MigrationTests/schemaV6ModelsCountMatchesV5` — PASS (16 == 16)
- `BlocksSectionTests/deletingBlockNullifiesRoutineLink` — PASS (SessionTemplate.block nullified)

## Deviations from Plan

### Pre-existing Simulator Store Issue (Rule 3 — Blocking Issue, Environment)

**Found during:** Task 1 verification
**Issue:** Simulator EEE2FCB2 had a stale on-disk SwiftData store from a previous schema version. The test host app (`fitbodApp.init()`) hits `fatalError("Failed to create ModelContainer: \(error)")` when it cannot open the mismatched store. This caused all tests on that simulator to crash with "signal trap before establishing connection."
**Fix:** Deleted the stale `default.store` from the affected simulator data container and switched all remaining test runs to simulator DFD218A6 (fresh store). This is an environment issue — confirmed pre-existing by verifying the crash reproduced with `git stash` (before any of this plan's changes).
**Scope:** Out-of-scope for code changes; environment-only fix.

## Phase 8 Carry-Over Note (CR-02)

`SessionTemplate.block` and `Block.legacyTemplates` are both load-bearing carry-over fields retained until Phase 8. `SessionFactory` still reads `template.block` to resolve the scheduled `BlockPhase`. Phase 8 must:
1. Migrate `SessionFactory` off `template.block` to the new program-graph resolver
2. Remove `SessionTemplate.block` and `Block.legacyTemplates` from the production models (SchemaV8 bump required)
Both fields are documented in their respective source files with Phase 8 carry-over notes.

## Known Stubs

None. All plan goals are fully implemented and verified.

## Threat Flags

None. This plan is internal schema/migration correctness only — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries.

## Self-Check: PASSED

All key files exist:
- FOUND: fitbod/Models/Block.swift
- FOUND: fitbod/Models/SplitSessionSlot.swift
- FOUND: fitbod/Persistence/SchemaV5.swift
- FOUND: fitbodTests/Persistence/SchemaV7MigrationTests.swift
- FOUND: 07-07-SUMMARY.md

All commits exist:
- a53b59c: fix(07-07): wire nullify delete-rules for Session.slot and legacy SessionTemplate.block
- aa0a072: fix(07-07): make migration suite deterministic + fix V6 count-pin
- b2d14a8: fix(07-07): restore pre-V7 chain at V5 with nested Routine/RoutineExercise @Model types
