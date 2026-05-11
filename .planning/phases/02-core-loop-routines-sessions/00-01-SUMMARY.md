---
phase: 02
plan: 00-01
subsystem: schema
tags: ["schema", "swiftdata", "entities", "wave-0"]
requires: []
provides:
  - "RoutineFolder entity (single-level routine grouping)"
  - "SupersetGroup entity (paired/giant set grouping)"
  - "RoutineExerciseSetOverride entity (per-set prescription override)"
  - "Routine.folderID soft ref"
  - "RoutineExercise.supersetGroupID / tracksTempo / tracksPartialReps / setOverrides cascade"
  - "SessionExercise.pinnedNote"
  - "SetEntry.partialReps / clusterSubRepsJoined / clusterSubReps computed / isComplete"
affects:
  - "Plan 00-02 (SchemaV2 + MigrationStage.lightweight wiring)"
  - "Plan 01-01 (SessionFactory uses isComplete sentinel + setOverrides cascade)"
  - "Plan 03-01 (folder-delete query-and-null pass, superset-delete query-and-null pass)"
  - "Plan 03-02 (RoutineDraft mirrors / setOverride pruning on targetSets decrease)"
  - "Plan 04-01/04-02 (session logger writes pinnedNote, toggles isComplete, renders partials / cluster sub-reps)"
tech-stack:
  added: []
  patterns:
    - "FOUND-02 — every new field default-valued (iCloud-shape insurance / lightweight migration safe)"
    - "FOUND-03 — SupersetKind persisted as kindRaw: String + computed accessor"
    - "CONTEXT.md Area 1 / Area 6 — soft UUID refs (no SwiftData relationship) for superset and folder bindings to keep deletes from cascading unexpectedly"
    - "Cascade-relationship-inverse pattern (mirrors Session→SessionExercise) for RoutineExercise→RoutineExerciseSetOverride"
    - "Lazy joined-string + computed-array accessor for SetEntry.clusterSubReps (mirrors Phase 1's primaryMuscleSlugsJoined pattern)"
key-files:
  created:
    - "fitbod/Models/RoutineFolder.swift"
    - "fitbod/Models/SupersetGroup.swift"
    - "fitbod/Models/RoutineExerciseSetOverride.swift"
  modified:
    - "fitbod/Models/Routine.swift (+ folderID: UUID?)"
    - "fitbod/Models/RoutineExercise.swift (+ supersetGroupID / tracksTempo / tracksPartialReps / setOverrides cascade)"
    - "fitbod/Models/SessionExercise.swift (+ pinnedNote: String?)"
    - "fitbod/Models/SetEntry.swift (+ partialReps / clusterSubRepsJoined / isComplete + clusterSubReps computed)"
decisions:
  - "Soft UUID refs (not SwiftData @Relationship) for Routine↔Folder and RoutineExercise↔SupersetGroup — deleting a folder or superset MUST move children back to Unfiled / standalone, never cascade-delete them."
  - "Cascade @Relationship for RoutineExercise → RoutineExerciseSetOverride (overrides are owned rows that have no meaning without their parent)."
  - "Explicit SetEntry.isComplete: Bool = false sentinel over the `completedAt == .distantPast` overload (RESEARCH Open Question #3)."
  - "Every new field default-valued so lightweight migration from SchemaV1 stores succeeds without a custom MigrationStage (FOUND-02)."
metrics:
  completed: 2026-05-11
  duration: "~12 minutes"
  tasks: 1
  files_changed: 7
  commits: 2
---

# Phase 2 Plan 00-01: Schema V2 New Entities and Additive Fields Summary

Landed every Phase 2 schema delta as one atomic plan: three new SwiftData entities (`RoutineFolder`, `SupersetGroup`, `RoutineExerciseSetOverride`) plus eight additive default-valued fields on four existing entities (`Routine`, `RoutineExercise`, `SessionExercise`, `SetEntry`). SchemaV1 and `FitbodSchemaMigrationPlan` are intentionally untouched — wiring the new entities into `SchemaV2` is plan 00-02's job. All changes parse-clean (`xcrun swiftc -parse` exits 0), and every new field has a default value so lightweight migration from existing SchemaV1 stores is unblocked.

## What Was Built

### New `@Model` entities (`fitbod/Models/`)

