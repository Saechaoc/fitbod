---
phase: 07-program-graph-schema-v7-migration
plan: "04"
subsystem: persistence, schema, migration
tags: [schema, v7, migration, swiftdata, entity-rename, split, session-template]
dependency_graph:
  requires:
    - 07-01 (ArchivedBlockConfig DTO + SchedulingMode enum)
    - 07-02 (SessionTemplate, SessionExerciseTemplate renames)
    - 07-03 (Split, SplitSessionSlot entities + Block/Session V7 fields)
  provides:
    - SchemaV7: VersionedSchema v7.0.0 with explicit 18-entry models array
    - SchemaV6 expanded: nested @Model Routine/RoutineExercise (V6 on-disk shapes)
    - FitbodSchemaMigrationPlan.migrateV6toV7 custom stage (7-step materialization)
    - stashV6Routines / materializeSessionTemplates internal static helpers
    - RoutineStash / RoutineExerciseStash / SessionRoutineStash Sendable plain structs
  affects:
    - fitbod/Persistence/SchemaV7.swift (created)
    - fitbod/Persistence/SchemaV6.swift (expanded)
    - fitbod/Persistence/FitbodSchemaMigrationPlan.swift (stage + helpers added)
tech_stack:
  added: []
  patterns:
    - Explicit models array on VersionedSchema (replaces passthrough — Pitfall 4 fix)
    - Nested @Model in VersionedSchema for cross-stage type access (SchemaV3 pattern)
    - Sendable plain-struct stash for willMigrate/didMigrate boundary safety
    - nonisolated(unsafe) static storage for migration-run stash (strict concurrency safe)
    - internal static helper extraction for test invocability (bumpPlateauToleranceDefault precedent)
    - insert-before-relate ordering in didMigrate materialization
    - Best-effort ArchivedBlockConfig from post-migration state (drift accepted per spec §6)
key_files:
  created:
    - fitbod/Persistence/SchemaV7.swift
  modified:
    - fitbod/Persistence/SchemaV6.swift
    - fitbod/Persistence/FitbodSchemaMigrationPlan.swift
