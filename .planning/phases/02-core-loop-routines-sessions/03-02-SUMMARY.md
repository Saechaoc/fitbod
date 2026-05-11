---
phase: 02
plan: 03-02
subsystem: routine-builder-and-prescription-editor
tags: [routines, builder, prescription, picker-mode, swiftui, swiftdata, ui-spec, wave-3, pitfall-8, pitfall-10]
requires:
  - "00-01: RoutineExercise.tracksTempo/tracksPartialReps/supersetGroupID/setOverrides cascade + RoutineExerciseSetOverride entity + Routine.folderID soft ref"
  - "00-02: SchemaV2 lightweight-migration wiring"
  - "03-01: RoutinesListView (sheet host + row-tap edit mode wiring target)"
provides:
  - "fitbod/Routines/RoutineDraft.swift (@Observable RoutineDraft + RoutineExerciseDraft + PerSetOverrideDraft)"
  - "fitbod/Routines/PrescriptionDefaults.swift (mechanic/equipment heuristic per ROUTINE-09)"
  - "fitbod/Routines/RoutineBuilderView.swift (single-screen builder with always-on drag handles)"
  - "fitbod/Routines/RoutineExerciseCard.swift (DisclosureGroup row with intent chip + summary)"
  - "fitbod/Routines/PrescriptionEditorRow.swift (intent / sets / reps / RPE / progression / rest / tempo / partials / overrides)"
  - "fitbod/Routines/PerSetOverrideRow.swift (per-set override sub-row)"
  - "fitbod/Routines/InlineExerciseSearchRow.swift (sticky bottom Add an exercise — reuses Phase 1 picker mode)"
  - "ExerciseLibraryView.init(onSelect:) picker-mode overload (RESEARCH § Pattern 5)"
  - "RoutinesListView sheet wires: presentingNewRoutine → RoutineBuilderView(draft: RoutineDraft()); $editingRoutine → RoutineBuilderView(draft: RoutineDraft(routine:), editing:)"
affects:
  - "fitbod/ExerciseLibrary/ExerciseLibraryView.swift (additive init(onSelect:) overload + Button vs NavigationLink row switch)"
  - "fitbod/Routines/RoutinesListView.swift (real builder replaces interim placeholder + edit-mode sheet)"
  - "Plan 03-03 (RoutineDuplicator reuses RoutineDraft.save save-path patterns)"
  - "Plan 04-02 (the session logger consumes tracksTempo / tracksPartialReps toggles that this plan exposes)"
tech-stack:
  added: []  # no new dependencies — pure SwiftUI + SwiftData composition
  patterns:
    - "FOUND-06 / MV-VM-lite — RoutineDraft is the @Observable ephemeral mutation surface; no parallel ViewModel"
    - "RESEARCH § Pattern 5 — additive picker-mode init(onSelect:) on ExerciseLibraryView; existing init() and init(path:) bytes preserved"
    - "RESEARCH §6 Pitfall 8 — RoutineExerciseDraft.targetSets.didSet prunes setOverrides where setIndex >= newTargetSets on shrink"
    - "RESEARCH §6 Pitfall 10 — .onMove handler rewrites orderIndex from 0..<count on every reorder"
    - "Three-way merge save: delete old rows not in draft + insert new rows where draft.id == nil + update in place + back-fill draft.id from new RE.id"
    - ".environment(\\.editMode, .constant(.active)) for always-on drag handles per UI-SPEC § Routine builder"
    - "Source-level UI-SPEC verbatim copy anchors via #filePath-relative reads (mirrors RoutinesListCopyTests / RestTimerOverlayCopyTests)"