1. **`RoutineFolder`** — `id` / `name` / `sortOrder` / `createdAt`. Single-level folder per CONTEXT.md Area 6. Designated init + convenience init.
2. **`SupersetGroup`** — `id` / `routineID` (soft ref) / `kindRaw` / `sortOrder` / `createdAt`. Co-located `SupersetKind` enum (`paired` / `giant`) + `kind` computed accessor in the same file (FOUND-03 pattern).
3. **`RoutineExerciseSetOverride`** — `id` / `routineExercise: RoutineExercise?` (inverse anchor) / `setIndex` / `targetRepsLow` / `targetRepsHigh` / `targetRPE`. Cascade-owned by `RoutineExercise.setOverrides`.

### Additive fields on existing entities

| Entity            | Field                          | Type                                     | Default | Requirement |
| ----------------- | ------------------------------ | ---------------------------------------- | ------- | ----------- |
| `Routine`         | `folderID`                     | `UUID?`                                  | `nil`   | ROUTINE-06  |
| `RoutineExercise` | `supersetGroupID`              | `UUID?`                                  | `nil`   | ROUTINE-04  |
| `RoutineExercise` | `tracksTempo`                  | `Bool`                                   | `false` | SESS-07     |
| `RoutineExercise` | `tracksPartialReps`            | `Bool`                                   | `false` | SESS-08     |
| `RoutineExercise` | `setOverrides` (`@Relationship`) | `[RoutineExerciseSetOverride]?`        | `[]`    | ROUTINE-03  |
| `SessionExercise` | `pinnedNote`                   | `String?`                                | `nil`   | SESS-11     |
| `SetEntry`        | `partialReps`                  | `Int?`                                   | `nil`   | SESS-08     |
| `SetEntry`        | `clusterSubRepsJoined`         | `String?`                                | `nil`   | SESS-08     |
| `SetEntry`        | `isComplete`                   | `Bool`                                   | `false` | (sentinel)  |

Plus the `clusterSubReps: [Int]` computed accessor on `SetEntry` (split-on-`,` getter, comma-join setter — mirrors the `primaryMuscleSlugsJoined` pattern from Phase 1).

## Files Changed

### Created
- `fitbod/Models/RoutineFolder.swift` — 33 lines
- `fitbod/Models/SupersetGroup.swift` — 57 lines (entity + enum + computed accessor)
- `fitbod/Models/RoutineExerciseSetOverride.swift` — 50 lines

### Modified
- `fitbod/Models/Routine.swift` — `+ public var folderID: UUID? = nil` (line 33)
- `fitbod/Models/RoutineExercise.swift` — `+ supersetGroupID / tracksTempo / tracksPartialReps` + `setOverrides` cascade `@Relationship`
- `fitbod/Models/SessionExercise.swift` — `+ pinnedNote: String? = nil` (line 51)
- `fitbod/Models/SetEntry.swift` — `+ partialReps / clusterSubRepsJoined / isComplete` + `clusterSubReps: [Int]` computed accessor in extension

