---
phase: 07-program-graph-schema-v7-migration
plan: "02"
subsystem: models, routines, sessions
tags: [rename, entity, swiftdata, schema, migration]
dependency_graph:
  requires:
    - 07-01 (SchedulingMode enum, ArchivedBlockConfig DTO)
  provides:
    - fitbod.SessionTemplate (was fitbod.Routine) — consumed by all Routines/Sessions/07-03 clusters
    - fitbod.SessionExerciseTemplate (was fitbod.RoutineExercise) — consumed by all prescription consumers
    - SessionFactory.start(template:) — call-site updated label
  affects:
    - fitbod/Models/SessionTemplate.swift
    - fitbod/Models/SessionExerciseTemplate.swift
    - fitbod/Models/RoutineExerciseSetOverride.swift
    - fitbod/Models/Block.swift
    - fitbod/Routines/ (7 files)
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/ExerciseLibrary/ExerciseDeletion.swift
    - fitbod/Views/LiftListSection.swift
    - fitbod/Persistence/SchemaV2.swift
    - fitbod/Persistence/SchemaV5.swift
    - fitbod/Persistence/SchemaV6.swift
tech_stack:
  added: []
  patterns:
    - Entity rename via mechanical compiler-error-driven approach (GitNexus rename not used — MCP available but mechanical fallback pre-authorized per plan; documented below)
    - Cascade relationship inverse updated: \SessionExerciseTemplate.sessionTemplate
    - KEEP-NAME allowlist honored: RoutineExerciseSetOverride struct + routineExercise field, RoutineFolder, SupersetGroup, all SwiftUI view/value-type names
    - SchemaV5/V6 typealias RHS updated (fitbod.Routine → fitbod.SessionTemplate) — alias name kept for models-array back-compat
key_files:
  created:
    - fitbod/Models/SessionTemplate.swift
    - fitbod/Models/SessionExerciseTemplate.swift
  modified:
    - fitbod/Models/RoutineExerciseSetOverride.swift
    - fitbod/Models/Block.swift
    - fitbod/Routines/RoutineDraft.swift
    - fitbod/Routines/RoutineRow.swift
    - fitbod/Routines/RoutinesListView.swift
    - fitbod/Routines/RoutineDuplicator.swift
    - fitbod/Routines/MoveRoutineSheet.swift
    - fitbod/Routines/SupersetAssignmentSheet.swift
    - fitbod/Routines/RoutineBuilderView.swift
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/ExerciseLibrary/ExerciseDeletion.swift
    - fitbod/Views/LiftListSection.swift
    - fitbod/Persistence/SchemaV2.swift
    - fitbod/Persistence/SchemaV5.swift
    - fitbod/Persistence/SchemaV6.swift
decisions:
  - Mechanical rename fallback used (GitNexus MCP pre-authorized fallback per plan; call-graph-aware rename path not taken — documented per plan output spec)
  - SessionFactory parameter label: chose template: (preferred over routine: per spec §3 — clearer call-site semantics post-rename)
  - SchemaV5/V6 typealias alias names kept as Routine/RoutineExercise (RHS updated to point at new types) to avoid breaking the models array references; 07-04 will add the nested historical @Model classes and finalize these files
  - SchemaV2 direct type references (not typealiases) updated to SessionTemplate.self/SessionExerciseTemplate.self directly
  - LiftListSection.swift and ExerciseDeletion.swift auto-fixed under Rule 3 (blocking; outside Routines/Sessions cluster scope but directly caused by our rename)
  - SchemaV2/V5/V6 typealias updates auto-fixed under Rule 3 (blocking; minimal change — only RHS of existing typealias lines)
  - Remaining errors in Backup/ cluster are plan-specified exit state — owned by 07-03
metrics:
  duration_minutes: 10
  completed_date: "2026-06-10"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 15
---

# Phase 7 Plan 02: Rename Routine→SessionTemplate, RoutineExercise→SessionExerciseTemplate Summary

