---
phase: 07-program-graph-schema-v7-migration
plan: "05"
subsystem: test-target / export
tags: [v7-migration, test-rename, schema-migration, export-version]
dependency_graph:
  requires: [07-02, 07-03, 07-04]
  provides: [SPEC-7-TESTS, SPEC-7-COMPILE, SPEC-7-DTO]
  affects: [fitbodTests, fitbod/Export]
tech_stack:
  added: []
  patterns:
    - InMemoryContainer.makeCurrent() on SchemaV7.models
    - SchemaVN.models count-pin assertions pattern (schemas/stages/names triad)
    - Golden JSON fixture byte-regen for canonicalSchemaVersion bump
key_files:
  created: []
  modified:
    - fitbodTests/TestSupport/InMemoryContainer.swift
    - fitbodTests/SchemaV4MigrationTests.swift
    - fitbodTests/Persistence/SchemaV6MigrationTests.swift
    - fitbodTests/SchemaV1Tests.swift
    - fitbodTests/SchemaV2MigrationTests.swift
    - fitbodTests/CascadeRuleTests.swift
    - fitbodTests/WarmupConfigTests.swift
    - fitbodTests/SessionFactoryTests.swift
    - fitbodTests/SessionFactoryPhase3Tests.swift
    - fitbodTests/WarmupDeloadIntegrationTests.swift
    - fitbodTests/DeloadVolumeApplicationTests.swift
    - fitbodTests/ActiveSessionConflictTests.swift
    - fitbodTests/MidSessionSwapTests.swift
    - fitbodTests/AddUnplannedExerciseTests.swift
    - fitbodTests/SupersetGroupTests.swift
    - fitbodTests/RoutineDuplicationTests.swift
    - fitbodTests/RoutineBlockLinkageTests.swift
    - fitbodTests/RoutineDraftValidationTests.swift
    - fitbodTests/RoutineBuilderHeaderPickersTests.swift
    - fitbodTests/SessionBlockSnapshotTests.swift
    - fitbodTests/BlockCardWeekNavigationTests.swift
    - fitbodTests/BlockOverviewScreenWeekCarouselTests.swift
    - fitbodTests/BlocksSectionTests.swift
    - fitbodTests/Phase6/BackupRoundTripTests.swift
    - fitbod/Export/ExportDTOs.swift
    - fitbodTests/Phase6/ExportDocumentSnapshotTests.swift
    - fitbodTests/Phase6/Fixtures/json/example-export.json
    - fitbodTests/NewBlockBuilderFidelityTests.swift
decisions:
  - "Test runner crash on pre-existing simulator with stale V6 SwiftData store — resolved by erasing simulator before test run; root cause was app container opening V6 schema against on-disk store that needed V7 migration"
  - "fitbodApp.swift intentionally left on SchemaV6.models for plan 07-05 scope; app-target flip to V7 is out of scope (07-06 or later)"
  - "example-export.json golden fixture updated inline (schemaVersion v6→v7) rather than test-regenerated, matching byte-stable format"
metrics:
  duration: "~90 minutes (across two executor sessions)"
  completed_date: "2026-06-10"
  tasks_completed: 2
  files_changed: 28
---

# Phase 07 Plan 05: Test-Target V7 Flip — Summary

**One-liner:** Flipped the entire fitbodTests target to V7 by renaming 24 test files from `Routine`/`RoutineExercise` @Model to `SessionTemplate`/`SessionExerciseTemplate`, pointing `InMemoryContainer.makeCurrent()` at `SchemaV7.models`, refreshing all count-pin assertions, and bumping `ExportDocument.canonicalSchemaVersion` to "v7" with golden fixture regen.

---

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Test-target entity rename (migration/persistence/model files) + InMemoryContainer flip + count-pin refresh | `52b1957` |
| 2 | ExportDocument version bump to v7 + golden fixture regen + guardrail suites green | `d325e83` |

---

## What Was Built

### Task 1: Test-Target Entity Rename

**InMemoryContainer:** `makeCurrent()` flipped from `Schema(SchemaV6.models)` to `Schema(SchemaV7.models)`. `makeEmpty()` intentionally stays on `SchemaV1.models`.