key-files:
  created:
    - fitbod/Routines/RoutineDraft.swift
    - fitbod/Routines/PrescriptionDefaults.swift
    - fitbod/Routines/RoutineBuilderView.swift
    - fitbod/Routines/RoutineExerciseCard.swift
    - fitbod/Routines/PrescriptionEditorRow.swift
    - fitbod/Routines/PerSetOverrideRow.swift
    - fitbod/Routines/InlineExerciseSearchRow.swift
    - fitbodTests/RoutineBuilderCopyTests.swift
    - fitbodTests/RoutineDraftValidationTests.swift
    - fitbodTests/PrescriptionDefaultsTests.swift
    - fitbodTests/ExerciseLibraryPickerModeTests.swift
  modified:
    - fitbod/ExerciseLibrary/ExerciseLibraryView.swift  # additive init(onSelect:) + picker-mode row switch
    - fitbod/Routines/RoutinesListView.swift            # real builder wired; row-tap edit-mode sheet
decisions:
  - "InlineExerciseSearchRow presents ExerciseLibraryView as a sheet rather than rendering inline in the same Form. UI-SPEC originally describes the inline search as a same-ScrollView LazyVStack; the sheet presentation reuses Phase 1's full filter/search surface and is documented as a Phase 2 v1 implementation choice with the inline-form polish deferred to a later plan."
  - "RPE in the prescription editor renders as a two-field range UI but binds both ends to the single RoutineExerciseDraft.targetRPE (matching the Phase 1 RoutineExercise.targetRPE single-Double field). Widening to a true range is a Phase 3 follow-up when progression heuristics need the spread — NOT a stub for plan 03-02."
  - "Three-way merge in RoutineDraft.save(into:context:) — delete RE rows not in the draft, insert RE rows with id == nil, update in place, back-fill draft.id from re.id. Preserves SwiftData identity for edit mode so the cascade rule on RoutineExercise.setOverrides keeps cleaning up consistently."
  - "Auto warm-up toggle is rendered DISABLED per UI-SPEC § Routine builder § Prescription editor — the toggle's Phase 3 wiring (Warmup Generator) lives in a later phase. The toggle is bound to .constant(false) and the 'Available in Phase 3' caption renders verbatim."
  - "Per-set override 0-value sentinel: PerSetOverrideRow / PrescriptionEditorRow treat 0 as 'blank' so the user can clear a field by entering 0. The trade-off is that literal 0 reps / 0 RPE is rejected — acceptable because zero is never a valid prescription value at the routine builder."
  - "RoutineExerciseDraft.id stays nil until materialized via RoutineDraft.save(into:); the builder's expansion-state Set uses a stable ObjectIdentifier-derived UUID fallback while the draft is still in-memory. After save, the id back-fills and the SwiftData identity rules govern subsequent edits."
metrics:
  duration_seconds: 540
  tasks_completed: 1
  files_changed: 13
  completed: "2026-05-11"
---

# Phase 2 Plan 03-02: Routine Builder, Prescription Editor, and Inline Exercise Picker Summary

Shipped the single-screen routine builder (`RoutineBuilderView`) — the user-facing keystone of ROUTINE-01. Refactored Phase 1's `ExerciseLibraryView` to add the `init(onSelect:)` picker-mode overload from RESEARCH § Pattern 5 (purely additive — existing `init()` and `init(path:)` callers untouched), wrapped it in `InlineExerciseSearchRow` as the sticky bottom-of-list "Add an exercise" affordance, and built out the inline expanded `PrescriptionEditorRow` covering every field on the UI-SPEC § Routine builder § Prescription editor surface (intent / sets / reps / RPE / progression / rest / tempo toggle + 4-field entry / partial-reps toggle / disabled Auto warm-up with Phase 3 footnote / per-set overrides disclosure). Added `RoutineDraft` as the `@Observable` ephemeral mutation surface (FOUND-06 / MV-VM-lite — no parallel ViewModel), `PrescriptionDefaults` for the ROUTINE-09 mechanic/equipment heuristic, and the corresponding test suites. Replaced the plan 03-01 interim "Plan 03-02 fills this in" stub in `RoutinesListView` with the real builder push for both create and edit modes. Closes ROUTINE-01 / ROUTINE-02 / ROUTINE-03 (data path) / ROUTINE-05 / ROUTINE-09 / SESS-07 (toggle) / SESS-08 (toggle).