### Intentionally NOT touched
- `fitbod/Persistence/SchemaV1.swift` — frozen baseline (PITFALLS #2). New entities are added to `SchemaV2` in plan 00-02, not here.
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — plan 00-02's responsibility.
- `fitbod/fitbodApp.swift` — `Schema(SchemaV1.models)` switch is plan 00-02's responsibility.

## Decisions Made

1. **Soft `UUID?` refs (not SwiftData `@Relationship`) for `Routine.folderID` and `RoutineExercise.supersetGroupID`.** Per CONTEXT.md Area 1 / Area 6, deleting a folder must move routines to Unfiled and deleting a superset must leave the constituent exercises as standalone rows — both behaviors are the opposite of a SwiftData cascade. The query-and-null passes live in the delete handlers in plans 03-01 / 03-02.

2. **Cascade `@Relationship` for `RoutineExercise.setOverrides` with inverse `\RoutineExerciseSetOverride.routineExercise`.** Overrides are owned — they have no meaning without their parent `RoutineExercise`, so cascading the delete is correct. Mirrors the `Session → SessionExercise` inverse pattern from Phase 1.

3. **`SetEntry.isComplete: Bool = false` as explicit "planned-but-not-logged" sentinel** rather than the `completedAt == .distantPast` overload (RESEARCH Open Question #3). Cleaner semantics for the per-set completion checkmark contract that lands in plans 01-01 (factory pre-populates) and 04-01 (logger flips on commit).

4. **Every new field default-valued.** `UUID?` → `nil`, `Bool` → `false`, `Int?` → `nil`, `String?` → `nil`, `[T]?` (`@Relationship`) → `[]`. FOUND-02 guarantees lightweight migration from any SchemaV1 store (including future iCloud-replicated stores) works without a custom `MigrationStage`.

5. **`SupersetKind` enum + `kind` accessor co-located in `SupersetGroup.swift`.** Single file ships entity + raw-string field + matching enum + computed accessor — mirrors FOUND-03 / Phase 1's `Intent` / `ProgressionKind` pattern but keeps the kind enum next to its sole consumer because no other entity uses `SupersetKind`.

## Tests

Per the plan's acceptance criterion #10, no tests in this plan. Schema-migration smoke tests are owned by plan 00-02 (`SchemaV2MigrationTests`); entity-shape tests are owned by the wave that consumes each entity (`RoutineFolderTests` in 03-01, `SupersetGroupTests` / `RoutineExerciseSetOverrideTests` / `RoutineDuplicationTests` in 03-02, etc.). RESEARCH § Validation Architecture explicitly defers entity-shape testing to the consuming wave.

## Verification

All 10 plan acceptance criteria verified:

| AC  | Check                                                                   | Result |
| --- | ----------------------------------------------------------------------- | ------ |
| 1   | RoutineFolder.swift — `@Model` + `@Attribute(.unique)` + name/sortOrder/createdAt | PASS   |
| 2   | SupersetGroup.swift — kindRaw + SupersetKind enum + kind accessor       | PASS   |
| 3   | RoutineExerciseSetOverride.swift — routineExercise/setIndex/targetRepsLow/High/RPE | PASS |
| 4   | Routine.folderID present (1 match)                                      | PASS   |
| 5   | RoutineExercise — supersetGroupID + tracksTempo + tracksPartialReps + setOverrides (≥4 matches) | PASS |
| 6   | SessionExercise.pinnedNote present (1 match)                            | PASS   |
| 7   | SetEntry — partialReps + clusterSubRepsJoined + isComplete + clusterSubReps (4 matches) | PASS |
| 8   | Every new field default-valued (no breaking changes)                    | PASS   |
| 9   | `find fitbod -name '*.swift' \| xargs xcrun swiftc -parse` exits 0      | PASS   |
| 10  | No test files created                                                   | PASS   |

Additional invariants verified:
- `git diff --stat fitbod/Persistence/SchemaV1.swift fitbod/Persistence/FitbodSchemaMigrationPlan.swift` returns empty (frozen baseline preserved).
- `git status --short` reports clean (modulo Xcode-local xcuserdata, never tracked).

## Commits

- `ee93f94` — `feat(02-00-01): add SchemaV2 entities RoutineFolder, SupersetGroup, RoutineExerciseSetOverride` (3 new files, 141 insertions)
- `028f139` — `feat(02-00-01): add additive SchemaV2 fields to Routine, RoutineExercise, SessionExercise, SetEntry` (4 modified files, 21 insertions)

## Deviations from Plan

None. The plan was executed exactly as written — three new entity files matching the prescribed field sets verbatim, four additive field edits to existing files at the prescribed insertion points, and zero changes to SchemaV1 / FitbodSchemaMigrationPlan / fitbodApp. The `xcrun swiftc -parse` gate passed on the first attempt with no Rule 1-3 auto-fixes required.

## Known Stubs

None. Every new field has a defined semantic; the consumer code that toggles / writes these fields lives in downstream plans (01-01, 03-01, 03-02, 04-01, 04-02) per the plan's "Soft dependencies" section. No placeholder / "TODO" / "not available" markers introduced.

## Authentication Gates

None occurred. This is a pure-schema plan with no network, auth, or external-tool interactions.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or trust-boundary schema changes introduced. The new entities are SwiftData-local types that participate in the existing SchemaV2 store under the same on-device / iCloud cohort as the Phase 1 entities.

## Next

Plan **00-02** wires the new entities into `SchemaV2`, switches `fitbodApp.swift`'s `Schema(SchemaV1.models)` over to `Schema(SchemaV2.models)`, and adds a `MigrationStage.lightweight(from: SchemaV1.self, to: SchemaV2.self)` step to `FitbodSchemaMigrationPlan`. The entity shape locked in this plan keeps that next step a literal one-liner per entity.

## Self-Check

**Files created — verified present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/RoutineFolder.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/SupersetGroup.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/RoutineExerciseSetOverride.swift` — FOUND

**Commits — verified present in git log:**
- `ee93f94` — FOUND
- `028f139` — FOUND

**Parse gate — verified:**
- `find fitbod -name '*.swift' -type f | xargs xcrun swiftc -parse` exited 0 (no output)

**SchemaV1 / FitbodSchemaMigrationPlan — verified untouched:**
- `git diff --stat fitbod/Persistence/SchemaV1.swift fitbod/Persistence/FitbodSchemaMigrationPlan.swift` returned empty

## Self-Check: PASSED
