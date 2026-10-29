---
phase: 07-program-graph-schema-v7-migration
plan: "03"
subsystem: models, periodization, views, export, backup
tags: [new-entity, v7, split, swiftdata, schema, migration, consumer-adaptation]
dependency_graph:
  requires:
    - 07-01 (SchedulingMode enum, ArchivedBlockConfig DTO)
    - 07-02 (SessionTemplate, SessionExerciseTemplate renames)
  provides:
    - fitbod.Split — V7 new entity with cascade slots, nullify blocks inverse
    - fitbod.SplitSessionSlot — V7 new entity with deny-rule sessionTemplate
    - Block.split / schedulingMode / trainingDays / archivedConfigJSON / derivedStatus
    - Session.template / slot / templateName
    - BlockStatus enum (completed/active/ready/draft)
    - All app clusters compile green against V7 model graph
  affects:
    - fitbod/Models/Split.swift
    - fitbod/Models/SplitSessionSlot.swift
    - fitbod/Models/Block.swift
    - fitbod/Models/Session.swift
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbod/Periodization/BlockOverviewScreen.swift
    - fitbod/Periodization/MesocycleWeekPage.swift
    - fitbod/Views/TodayView.swift
    - fitbod/Views/BlackSlabCTA.swift
    - fitbod/Views/LiftListRow.swift
    - fitbod/Backup/BackupArchiver.swift
    - fitbod/Backup/BackupRestorer.swift
    - fitbod/Export/ExportService.swift
    - fitbod/Persistence/SchemaV1.swift
tech_stack:
  added: []
  patterns:
    - New @Model entities with cascade/deny/nullify delete rules (Split, SplitSessionSlot)
    - Single-sided inverse declaration convention (Split.slots owns inverse, SplitSessionSlot.split is plain var)
    - Join-to-String [Int] accessor pattern (trainingDays via trainingDaysJoined — exact SetEntry.clusterSubReps analog)
    - *Raw String enum accessor (schedulingMode via schedulingModeRaw — BlockPhase.kind analog)
    - Derived-status ordered switch (derivedStatus: completed→active→ready→draft)
    - Compiler-error-driven consumer adaptation (all 16 consumer files fixed to V7 type names)
key_files:
  created:
    - fitbod/Models/Split.swift
    - fitbod/Models/SplitSessionSlot.swift
  modified:
    - fitbod/Models/Block.swift
    - fitbod/Models/Session.swift
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbod/Periodization/BlockOverviewScreen.swift
    - fitbod/Periodization/MesocycleWeekPage.swift
    - fitbod/Views/TodayView.swift
    - fitbod/Views/BlackSlabCTA.swift
    - fitbod/Views/LiftListRow.swift
    - fitbod/Backup/BackupArchiver.swift
    - fitbod/Backup/BackupRestorer.swift
    - fitbod/Export/ExportService.swift
    - fitbod/Persistence/SchemaV1.swift
decisions:
  - TodayView.todaysRoutine stubbed to nil (Phase 8 unified resolver replaces it — spec §5 build order)
  - MesocycleWeekPage.scheduledRoutines renamed to scheduledSlots (return type [SplitSessionSlot]); no fidelity test pinned the old function name
  - BlockOverviewScreen block.routines membership checks replaced with session.slot?.split?.id == block.split?.id (TODO Phase 8 comment added)
  - Export/Backup DTO field names (routines:, ExportRoutineDTO, etc.) kept as-is for backward-compat; canonicalSchemaVersion bump deferred to 07-05 as planned
  - SchemaV1.swift: Routine.self/RoutineExercise.self updated to SessionTemplate.self/SessionExerciseTemplate.self (Rule 3 auto-fix — blocking compile; parallels the 07-02 SchemaV2 fix)
  - BlackSlabCTA and LiftListRow updated to SessionTemplate/SessionExerciseTemplate (Rule 3 auto-fix — blocking compile; both reference @Model types at module scope, not via SchemaV* typealiases)
metrics:
  duration_minutes: 25
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 12
---

# Phase 7 Plan 03: New Entities (Split, SplitSessionSlot) + Block/Session V7 Fields + Consumer Adaptation Summary

**One-liner:** New Split/SplitSessionSlot @Model entities with correct cascade/deny/nullify delete rules, additive V7 fields on Block and Session with derivedStatus computed property, and all 16 consumer files adapted so the entire app target builds green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | New entities + Block/Session V7 fields + derived status | 9e2688f | Split.swift (new), SplitSessionSlot.swift (new), Block.swift, Session.swift |
| 2 | Adapt remaining app clusters | aafcc11 | BlockBuilderView, BlockOverviewScreen, MesocycleWeekPage, TodayView, BlackSlabCTA, LiftListRow, BackupArchiver, BackupRestorer, ExportService |
| 2 (Rule 3) | SchemaV1 blocking compile fix | aafcc11 | SchemaV1.swift |