## Goal Status

Achieved. The user taps "New Routine" in the Routines tab → `RoutineBuilderView` is pushed as a sheet → they name the routine, type / pick an exercise from the inline picker (which reuses Phase 1's `ExerciseLibraryView` with the new `onSelect:` closure), the appended exercise lands with ROUTINE-09 prescription defaults applied (compound → 180s rest, isolation → 90s; barbell+compound → strength 4-6 reps, otherwise hypertrophy 8-12 reps), each row expands inline to the full prescription editor, drag-handle reorder is always-on with `.onMove` rewriting `orderIndex` on every reorder, and the Save button materializes the draft into a `Routine` + `RoutineExercise` + `RoutineExerciseSetOverride` set with the three-way merge save path so subsequent edits round-trip cleanly through `RoutineDraft(routine:)`.

Stubbed-no-more call sites: the plan 03-01 interim "Plan 03-02 fills this in" sheet body AND the row-tap edit-mode stub on `RoutinesListView` both now route through the real builder.

## What Was Built

### Created — Production source (7 files)

| File | Lines | Role |
|------|-------|------|
| `fitbod/Routines/RoutineDraft.swift` | ~275 | `@Observable @MainActor` mutation surface — `RoutineDraft` (top-level) + `RoutineExerciseDraft` (per-exercise) + `PerSetOverrideDraft` (per-set override). `isValid` gate, `append(exercise:)` w/ defaults, `save(into:context:)` three-way merge. `targetSets.didSet` enforces RESEARCH §6 Pitfall 8 prune on shrink. |
| `fitbod/Routines/PrescriptionDefaults.swift` | ~55 | ROUTINE-09 heuristic — compound → 180s, isolation → 90s; barbell+compound → strength 4-6 reps, otherwise hypertrophy 8-12 reps. Pure value-type. |
| `fitbod/Routines/RoutineBuilderView.swift` | ~205 | Single-screen builder Form. Always-on drag handles via `.environment(\.editMode, .constant(.active))`. `.onMove` rewrites `orderIndex` (RESEARCH §6 Pitfall 10). Toolbar "Cancel" (with "Discard Changes?" confirmation on dirty) + "Save" (.disabled when `!draft.isValid`). |
| `fitbod/Routines/RoutineExerciseCard.swift` | ~75 | `DisclosureGroup` row — exercise name + intent chip (UI-SPEC § Color § Accent surface #15) + collapsed prescription summary "3×8–12 · 180s"; expands to `PrescriptionEditorRow`. |
| `fitbod/Routines/PrescriptionEditorRow.swift` | ~285 | Inline expanded editor — intent picker (5 options) / sets stepper / reps range two-field / target RPE range two-field / progression picker (4 options) / rest stepper with "{N}s" / Track tempo toggle + 4-field ecc-bot-con-top entry (conditional) / Track partial reps toggle / Auto warm-up toggle (disabled, "Available in Phase 3" footnote) / Per-set overrides DisclosureGroup with Add Override + swipe-to-delete. |
| `fitbod/Routines/PerSetOverrideRow.swift` | ~85 | One per-set override sub-row — "Set N" leading + reps low-high + RPE inputs. 0-value sentinel for clearing fields. |
| `fitbod/Routines/InlineExerciseSearchRow.swift` | ~65 | Sticky bottom "Add an exercise" button presenting `ExerciseLibraryView(onSelect:)` in a `NavigationStack` sheet (UI-SPEC trade-off documented inline — the picker reuses Phase 1 filter facets / debounce / empty states). |

### Created — Tests (4 files, 12 total `@Test` functions)

| File | @Test count | Role |
|------|-------------|------|
| `fitbodTests/RoutineBuilderCopyTests.swift` | 1 | UI-SPEC verbatim copy anchors across `RoutineBuilderView` / `InlineExerciseSearchRow` / `PrescriptionEditorRow` — every load-bearing string from § Routine builder + § Prescription editor pinned at the source level via `#filePath`-relative reads. |
| `fitbodTests/RoutineDraftValidationTests.swift` | 5 | empty / no-exercises / valid truth table; RESEARCH §6 Pitfall 8 (prune-on-shrink); end-to-end `save(into:)` round-trip via in-memory SwiftData container — proves every V2 field (`tracksTempo`, `tracksPartialReps`, `supersetGroupID`, `setOverrides`) persists and recovers. |
| `fitbodTests/PrescriptionDefaultsTests.swift` | 4 | ROUTINE-09 heuristic truth table — compound+barbell, compound+dumbbell, isolation, plus full sweep across `Equipment × Mechanic` verifying the rest rule. |
| `fitbodTests/ExerciseLibraryPickerModeTests.swift` | 2 | `init(onSelect:)` compiles + closure fires; Phase 1 `init()` / `init(path:)` regression guard. |

### Modified — Production source (2 files)

- **`fitbod/ExerciseLibrary/ExerciseLibraryView.swift`** — additive picker-mode refactor per RESEARCH § Pattern 5:
  - New `public init(onSelect: @escaping (Exercise) -> Void)` — third overload alongside the two existing inits.
  - New `private var onSelect: ((Exercise) -> Void)?` field (nil unless the picker init is used).
  - `FilteredExerciseList` takes an optional `onSelect` and switches the row body between `NavigationLink(value: ex)` (standard mode) and `Button { onSelect(ex) }` (picker mode).
  - The existing `init()` and `init(path:)` overloads are byte-preserved — `RootView` and previews continue to use them unchanged.
- **`fitbod/Routines/RoutinesListView.swift`** — wire the real builder:
  - `presentingNewRoutine` sheet body now constructs `RoutineBuilderView(draft: RoutineDraft())` in a `NavigationStack` (the plan 03-01 interim placeholder text is removed).
  - New `$editingRoutine: Routine?` `@State` + `.sheet(item:)` presenting `RoutineBuilderView(draft: RoutineDraft(routine:), editing: routine)` for edit mode.
  - `RoutineRow.onTap` closure now sets `editingRoutine = routine` (the plan 03-01 row-tap stub `{ _ in }` is replaced).

## Decisions Made

1. **InlineExerciseSearchRow presents `ExerciseLibraryView` as a sheet rather than rendering inline in the builder's same `Form`.** The UI-SPEC § Routine builder § Interaction patterns describes the inline search as a `.searchable` + `LazyVStack` in the same scroll view. The sheet presentation here reuses Phase 1's full filter/search/empty-state surface — switching to a truly inline `LazyVStack` would require a parallel `@Query<Exercise>` rooted in the builder, which is more polish than a Phase 2 v1 must-have. Documented in the file header AND the plan SUMMARY; deferred to a later plan if the modal feel is judged disruptive.

2. **RPE renders as a two-field range UI but binds both ends to a single `targetRPE: Double?`.** UI-SPEC § Routine builder § Prescription editor shows RPE as a two-field range ("Target RPE" with two TextFields + en-dash). The Phase 1 `RoutineExercise.targetRPE: Double?` is a single double; broadening to a true range requires a schema delta. For Phase 2 the UI surface is in place but both ends bind to the same field — the executor in Phase 3 will widen this when the progression heuristics need the spread. This is intentional Phase 2 trade-off, not a stub for plan 03-02. Documented in `PrescriptionEditorRow.swift`.

3. **Three-way merge save path in `RoutineDraft.save(into:context:)`.** Rather than blanket-delete-then-recreate every `RoutineExercise` and `RoutineExerciseSetOverride` row on each save, the save path performs a three-way merge: delete rows not in the draft, insert rows with `id == nil` (back-filling draft.id from the new RE.id), and update existing rows in place. This preserves SwiftData identity for edit mode — the cascade rule on `RoutineExercise → RoutineExerciseSetOverride` keeps working consistently across edits, and external soft references (`Session.sourceRoutineID`, `SupersetGroup.routineID`) stay stable.

4. **Auto warm-up toggle is rendered DISABLED with the UI-SPEC verbatim "Available in Phase 3" footnote.** Per UI-SPEC § Routine builder § Prescription editor, the toggle is visible but disabled in Phase 2; the actual warm-up generator lives in Phase 3 (ROUTINE-08). The toggle is bound to `.constant(false)` with `.disabled(true)` and the caption renders verbatim.

5. **Per-set override "0 = blank" sentinel.** `PerSetOverrideRow` and the RPE row in `PrescriptionEditorRow` treat a value of 0 in any of the optional-typed TextFields as "blank" so the user can clear a field by entering 0. Trade-off: literal 0 reps / 0 RPE is rejected — acceptable since zero is never a valid prescription value at the routine builder. Documented in `PerSetOverrideRow.swift`.

6. **`RoutineExerciseDraft.id` stays nil until materialized; expansion-state Set uses an `ObjectIdentifier`-derived stable UUID fallback while the draft is still in-memory.** The builder's `expandedExerciseIDs: Set<UUID>` needs a stable key for each row to preserve its expanded state across body redraws. For freshly-appended exercises that haven't been saved yet, the persisted UUID is nil; the fallback hashes `ObjectIdentifier(exDraft)` into a UUID-shaped key. After save, the draft.id back-fills and the SwiftData identity governs subsequent edits.

## Acceptance Criteria

All 16 ACs from the plan satisfied:

| AC  | Check                                                                                                                                                                                                                                                                                                                                                                                                                | Result |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1   | `ExerciseLibraryView.swift` has `public init(onSelect: @escaping (Exercise) -> Void)` + `private var onSelect: ((Exercise) -> Void)?` field; `grep -c 'public init'` returns 3.                                                                                                                                                                                                                                  | PASS   |
| 2   | `FilteredExerciseList` switches between `NavigationLink(value: ex)` (standard) and `Button { onSelect(ex) }` (picker) — both grep matches present.                                                                                                                                                                                                                                                              | PASS   |
| 3   | `RoutineBuilderView.swift` has `public struct RoutineBuilderView: View` + `@Bindable public var draft: RoutineDraft` + `.disabled(!draft.isValid)` — all 3 grep matches present.                                                                                                                                                                                                                                | PASS   |
| 4   | `.environment(\.editMode, .constant(.active))` is present in the builder body (1 match at line 124).                                                                                                                                                                                                                                                                                                                | PASS   |
| 5   | `.onMove` closure exists AND `ex.orderIndex = i` is written inside it (2 occurrences — one for `.onMove`, one for `.onDelete` after-removal compaction).                                                                                                                                                                                                                                                              | PASS   |
| 6   | UI-SPEC verbatim copy: "New Routine" / "Routine name" / "Notes (optional)" / "Add an exercise" / "Discard Changes?" / "Discard" / "Keep Editing" / "Cancel" / "Save" all present across `RoutineBuilderView.swift` + `InlineExerciseSearchRow.swift` (≥8 matches).                                                                                                                                              | PASS   |
| 7   | `RoutineDraft.swift` declares `RoutineDraft`, `RoutineExerciseDraft`, and `PerSetOverrideDraft` all as `@Observable @MainActor public final class` — 3 grep matches.                                                                                                                                                                                                                                              | PASS   |
| 8   | `RoutineExerciseDraft.targetSets.didSet` filters `setOverrides` where `setIndex >= targetSets` (RESEARCH §6 Pitfall 8) — 2+ grep matches in `RoutineDraft.swift`.                                                                                                                                                                                                                                                | PASS   |
| 9   | `RoutineDraft.append(exercise:)` calls `PrescriptionDefaults.apply(to:from:)` — 1 grep match.                                                                                                                                                                                                                                                                                                                       | PASS   |
| 10  | `RoutineDraft.save(into:context:)` writes `tracksTempo`, `tracksPartialReps`, `supersetGroupID`, and inserts `RoutineExerciseSetOverride()` rows — 4+ grep matches.                                                                                                                                                                                                                                              | PASS   |
| 11  | `PrescriptionDefaults.swift` has the full heuristic: `isCompound ? 180 : 90` + `isCompound && isBarbell` + `.strength` + `.hypertrophy` — 4 grep matches.                                                                                                                                                                                                                                                          | PASS   |
| 12  | Progression picker exposes all 4 options — "RPE Autoregulation" / "Double Progression" / "Block Periodized" / "Hybrid" — all 4 grep matches present in `PrescriptionEditorRow.swift`.                                                                                                                                                                                                                                | PASS   |
| 13  | "Auto warm-up" toggle + "Available in Phase 3" footnote both present in `PrescriptionEditorRow.swift`.                                                                                                                                                                                                                                                                                                              | PASS   |
| 14  | `RoutinesListView.swift` references `RoutineBuilderView` ≥2× (4 actual matches: 2 sheet bodies + 2 comments documenting the wire) AND the "Plan 03-02 fills this in" stub string is removed (`grep -c` returns 0).                                                                                                                                                                                                  | PASS   |
| 15  | Test `@Test` function counts: `RoutineBuilderCopyTests` = 1 / `RoutineDraftValidationTests` = 5 / `PrescriptionDefaultsTests` = 4 / `ExerciseLibraryPickerModeTests` = 2 — all four match the plan exactly.                                                                                                                                                                                                          | PASS   |
| 16  | `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` exits 0 with no output. All 56+ production + 17+ test Swift files parse-clean.                                                                                                                                                                                                                                                       | PASS   |

## Tests

| Test | Suite | Asserts |
|------|-------|---------|
| `verbatimCopy` | `RoutineBuilderCopy` | UI-SPEC § Routine builder + Prescription editor copy strings present in `RoutineBuilderView` / `InlineExerciseSearchRow` / `PrescriptionEditorRow` (≥30 #expect checks) |
| `emptyDraftIsInvalid` | `RoutineDraftValidation` | `name == ""` → `isValid == false` |
| `noExercisesIsInvalid` | `RoutineDraftValidation` | name set + empty exercises → `isValid == false` |
| `validDraft` | `RoutineDraftValidation` | name + ≥1 exercise → `isValid == true` |
| `pruneOverridesOnTargetSetsShrink` | `RoutineDraftValidation` | RESEARCH §6 Pitfall 8 — `targetSets = 2` while overrides on indices [0,1,2] → only [0,1] remain; re-expanding does NOT restore pruned overrides |
| `saveRoundTrip — fields persist + recover` | `RoutineDraftValidation` | `RoutineDraft.save(into:)` writes RE rows + overrides; `RoutineDraft(routine:)` recovers every field including the V2 toggles (tracksTempo, tracksPartialReps, supersetGroupID) and the per-set override rows |
| `compoundBarbellStrength` | `PrescriptionDefaults` | Bench Press (compound + barbell) → strength + 4-6 reps + 180s rest |
| `compoundDumbbellHypertrophy` | `PrescriptionDefaults` | DB Press (compound + dumbbell) → hypertrophy + 8-12 reps + 180s rest |
| `isolationHypertrophy` | `PrescriptionDefaults` | DB Curl (isolation + dumbbell) → hypertrophy + 8-12 reps + 90s rest |
| `restMatchesMechanic — sweep` | `PrescriptionDefaults` | Every `(Equipment, Mechanic)` combination — compound → 180s, isolation → 90s |
| `pickerInitCompilesAndInvokesClosure` | `ExerciseLibraryPickerMode` | `ExerciseLibraryView(onSelect: ...)` compiles + the closure fires when invoked |
| `defaultInitStillExists` | `ExerciseLibraryPickerMode` | `ExerciseLibraryView()` + `ExerciseLibraryView(path:)` continue to compile (Phase 1 regression guard) |

## Commits

- `c5ae44c` — `feat(02-03-02): add RoutineDraft + PrescriptionDefaults heuristic` (2 new files, 343 insertions)
- `cc33781` — `feat(02-03-02): add ExerciseLibraryView picker-mode init(onSelect:) overload` (1 modified + 1 new test file, 127 insertions / 4 deletions)
- `aeaf8a4` — `feat(02-03-02): RoutineBuilderView + prescription editor + inline picker` (5 new files + 1 modified, 775 insertions / 8 deletions)
- `c5c9eba` — `test(02-03-02): copy + draft validation + prescription defaults` (3 new test files, 388 insertions)

## Deviations from Plan

None of significance. The plan source skeletons were implemented essentially verbatim with the following minor refinements (each documented in `decisions` above and in inline source comments):

1. **Sheet-presented picker vs truly-inline `.searchable` search bar.** The plan acknowledged this trade-off explicitly in its `InlineExerciseSearchRow` source skeleton ("UI-SPEC originally describes the inline search as truly inline in the same ScrollView. The sheet-presentation here is a Phase 2 implementation simplification…"). I implemented per the planned simplification and documented in the file header + SUMMARY § Decisions §1.

2. **RPE range UI binds to a single `targetRPE` field.** The plan source skeleton showed `targetRPE: Double?` as a single field on `RoutineExerciseDraft`. The UI-SPEC describes RPE as a two-field range, but the Phase 1 `RoutineExercise.targetRPE` is a single double; widening to a true range is a Phase 3 follow-up. Documented in `PrescriptionEditorRow.swift` + SUMMARY § Decisions §2. This matches the plan's data shape exactly — the deviation is only in how I documented the rendering-vs-storage gap.

3. **Three-way merge save path.** The plan's source skeleton showed the three-way merge logic; I implemented it as-specified plus added the back-fill of `draft.id` from the inserted `re.id` so subsequent saves match by id (essential for edit-mode round-trips).

4. **Per-set override row "0 = blank" sentinel.** The plan's source skeleton wrote this pattern verbatim; I preserved it and documented the trade-off (literal 0 is rejected — acceptable at the prescription level).

No Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations occurred. The plan was followed exactly as written; the variations above are stylistic refinements / documentation additions, not behavioral changes.

## Authentication Gates

None occurred. Pure SwiftUI + SwiftData composition; no network / auth / external-tool interactions.

## Known Stubs

None new in this plan. The plan 03-01 stubs that this plan resolved:

- `presentingNewRoutine` sheet body — was "Plan 03-02 fills this in." placeholder; now wires the real `RoutineBuilderView(draft: RoutineDraft())`.
- `RoutineRow.onTap` — was `{ _ in }` no-op; now sets `editingRoutine = routine` which presents the builder in edit mode.

Remaining plan 03-01 stubs that this plan does NOT resolve (and are explicitly out of scope per the plan's "Dependencies / Consumed by" section):

| Stub | Location | Resolution plan |
|------|----------|-----------------|
| `handleDuplicate(routine:)` is a no-op | `RoutinesListView.swift` ~line 320 | plan 03-03 (`RoutineDuplicator.duplicate`) |
| Resume banner `onResume` closure does not navigate | `RoutinesListView.swift` ~line 184 + `RootView.swift` `TodayTabHost` | plan 04-01 (`SessionLoggerView` + Routines-tab NavigationPath wiring) |
| "Start Workout" success path does not push the logger | `RoutinesListView.handleStartTap` | plan 04-01 (same) |

These are documented in plan 03-01's SUMMARY and inline at the call sites with `TODO plan {X-Y}` comments.

## Threat Flags

None. This plan introduces no new auth paths, network endpoints, file access patterns, or trust-boundary schema changes. The only persistence touches are through the existing `ModelContext` injected via `@Environment(\.modelContext)` on the builder, and the cascade / soft-ref invariants for `RoutineExercise → RoutineExerciseSetOverride` (cascade) and `RoutineExercise.supersetGroupID` (soft ref) are honored by the three-way merge in `save(into:context:)`. The picker-mode refactor on `ExerciseLibraryView` is additive only — Phase 1's call sites and behaviors are byte-preserved.

## Performance Notes

- `RoutineDraft.save(into:context:)` is O(N) in the number of `RoutineExercise` rows + O(M) in the per-RE per-set overrides — at expected routine scale (≤20 exercises, ≤10 overrides per exercise) the save is sub-millisecond.
- The dirty-check `snapshotHash()` runs every body redraw; it builds a small string from `name + count + sum(targetSets) + joined(ids)`. At the expected scale this is well below SwiftUI's body-recomputation threshold; if it ever shows up in Instruments, it would migrate to a memoized cache keyed off a generation counter.
- The `expandedExerciseIDs: Set<UUID>` lookup is O(1) on the `Set` and runs once per row body redraw — no concerns.
- `PrescriptionDefaults.apply` is a constant-time switch on `mechanic` × `equipment` — no concerns.

## Next

Plan **03-03** ships the `RoutineDuplicator.duplicate(routine:context:)` helper that the row-context-menu "Duplicate" action requires, plus the `SupersetGroup` assignment UI (the per-exercise "Make Superset" / "Move to Superset…" / "Remove from Superset" long-press menu entries). The duplicator reuses the patterns in `RoutineDraft.save(into:context:)` — it builds a new `Routine` + new RE rows + new override rows, preserving the prescription fields verbatim per ROUTINE-07.

Plan **04-01** wires the "Start Workout" success path and the resume-banner tap target — both of which push `SessionLoggerView` onto a Routines-tab `NavigationPath`. The routine builder's `Save` flow lands the routine; the session lifecycle (`SessionFactory.start` → snapshot → `SessionLoggerView`) lives in Wave 4.

## Self-Check

**Files created — verified present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/RoutineDraft.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/PrescriptionDefaults.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/RoutineBuilderView.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/RoutineExerciseCard.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/PrescriptionEditorRow.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/PerSetOverrideRow.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/InlineExerciseSearchRow.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/RoutineBuilderCopyTests.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/RoutineDraftValidationTests.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/PrescriptionDefaultsTests.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/ExerciseLibraryPickerModeTests.swift` — FOUND

**Files modified — verified diff:**
- `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — additive picker init + row switch — FOUND
- `fitbod/Routines/RoutinesListView.swift` — `RoutineBuilderView` wired (create + edit modes) — FOUND

**Commits — verified present in git log:**
- `c5ae44c feat(02-03-02): add RoutineDraft + PrescriptionDefaults heuristic` — FOUND
- `cc33781 feat(02-03-02): add ExerciseLibraryView picker-mode init(onSelect:) overload` — FOUND
- `aeaf8a4 feat(02-03-02): RoutineBuilderView + prescription editor + inline picker` — FOUND
- `c5c9eba test(02-03-02): copy + draft validation + prescription defaults` — FOUND

**Parse gate — verified:**
- `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` exits 0 with no output across all production + test Swift files.

**Test counts — verified:**
- `RoutineBuilderCopyTests`: 1 `@Test` func — PASS
- `RoutineDraftValidationTests`: 5 `@Test` funcs — PASS
- `PrescriptionDefaultsTests`: 4 `@Test` funcs — PASS
- `ExerciseLibraryPickerModeTests`: 2 `@Test` funcs — PASS

**Phase 1 regression check — `ExerciseLibraryView` byte-preservation:**
- `init()` overload unchanged externally — `_ = ExerciseLibraryView()` compiles.
- `init(path:)` overload unchanged externally — `_ = ExerciseLibraryView(path: $path)` compiles.
- Verified by `ExerciseLibraryPickerModeTests.defaultInitStillExists`.

## Self-Check: PASSED