decisions:
  - SchemaV7.models is explicit (18 entries) — NOT a passthrough to SchemaV6.models; V6 has migration-only nested types that must not appear in V7 production container
  - SchemaV6.models expanded from SchemaV5.models passthrough to explicit 16-entry array including Self.Routine.self + Self.RoutineExercise.self (Pitfall 4 fix — silent 0-row stash otherwise)
  - Nested SchemaV6.Routine carries block fitbod.Block? field (step 3 blockID capture); cross-schema inverse omitted on setOverrides relationship (SchemaV3 pattern)
  - templateName backfill (step 5) uses remapped template name — equivalent to existing routineSnapshotName log-time snapshot semantics (orchestrator decision #2; no duplicate column added)
  - stash storage is nonisolated(unsafe) static — migration closures run on unspecified executor; this avoids strict-concurrency violations for ephemeral migration scratch space
  - stash cleared after materializeSessionTemplates succeeds to free memory
metrics:
  duration_minutes: 35
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 7 Plan 04: SchemaV7 + Expanded SchemaV6 + migrateV6toV7 Custom Stage Summary

**One-liner:** SchemaV7 VersionedSchema with explicit 18-entity models array, SchemaV6 expanded with nested @Model V6-shape Routine/RoutineExercise types (Pitfall 4 passthrough fix), and the complete 7-step migrateV6toV7 custom stage with Sendable stash structs and internal-static testable helpers.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SchemaV7 + SchemaV6 nested-type expansion | f1aeee1 | SchemaV7.swift (new), SchemaV6.swift |
| 2 | migrateV6toV7 custom stage + 7-step helpers + stash structs | ee20baa | FitbodSchemaMigrationPlan.swift |

## What Was Built

### SchemaV7.swift (new file)

- `public enum SchemaV7: VersionedSchema` with `versionIdentifier = Schema.Version(7, 0, 0)`
- Typealiases for all 18 production types:
  - V7 renames/new: `SessionTemplate`, `SessionExerciseTemplate`, `Split`, `SplitSessionSlot`
  - Unchanged: `Exercise`, `MuscleGroup`, `ExerciseMuscleStimulus`, `Session`, `SessionExercise`, `SetEntry`, `Block`, `BlockPhase`, `UserSettings`, `MuscleVolumeTarget`, `RoutineFolder`, `SupersetGroup`, `RoutineExerciseSetOverride`, `PlateInventory`
- Explicit 18-entry `models` array — NOT a passthrough to SchemaV6.models (which now contains migration-only nested types)

### SchemaV6.swift expansion (existing file modified)

- Replaced `SchemaV5.models` passthrough with explicit 16-entry array (14 production types + `Self.Routine.self` + `Self.RoutineExercise.self`)
- Added `extension SchemaV6` with two nested `@Model` classes:
  - `SchemaV6.Routine`: V6 on-disk shape with `block: fitbod.Block?` (step 3 blockID capture), `exercises` relationship using nested inverse `\SchemaV6.RoutineExercise.routine`
  - `SchemaV6.RoutineExercise`: V6 on-disk shape with `routine: SchemaV6.Routine?` (nested form — critical for inverse keypath correctness), all prescription fields verbatim; `setOverrides` inverse omitted (cross-schema ref, migration never traverses it)
- `#Index` intentionally omitted on both nested types (macro can't resolve qualified names through enum namespace — SchemaV3.swift precedent)
- Removed the `Routine = fitbod.SessionTemplate` and `RoutineExercise = fitbod.SessionExerciseTemplate` typealiases (these were V7-rename forwarding aliases; V6 expansion uses its own standalone nested @Model types instead)

### FitbodSchemaMigrationPlan.swift additions

**Registration:**
- `schemas` array: `[V1, V2, V3, V4, V5, V6, V7]` — count 7
- `stages` array: `[migrateV1toV2, ..., migrateV5toV6, migrateV6toV7]` — count 6

**Stage declaration:**
- `public static let migrateV6toV7 = MigrationStage.custom(fromVersion: SchemaV6.self, toVersion: SchemaV7.self, willMigrate: { context in try Self.stashV6Routines(in: context) }, didMigrate: { context in try Self.materializeSessionTemplates(in: context) })`
- Header comment documents all 7 steps + orchestrator decision #2 (templateName reuses routineSnapshotName semantics)

**Stash types (Sendable plain structs):**
- `RoutineStash`: id, name, notes, createdAt, updatedAt, isArchived, folderID, blockID (from `block?.id`), intentRaw, progressionKindRaw, exercises: [RoutineExerciseStash]
- `RoutineExerciseStash`: all per-exercise prescription fields verbatim (id, exerciseID, orderIndex, targetSets, targetRepsLow/High, targetRPE/RIR, prescribedRestSeconds, tempo, notes, generateWarmups, supersetGroupID, tracksTempo, tracksPartialReps, warmupOverrideData)
- `SessionRoutineStash`: sessionID, routineID (from `Session.sourceRoutineID`)

**Stash storage:**
- `nonisolated(unsafe) static var v6RoutineStash: [RoutineStash]`
- `nonisolated(unsafe) static var v6SessionStash: [SessionRoutineStash]`

**`stashV6Routines(in:)` (internal static):**
- Fetches `FetchDescriptor<SchemaV6.Routine>()` (requires Pitfall 4 fix to work)
- Converts all rows to RoutineStash + RoutineExerciseStash immediately (no @Model escapes)
- Fetches `FetchDescriptor<Session>()` and converts to SessionRoutineStash pairs

**`materializeSessionTemplates(in:)` (internal static) — 7-step spec §7:**
- Step 2: Creates `SessionTemplate` per stash row (insert-before-relate); rebuilds `SessionExerciseTemplate` exercise rows with Exercise catalog lookup; remaps `Session.template` via routineID→template dictionary
- Step 3: Groups stashes by blockID; creates `Split("{block.name} split")` per block with templates; name-sorted slot order (matches old weekday heuristic); completed blocks → `split.isArchived = true`
- Step 4: Finds active block's split, gets sorted slots, locates last completed session in that block, backfills `Session.slot` for rotation continuity
- Step 5: Sets `Session.templateName` from remapped template name (falls back to `routineSnapshotName` for sessions with no template link — orchestrator decision #2)
- Step 6: Best-effort `Block.archivedConfigJSON` for completed blocks; encodes `ArchivedBlockConfig` from post-migration state using `phase.nameRaw` (BlockPhase uses `nameRaw`, not `kindRaw`)
- Step 7: No code needed — old Routine.block dies with the entity rename
- `try context.save()` at the end; stash arrays cleared after success

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] BlockPhase field name correction**
- **Found during:** Task 2 implementation of step 6 (archivedConfigJSON encoding)
- **Issue:** Plan referred to `phase.kindRaw` but `BlockPhase` persists its kind as `nameRaw: String` (computed accessor is `kind: BlockPhaseKind`). Using `kindRaw` would have caused a compile error.
- **Fix:** Used `phase.nameRaw` per actual BlockPhase model definition
- **Files modified:** `fitbod/Persistence/FitbodSchemaMigrationPlan.swift`
- **Commit:** ee20baa

**2. [Rule 2 - Missing Critical] Removed stale V7-rename typealiases from SchemaV6**
- **Found during:** Task 1 — SchemaV6 previously had `typealias Routine = fitbod.SessionTemplate` and `typealias RoutineExercise = fitbod.SessionExerciseTemplate` (forwarding aliases added by 07-02)
- **Issue:** These typealiases conflict with the new nested `@Model final class Routine` and `@Model final class RoutineExercise` declarations — Swift requires distinct names. The nested @Model types are the correct V6 on-disk shape representations.
- **Fix:** Removed the `Routine` and `RoutineExercise` typealiases from SchemaV6's typealias block; the nested @Model types stand on their own
- **Files modified:** `fitbod/Persistence/SchemaV6.swift`
- **Commit:** f1aeee1

## Schema State After Plan 04

| Version | models count | Notable contents |
|---------|-------------|-----------------|
| SchemaV6 | 16 | 14 prod types + SchemaV6.Routine + SchemaV6.RoutineExercise (migration scaffolding) |
| SchemaV7 | 18 | All 18 V7 production types (4 new/renamed + 14 unchanged) |

FitbodSchemaMigrationPlan:
- `schemas.count == 7` (V1 through V7)
- `stages.count == 6` (V1→V2, V2→V3, V3→V4, V4→V5, V5→V6, V6→V7)

## templateName / routineSnapshotName Reconciliation

Per orchestrator decision #2: `Session.templateName` (V7 new field) is backfilled from the remapped `SessionTemplate.name` at migration time. For sessions whose template ref is nil (ad-hoc sessions or sessions from deleted routines), the fallback is the existing `routineSnapshotName` field. This reuses the established log-time snapshot semantics — no duplicate snapshot column was added to the schema. The deprecated `sourceRoutineID` and `routineSnapshotName` fields are retained in V7 for backup format backward-compatibility (per orchestrator decision retained from 07-03).

## Known Stubs

None introduced in this plan. The migration helpers are complete implementations (not stubs). The test plan 07-06 will drive semantic verification.

## Threat Flags

No new network endpoints, auth paths, or file access patterns introduced.

Threat mitigations from the plan's STRIDE register:

- **T-07-08** (willMigrate data loss): All V6 Routine data stashed as Sendable plain structs before the table is dropped; no @Model escapes the closure. Stash includes blockID (step 3) and all exercise prescription fields (step 2 SessionExerciseTemplate rebuild).
- **T-07-09** (ghost rows): Split code name is `Split`, not `Routine`. SwiftData name-match cannot carry V6 Routine rows into the Split entity.
- **T-07-10** (silent empty stash): SchemaV6.models now explicitly includes `Self.Routine.self` and `Self.RoutineExercise.self` — `FetchDescriptor<SchemaV6.Routine>()` will resolve rows. Pitfall 4 fix confirmed.
- **T-07-11** (archive integrity): `archivedConfigJSON` encoded from post-migration state with `"v":1` stamp. Drift accepted per spec §6; readers never fall back to live templates.

## Self-Check: PASSED

- `fitbod/Persistence/SchemaV7.swift` — FOUND
- `fitbod/Persistence/SchemaV6.swift` contains `@Model`, `class Routine`, `class RoutineExercise`, `Self.Routine.self` — VERIFIED
- `SchemaV6.swift` does NOT contain `SchemaV5.models` (code reference) — VERIFIED
- `FitbodSchemaMigrationPlan.swift` contains `SchemaV7.self`, `migrateV6toV7`, `MigrationStage.custom`, `stashV6Routines`, `materializeSessionTemplates`, `struct RoutineStash: Sendable`, `struct SessionRoutineStash: Sendable`, `FetchDescriptor<SchemaV6.Routine>` — VERIFIED
- Build result: `** BUILD SUCCEEDED **` — VERIFIED
- Commits f1aeee1, ee20baa — both present in git log