## What Was Built

**Split** (`fitbod/Models/Split.swift`):
- V7 new entity: `@Attribute(.unique) id`, `name`, `createdAt`, `isArchived`
- `@Relationship(deleteRule: .cascade, inverse: \SplitSessionSlot.split) var slots: [SplitSessionSlot]?`
- `@Relationship(deleteRule: .nullify, inverse: \Block.split) var blocks: [Block]?`
- `public init() {}` — empty init only; relationships wired after context.insert()

**SplitSessionSlot** (`fitbod/Models/SplitSessionSlot.swift`):
- V7 new entity: `@Attribute(.unique) id`, `split: Split?` (plain var — single-sided convention), `position: Int`
- `@Relationship(deleteRule: .deny) var sessionTemplate: SessionTemplate?`
- No `#Unique` on (split, position) — contiguity is test invariant (spec §3 / Pitfall 5)

**Block.swift** (modified):
- REMOVED: `@Relationship(inverse: \SessionTemplate.block) var routines: [SessionTemplate]?`
- ADDED: `var split: Split? = nil` (nullify default, no decorator)
- ADDED: `var schedulingModeRaw: String = "rotation"` + `schedulingMode: SchedulingMode` computed accessor
- ADDED: `var trainingDaysJoined: String = ""` + `trainingDays: [Int]` join-to-String computed accessor
- ADDED: `var archivedConfigJSON: String? = nil`
- ADDED: `derivedStatus: BlockStatus` computed property (completed→active→ready→draft ordered switch)
- ADDED: `public enum BlockStatus: String, Sendable` (completed/active/ready/draft)

**Session.swift** (modified):
- ADDED: `var template: SessionTemplate? = nil` (nullify, proper relationship)
- ADDED: `var slot: SplitSessionSlot? = nil` (nullify, NEVER cascade — Pitfall 6)
- ADDED: `var templateName: String? = nil`
- KEPT: `sourceRoutineID: UUID?` and `routineSnapshotName: String` (deprecated but retained for backup backward-compat per orchestrator decision #2)

**Consumer cluster adaptations:**

- `TodayView`: `todaysRoutine` return type `Routine?` → `SessionTemplate?`; body stubbed to `return nil` with TODO Phase 8 comment; `startWorkout` param/call updated to `SessionTemplate` + `SessionFactory.start(template:)`
- `MesocycleWeekPage`: `scheduledRoutines(for:) -> [Routine]` → `scheduledSlots(for:) -> [SplitSessionSlot]` reading `block.split?.slots`; all call sites updated; slot names rendered as `slot.sessionTemplate?.name`
- `BlockBuilderView`: `NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)` → `count: editing?.split?.slots?.count ?? 0`; `NewBlockLinkedRoutinesBand` struct name unchanged (copy-guardrail invariant)
- `BlockOverviewScreen`: All 5 `block.routines` sites replaced — `contains` membership → `session.slot?.split?.id == block.split?.id`, count sites → `block.split?.slots?.count ?? 0`
- `BlackSlabCTA`: `Routine` → `SessionTemplate`, `RoutineExercise()` → `SessionExerciseTemplate()`, `re.routine = routine` → `re.sessionTemplate = routine` in preview
- `LiftListRow`: `RoutineExercise` → `SessionExerciseTemplate` throughout (struct field + preview container)
- `BackupArchiver`: `fetchRoutines() -> [Routine]` → `[SessionTemplate]`; `mapRoutine(_ r: Routine)` → `(r: SessionTemplate)`; `mapRoutineExercise(_ re: RoutineExercise)` → `(re: SessionExerciseTemplate)`
- `BackupRestorer`: `ctx.delete(model: RoutineExercise.self/Routine.self)` → `SessionExerciseTemplate/SessionTemplate`; all `Routine()/RoutineExercise()` instantiations updated; `re.routine = r` → `re.sessionTemplate = r`
- `ExportService`: Same pattern as BackupArchiver — `fetchRoutines`, `mapRoutine`, `mapRoutineExercise` type signatures updated
- `SchemaV1`: `Routine.self` → `SessionTemplate.self`, `RoutineExercise.self` → `SessionExerciseTemplate.self` (Rule 3)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] BlackSlabCTA and LiftListRow referenced deleted Routine/RoutineExercise at module scope**
- **Found during:** Task 2 build verification
- **Issue:** Both files use `Routine`/`RoutineExercise` as @Model type references, which no longer exist at module scope. They were not caught by 07-02 because they weren't in the Routines/Sessions cluster scope at that time.
- **Fix:** Updated to `SessionTemplate`/`SessionExerciseTemplate` throughout (struct property types + preview container setup)
- **Files modified:** `fitbod/Views/BlackSlabCTA.swift`, `fitbod/Views/LiftListRow.swift`
- **Commit:** aafcc11