**One-liner:** Mechanical rename of top-level `Routine`→`SessionTemplate` and `RoutineExercise`→`SessionExerciseTemplate` @Model entities, with full adaptation of Routines/Sessions consumer clusters and Rule 3 auto-fixes for four additionally-broken files.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rename model entities + adapt direct relatives | c7fe503 | SessionTemplate.swift (new), SessionExerciseTemplate.swift (new), RoutineExerciseSetOverride.swift, Block.swift; deleted Routine.swift, RoutineExercise.swift |
| 2 | Adapt Routines + Sessions consumer clusters | 4ef4445 | RoutineDraft.swift, RoutineRow.swift, RoutinesListView.swift, RoutineDuplicator.swift, MoveRoutineSheet.swift, SupersetAssignmentSheet.swift, RoutineBuilderView.swift, SessionFactory.swift |
| 2 (Rule 3) | Auto-fix additional blocking compile errors | 3302738 | ExerciseDeletion.swift, LiftListSection.swift, SchemaV2.swift, SchemaV5.swift, SchemaV6.swift |

## What Was Built

**SessionTemplate** (`fitbod/Models/SessionTemplate.swift`):
- V7 rename of `Routine.swift` — `@Model final class SessionTemplate` with all original fields preserved
- `@Relationship(deleteRule: .cascade, inverse: \SessionExerciseTemplate.sessionTemplate) var exercises`
- Extension: `intent: Intent`, `progressionKind: ProgressionKind` computed accessors unchanged
- File header documents V7 rename lineage and SchemaV6.Routine historical shape

**SessionExerciseTemplate** (`fitbod/Models/SessionExerciseTemplate.swift`):
- V7 rename of `RoutineExercise.swift` — `@Model final class SessionExerciseTemplate`
- Back-ref field: `var sessionTemplate: SessionTemplate? = nil` (was `routine: Routine?`)
- `@Relationship(deleteRule: .cascade, inverse: \RoutineExerciseSetOverride.routineExercise) var setOverrides` — inverse keypath unchanged (field name preserved per naming debt)
- `warmupOverride: WarmupConfig?` computed accessor preserved

**RoutineExerciseSetOverride** (modified):
- `var routineExercise: SessionExerciseTemplate?` — TYPE updated, field NAME kept (naming debt per spec §3)

**Block.swift** (modified):
- `@Relationship(inverse: \SessionTemplate.block) var routines: [SessionTemplate]?` — keypath updated to compile

**Routines cluster** (7 files adapted):
- `RoutineDraft`: `init(routine: SessionTemplate)`, `save(into: SessionTemplate)`, `RoutineExercise()` → `SessionExerciseTemplate()`, `.routine =` → `.sessionTemplate =`, `convenience init(re: SessionExerciseTemplate)`
- `RoutineRow`: model-type props and callbacks `Routine` → `SessionTemplate` (struct name `RoutineRow` unchanged)
- `RoutinesListView`: `@Query` sort key, state vars, handler params, `FetchDescriptor`, preview — all `Routine`/`RoutineExercise` model types updated
- `RoutineDuplicator`: `duplicate(routine: SessionTemplate) -> SessionTemplate`, `SessionExerciseTemplate()`, `.sessionTemplate =`
- `MoveRoutineSheet`: prop + init param → `SessionTemplate`
- `SupersetAssignmentSheet`: prop + init param → `SessionTemplate`
- `RoutineBuilderView`: `editing: SessionTemplate?`, `save()` local var → `SessionTemplate`

**SessionFactory** (modified):
- `start(template: SessionTemplate, ...)` — parameter label changed from `routine:` to `template:` (preferred per spec §3)
- All `routine.*` field accesses → `template.*`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Mechanical rename fallback used (pre-authorized)**
- **Found during:** Task 1
- **Issue:** GitNexus MCP `gitnexus_rename` is available but the plan pre-authorizes the mechanical compiler-error-driven rename as the fallback
- **Fix:** Performed precise word-boundary mechanical rename. No over-broad substring replacements; KEEP-NAME allowlist respected throughout
- **Files modified:** All files listed above
- **Commit:** c7fe503, 4ef4445