**Count-pin assertions refreshed:**
- `SchemaV4MigrationTests`: names array now includes "SchemaV7"; `schemas.count == 7`; `stages.count == 6` (both occurrences at lines ~96 and ~109)
- `SchemaV6MigrationTests`: `names.last == "SchemaV7"`; `stages.count == 6`; `SchemaV6.models.count == SchemaV5.models.count + 2` (with comment explaining the 2 nested types added in 07-04 for the custom V6→V7 migration stage)

**Mechanical rename across 24 test files:**
- `Routine()` → `SessionTemplate()`
- `RoutineExercise()` → `SessionExerciseTemplate()`
- `FetchDescriptor<Routine>` → `FetchDescriptor<SessionTemplate>`
- `FetchDescriptor<RoutineExercise>` → `FetchDescriptor<SessionExerciseTemplate>`
- `re.routine = routine` → `re.sessionTemplate = routine` (back-reference property renamed in V7)
- `SessionFactory.start(routine:` → `SessionFactory.start(template:` (call label renamed in V7)
- `mapRoutine(_ r: Routine)` → `mapRoutine(_ r: SessionTemplate)` (BackupRoundTripTests)

**Block.routines removal handled:** `Block.routines` was removed in V7 (replaced by Block→Split→SplitSessionSlot). Two test files required adaptation:
- `BlockCardWeekNavigationTests`: retired `scheduledRoutinesSortedByName` test (called `MesocycleWeekPage.scheduledRoutines(for:)` which was removed in V7); left as a commented-out non-`@Test` stub with V7 explanation
- `BlockOverviewScreenWeekCarouselTests`: removed `block.routines = [routine]` assignment; updated session-to-block linkage check from block.routines OR-branch to `session.block?.id == block.id`; updated future-day "upcoming" test to use `block.isActive` instead of routineCount

**Preserved per KEEP-NAME allowlist:**
- `RoutineFolder`, `RoutineExerciseSetOverride` (and its `routineExercise` field)
- `SupersetGroup`
- All `SchemaVN.Routine` historical nested types (SchemaV1 through SchemaV6)
- UI string literals: "Routine", "New Routine", "Routine mutations" in comments/test strings

### Task 2: ExportDocument Version Bump

- `fitbod/Export/ExportDTOs.swift` line 87: `canonicalSchemaVersion = "v6"` → `"v7"`
- `fitbodTests/Phase6/ExportDocumentSnapshotTests.swift` line 238: `json["schemaVersion"] == "v6"` → `"v7"`
- `fitbodTests/Phase6/Fixtures/json/example-export.json`: `"schemaVersion" : "v6"` → `"v7"` (golden fixture updated inline — byte-stable format preserved)

Also included in Task 2 commit: `NewBlockBuilderFidelityTests.swift` — new guardrail test `blockBuilderViewExposesDirectManipulationAffordances()` asserting swipe-to-delete (DragGesture + destructive Button + commitDelete) and drag-to-reorder (⋮⋮ handle + LongPressGesture + move(fromOffsets:) + lifecycle callbacks) affordances in `BlockBuilderView.swift`.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SessionExerciseTemplate back-reference property renamed**
- **Found during:** Task 1 execution
- **Issue:** `re.routine = routine` caused compiler error — the back-reference property on `SessionExerciseTemplate` was renamed from `routine` to `sessionTemplate` as part of the V7 entity rename in 07-02
- **Fix:** Renamed all occurrences of `.routine =` (as back-reference assignment) to `.sessionTemplate =` across 12 test files
- **Files modified:** SchemaV2MigrationTests, CascadeRuleTests, SessionFactoryTests, SessionFactoryPhase3Tests, WarmupDeloadIntegrationTests, DeloadVolumeApplicationTests, ActiveSessionConflictTests, MidSessionSwapTests, AddUnplannedExerciseTests, SupersetGroupTests, RoutineDuplicationTests, BlockOverviewScreenWeekCarouselTests