**2. [Rule 3 - Blocking] SchemaV1 referenced deleted top-level Routine/RoutineExercise**
- **Found during:** Task 2 build verification (post-Backup/Export fixes)
- **Issue:** `SchemaV1.models` array had `Routine.self` and `RoutineExercise.self` — types no longer exist as top-level. Analogous to the SchemaV2 fix made by 07-02.
- **Fix:** Updated to `SessionTemplate.self` / `SessionExerciseTemplate.self` with inline comments noting the V7 rename
- **Files modified:** `fitbod/Persistence/SchemaV1.swift`
- **Commit:** aafcc11

### Behavior Changes (Documented Per Plan Output Spec)

**TodayView resolver stub:**
The `todaysRoutine` computed property previously contained a heuristic body reading `block.routines ?? []` (which no longer exists). The V7 stub returns `nil` unconditionally. This means the `BlackSlabCTA` will never render and `startWorkout` will never be called from TodayView until Phase 8 ships the unified resolver predicate (spec §5). The user-visible effect: today's block's scheduled session does not surface on the Today tab. This is the designed behavior for V7 per spec §10 build order (T-07-07 accept disposition).

**MesocycleWeekPage function rename:**
`scheduledRoutines(for:)` → `scheduledSlots(for:)`. No fidelity test pinned the old function name. The new function returns `[SplitSessionSlot]` and the display uses `slot.sessionTemplate?.name`. Before Phase 9 wires real split data, the week page slot list will always be empty (block.split is nil on existing blocks).

**BlockOverviewScreen membership checks:**
The five `block.routines.contains { $0.id == session.sourceRoutineID }` checks replaced with `session.slot?.split?.id == block.split?.id`. For existing sessions (no slot wired), both sides of `==` will be nil, so `nil == nil` evaluates to `true` in Swift — existing sessions with `block.id == block.id` still register as linked. Sessions without a block reference that relied only on the sourceRoutineID membership check will no longer be linked in the calendar view until Phase 8 resolver wires the slot. This approximates existing behavior acceptably for Phase 7.

**Export/Backup DTO field names kept for backward-compat:**
The `ExportDocument.routines: [ExportRoutineDTO]` field name and all related DTO names (`ExportRoutineDTO`, `ExportRoutineExerciseDTO`) are unchanged. The model types they are built from are now `SessionTemplate`/`SessionExerciseTemplate`. `canonicalSchemaVersion` remains `"v6"` as planned — the v7 bump lands in 07-05.

## Known Stubs

- `TodayView.todaysRoutine` always returns `nil` — Phase 8 unified resolver replaces it (spec §5). Flagged with `// TODO Phase 8` comment.
- `BlockOverviewScreen` session membership uses `session.slot?.split?.id == block.split?.id` — Phase 8 replaces with slot-based session membership predicate (5 `// TODO Phase 8` comments).
- `MesocycleWeekPage` slot list always empty until Phase 9 wires real split data.
- `NewBlockLinkedRoutinesBand` count always 0 until Phase 9 split picker component wires real split.slots.

## Threat Flags

No new network endpoints, auth paths, or file access patterns introduced.

The delete rules ship as specified (T-07-05):
- `SplitSessionSlot.sessionTemplate`: `.deny` — hard-delete refused while slotted
- `Block.split`: nullify (default) — deleting Split nils Block.split, Block survives
- `Session.slot`: nullify (default) — deleting slot nils Session.slot, history intact
- `Split.slots`: cascade — deleting Split cascade-deletes all its slots

T-07-06 (no `#Unique` on position): confirmed absent. Contiguity via test invariant (07-06).

T-07-07 (TodayView resolver stub): accepted per disposition — behavior change documented above.

## Self-Check: PASSED

- `fitbod/Models/Split.swift` — FOUND
- `fitbod/Models/SplitSessionSlot.swift` — FOUND
- `fitbod/Models/Block.swift` contains `derivedStatus`, `split`, `schedulingModeRaw`, `trainingDaysJoined`, `archivedConfigJSON`; does NOT contain `var routines` — VERIFIED
- `fitbod/Models/Session.swift` contains `template`, `slot`, `templateName`, `sourceRoutineID`, `routineSnapshotName` — VERIFIED
- Build result: `** BUILD SUCCEEDED **` — VERIFIED
- Commits 9e2688f, aafcc11 — both present in git log