**2. [Rule 3 - Blocking] ExerciseDeletion.swift referenced deleted RoutineExercise type**
- **Found during:** Post-Task 2 build verification
- **Issue:** `FetchDescriptor<RoutineExercise>()` — `RoutineExercise` no longer exists; compile error
- **Fix:** Updated to `FetchDescriptor<SessionExerciseTemplate>()`
- **Files modified:** `fitbod/ExerciseLibrary/ExerciseDeletion.swift`
- **Commit:** 3302738

**3. [Rule 3 - Blocking] LiftListSection.swift referenced deleted Routine/RoutineExercise types**
- **Found during:** Post-Task 2 build verification
- **Issue:** `let routine: Routine?`, `[RoutineExercise]` — both types no longer exist
- **Fix:** Updated to `SessionTemplate?`, `[SessionExerciseTemplate]`, preview `ModelContainer` types updated, `RoutineExercise()` → `SessionExerciseTemplate()`, `re.routine` → `re.sessionTemplate`
- **Files modified:** `fitbod/Views/LiftListSection.swift`
- **Commit:** 3302738

**4. [Rule 3 - Blocking] SchemaV2/V5/V6 referenced deleted top-level Routine/RoutineExercise**
- **Found during:** Post-Task 2 build verification
- **Issue:** SchemaV2 models array and SchemaV5/V6 typealias RHS pointed at `fitbod.Routine`/`fitbod.RoutineExercise` — types no longer exist as top-level
- **Fix:** SchemaV2 models array entries → `SessionTemplate.self`/`SessionExerciseTemplate.self`; SchemaV5/V6 typealias RHS → `fitbod.SessionTemplate`/`fitbod.SessionExerciseTemplate` (alias names Routine/RoutineExercise kept for models-array back-compat; 07-04 will finalize these files with nested historical @Model classes)
- **Files modified:** `fitbod/Persistence/SchemaV2.swift`, `fitbod/Persistence/SchemaV5.swift`, `fitbod/Persistence/SchemaV6.swift`
- **Commit:** 3302738

### Plan Exit State Verified

Remaining build errors (Backup cluster only) match the plan-specified exit state:
- `fitbod/Backup/BackupArchiver.swift` — 9 errors (Routine/RoutineExercise references, owned by 07-03)
- `fitbod/Backup/BackupRestorer.swift` — 7 errors (Routine/RoutineExercise references, owned by 07-03)
- No errors in: Models, Routines, Sessions, ExerciseLibrary, Views, Persistence, Design clusters

## GitNexus Rename Approach

**Fallback used — mechanical compiler-error-driven rename.** The GitNexus MCP tools are available but the plan pre-authorized the mechanical fallback and requires the choice to be noted here. All renames were performed with word-boundary awareness (`\b` patterns); the KEEP-NAME allowlist (RoutineFolder, RoutineExerciseSetOverride, SupersetGroup, SchemaV1-V6 nested types, SwiftUI view names) was respected throughout.

## Known Stubs

None — this plan is a pure structural rename with no UI data paths or placeholder values introduced.

## Threat Flags

No new network endpoints, auth paths, or file access patterns introduced. The entity rename does not touch the SwiftData store schema (on-disk V6 shape preserved in SchemaV6 nested types added by 07-04).

## Self-Check: PASSED

- `fitbod/Models/SessionTemplate.swift` — FOUND
- `fitbod/Models/SessionExerciseTemplate.swift` — FOUND
- `fitbod/Models/Routine.swift` — correctly ABSENT (deleted)
- `fitbod/Models/RoutineExercise.swift` — correctly ABSENT (deleted)
- `RoutineExerciseSetOverride.routineExercise` field type `SessionExerciseTemplate?` — VERIFIED
- `RoutineExerciseSetOverride` struct name unchanged — VERIFIED
- No SchemaV*.swift nested @Model classes modified (SchemaV3.swift, SchemaV4.swift untouched)
- Commits c7fe503, 4ef4445, 3302738 — all present in git log