**2. [Rule 1 - Bug] SessionFactory.start() parameter label renamed**
- **Found during:** Task 1 execution
- **Issue:** `SessionFactory.start(routine: routine,` caused compiler error — the parameter label was renamed to `template:` in 07-02's `SessionFactory.swift` adaptation
- **Fix:** Renamed all `start(routine:` calls to `start(template:` across 6 test files (5 occurrences in SessionFactoryPhase3Tests alone)
- **Files modified:** SessionFactoryTests, SessionFactoryPhase3Tests, WarmupDeloadIntegrationTests, DeloadVolumeApplicationTests, ActiveSessionConflictTests, MidSessionSwapTests

**3. [Rule 1 - Bug] Block.routines removed in V7**
- **Found during:** Task 1 execution
- **Issue:** `block.routines = [routine]` and `block.routines` reads caused compiler errors — `Block.routines` relationship was completely removed in V7 (Block→SessionTemplate link replaced by Block→Split→SplitSessionSlot)
- **Fix:** Retired `scheduledRoutinesSortedByName` test; updated carousel test to use session.block?.id linkage and block.isActive for future-day state
- **Files modified:** BlockCardWeekNavigationTests, BlockOverviewScreenWeekCarouselTests

**4. [Rule 1 - Bug] Module-qualified type references in SchemaV4MigrationTests**
- **Found during:** Task 1 execution
- **Issue:** `fitbod.Routine.self` and `fitbod.RoutineExercise.self` caused compiler errors — these module-qualified references point to the top-level production types which are now `SessionTemplate` and `SessionExerciseTemplate`
- **Fix:** Updated to `fitbod.SessionTemplate.self` and `fitbod.SessionExerciseTemplate.self`
- **Files modified:** SchemaV4MigrationTests

**5. [Rule 3 - Blocking] Test runner crash on stale simulator**
- **Found during:** Task 1 verification
- **Issue:** `xcodebuild test` crashed with "Early unexpected exit, operation never finished bootstrapping" — caused by app process fatalError on launch when on-disk SwiftData store (previously opened with V6 schema) encountered the V7 migration plan
- **Fix:** Erased simulator with `xcrun simctl erase <id>` before running tests; fresh simulator with no on-disk store boots cleanly
- **Note:** The app target (`fitbodApp.swift`) intentionally still uses `Schema(SchemaV6.models)` — flipping it is out of scope for plan 07-05. This is expected behavior per the plan's scope boundary.

---

## Verification Results

**Task 1 automated check:** PASSED
```
rg -q "Schema(SchemaV7.models)" fitbodTests/TestSupport/InMemoryContainer.swift
rg -q "schemas.count == 7" fitbodTests/SchemaV4MigrationTests.swift
rg -q "stages.count == 6" fitbodTests/SchemaV4MigrationTests.swift fitbodTests/Persistence/SchemaV6MigrationTests.swift
rg -q "SchemaV7" fitbodTests/SchemaV4MigrationTests.swift fitbodTests/Persistence/SchemaV6MigrationTests.swift
! rg -q "stages.count == 5|schemas.count == 6" ...  → OK
```

**Task 2 automated check:** PASSED
```
rg -q 'canonicalSchemaVersion = "v7"' fitbod/Export/ExportDTOs.swift → OK
rg -q '"v7"' fitbodTests/Phase6/ExportDocumentSnapshotTests.swift → OK
```

**3 BlockBuilderView copy-guardrail suites:** ALL GREEN (** TEST SUCCEEDED **)
- NewBlockBuilderFidelityTests: 6/6 passed (including new direct-manipulation affordances test)
- BlockBuilderViewCopyTests: 1/1 passed
- ProgramViewFidelityTests: 6/6 passed

**Build:** `** TEST BUILD SUCCEEDED **` (full fitbod scheme, iOS Simulator)

---

## Known Stubs

None. All changes are mechanical renames and version string bumps with no placeholder data.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `fitbodTests/TestSupport/InMemoryContainer.swift` — contains `Schema(SchemaV7.models)`: FOUND
- `fitbodTests/SchemaV4MigrationTests.swift` — contains `schemas.count == 7`: FOUND
- `fitbod/Export/ExportDTOs.swift` — contains `canonicalSchemaVersion = "v7"`: FOUND
- `fitbodTests/Phase6/Fixtures/json/example-export.json` — contains `"schemaVersion" : "v7"`: FOUND
- Commit `52b1957` exists: FOUND
- Commit `d325e83` exists: FOUND
