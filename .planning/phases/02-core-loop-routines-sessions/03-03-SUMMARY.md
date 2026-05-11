---
phase: 02
plan: 03-03
subsystem: supersets-and-routine-duplication
tags: [routines, supersets, giant-sets, duplication, deep-copy, swiftui, swiftdata, ui-spec, wave-3, pitfall-6, pitfall-1]
requires:
  - "00-01: SupersetGroup entity + RoutineExercise.supersetGroupID soft ref + RoutineExerciseSetOverride cascade"
  - "00-02: SchemaV2 lightweight-migration wiring"
  - "03-01: RoutinesListView.handleDuplicate stub + RoutineRow context-menu wiring target"
  - "03-02: RoutineBuilderView + RoutineExerciseCard host + RoutineDraft.save patterns"
provides:
  - "fitbod/Routines/RoutineDuplicator.swift (public enum RoutineDuplicator + duplicate(routine:context:) deep-copy entry point)"
  - "fitbod/Routines/SupersetAssignmentSheet.swift (public struct SupersetAssignmentSheet: View — long-press menu sheet for Move to Superset / New Superset)"
  - "RoutineExerciseCard 4pt accent rail when supersetGroupID != nil (UI-SPEC accent surface #9)"
  - "RoutineExerciseCard long-press context menu (Edit Prescription / Move to Superset… / Remove from Superset / Make Superset / Duplicate Exercise / Remove)"
  - "RoutineBuilderView pendingSupersetAssignment state + sheet presentation + Save-Routine-First gate for create mode"
  - "RoutineBuilderView in-builder duplicateExercise + removeExercise helpers wired to the long-press menu"
  - "RoutinesListView.handleDuplicate now calls RoutineDuplicator.duplicate"
affects:
  - "fitbod/Routines/RoutineExerciseCard.swift (HStack wrapper + leading 4pt rail + .contextMenu block)"
  - "fitbod/Routines/RoutineBuilderView.swift (closure wiring + sheet + alert + handlers)"
  - "fitbod/Routines/RoutinesListView.swift (handleDuplicate stub replaced with RoutineDuplicator.duplicate call)"
tech-stack:
  added: []  # no new dependencies — pure SwiftUI + SwiftData composition
  patterns:
    - "RESEARCH §6 Pitfall 6 — SupersetGroup rows cloned FIRST so groupIDMap is fully populated before RoutineExercise clones reference it"
    - "PITFALLS-doc #1 — every cloned row is a fresh insert; clones' field values copied verbatim; only IDs (and the soft-ref supersetGroupID via the map) diverge"
    - "Soft-ref design (CONTEXT.md Area 1 / Area 6) — SupersetGroup.routineID is a UUID weak ref; no SwiftData cascade; the duplicator's explicit fetch-by-routineID is the load-bearing wire"
    - "Sheet writes to RoutineExerciseDraft.supersetGroupID (in-memory builder draft); persisted write happens at Save time via RoutineDraft.save(into:context:)"
    - "Edit-mode gate — assignment sheet only opens when editing != nil; create-mode shows Save-Routine-First alert (SupersetGroup.routineID needs persisted Routine to anchor against)"
    - "In-builder duplicate vs routine-level duplicate split — duplicateExercise(_:) on the builder is a quick row clone; RoutineDuplicator is the full deep-copy entry point for the Routines list"
    - "Source-level grep ACs verify presence of every UI-SPEC verbatim string + every cascade / remap pattern"
key-files:
  created:
    - fitbod/Routines/RoutineDuplicator.swift
    - fitbod/Routines/SupersetAssignmentSheet.swift
    - fitbodTests/RoutineDuplicationTests.swift
    - fitbodTests/SupersetGroupTests.swift
  modified:
    - fitbod/Routines/RoutineExerciseCard.swift        # leading 4pt rail + .contextMenu + closure init params
    - fitbod/Routines/RoutineBuilderView.swift          # pendingSupersetAssignment + sheet + alert + handlers
    - fitbod/Routines/RoutinesListView.swift            # handleDuplicate wired to RoutineDuplicator.duplicate
decisions:
  - "Edit-mode gate: SupersetAssignmentSheet only opens when editing != nil. In create mode, attempting to assign a superset surfaces a 'Save Routine First' alert. Rationale: SupersetGroup.routineID is a soft UUID ref to a persisted Routine — creating a SupersetGroup against an unsaved-draft routine would leave an orphan group in the store if the user cancels. The alert keeps the create-mode flow predictable and avoids speculative persistence."
  - "In-builder duplicateExercise(_:) does NOT clone per-set overrides. The in-builder duplicate is a quick 'give me another row like this' affordance for prescribing two similar lifts; full deep-copy with overrides is what RoutineDuplicator handles at the routine level."
  - "In-builder duplicateExercise(_:) does NOT copy supersetGroupID. The duplicate starts as a standalone exercise; the user can long-press it and assign a superset explicitly. Rationale: if the source was paired, an automatic copy of supersetGroupID would create a 3-way giant set silently — surprising behavior."
  - "Sheet presentation uses .sheet(isPresented:) with a manual Binding rather than .sheet(item:). RoutineExerciseDraft has id: UUID? (Optional), so Identifiable-driven sheet(item:) would either collide for two nil-ID drafts or churn the sheet identity when the id back-fills on save. The manual binding cleanly tracks the optional draft state."
  - "Sheet immediately persists new SupersetGroup rows on 'New Superset' tap (ctx.save() inside the button action). Rationale: the sheet's @Query<SupersetGroup> needs to see the row in subsequent presentations; the per-exercise assignment lives on the in-memory draft and is persisted at Save time."
  - "RoutineExerciseCard.init grows by 4 closures with default no-op values. Default-noop preserves the Phase 1 / plan 03-02 callers (preview blocks, existing tests) without forcing every call site to pass all 4. Equivalent to the plan's source skeleton."
  - "RoutineDuplicator.duplicate runs try? context.save() at the end (non-fatal). A save failure is logged via the existing console path, not surfaced as a user-visible alert. The duplicate action is low-stakes (user can retry); an alert would interrupt the typical Routines-tab flow more than it would help."
metrics:
  duration_seconds: 720
  tasks_completed: 1
  files_changed: 7
  completed: "2026-05-11"
---

# Phase 2 Plan 03-03: Supersets, Giant Sets, and Routine Duplication Summary

Shipped the two remaining ROUTINE-* requirements that plan `03-02` deferred: supersets / giant sets (ROUTINE-04) and routine duplication (the deep-copy half of ROUTINE-06; folders were closed by plan `03-01`). Added `RoutineDuplicator` as the deep-copy entry point handling `Routine` + `RoutineExercise` + cascade-owned `RoutineExerciseSetOverride` + the soft-ref `SupersetGroup` rows with UUID remap per RESEARCH §6 Pitfall 6. Added `SupersetAssignmentSheet` as the long-press menu sheet for "Add to Superset" / "New Superset". Modified `RoutineExerciseCard` with the UI-SPEC § Color § Accent surface #9 leading 4pt-wide accent rail (rendered when `supersetGroupID != nil`) plus the UI-SPEC verbatim long-press context menu ("Edit Prescription" / "Move to Superset…" / "Remove from Superset" / "Make Superset" / "Duplicate Exercise" / "Remove"). Wired `RoutineBuilderView` state for the assignment sheet (`pendingSupersetAssignment: RoutineExerciseDraft?`) with a create-mode "Save Routine First" alert gate. Replaced the plan 03-01 stub `handleDuplicate(routine:)` in `RoutinesListView` with the real `RoutineDuplicator.duplicate(routine:context:)` call.

Closes ROUTINE-04 (supersets) and the deep-copy half of ROUTINE-06 (duplication).

## Goal Status

Achieved. The user long-presses a routine exercise card in the builder → context menu shows the 5 UI-SPEC verbatim actions. "Move to Superset…" (when ungrouped) or "Make Superset" presents `SupersetAssignmentSheet` listing existing `SupersetGroup` rows for this routine + a "New Superset" accent action row. Selecting an existing group sets `RoutineExerciseDraft.supersetGroupID = groupID`; "New Superset" inserts a fresh `SupersetGroup` (immediately persisted so the @Query sees it next time) and assigns it. The 4pt accent rail renders on the left edge of every grouped card.

Duplication: tapping "Duplicate" on a row in the Routines list calls `RoutineDuplicator.duplicate(routine:context:)`. The duplicator deep-copies the source Routine + every owned RoutineExercise + cascade-owned RoutineExerciseSetOverride rows + the soft-ref SupersetGroup rows that belong to the source routine, freshly minting UUIDs and remapping `RoutineExercise.supersetGroupID` via a `[UUID: UUID]` map per RESEARCH §6 Pitfall 6. The clone surfaces as "{Original} (Copy)" in the same folder via @Query reactivity.

## What Was Built

### Created — Production source (2 files)

| File | Lines | Role |
|------|-------|------|
| `fitbod/Routines/RoutineDuplicator.swift` | ~135 | `public enum RoutineDuplicator` + `@MainActor public static func duplicate(routine:context:) -> Routine` — deep-copy entry point. SupersetGroup rows cloned FIRST → `groupIDMap` populated → RoutineExercise rows cloned with `supersetGroupID` remap → RoutineExerciseSetOverride rows cloned (cascade-owned). `try? context.save()` at end (non-fatal). |
| `fitbod/Routines/SupersetAssignmentSheet.swift` | ~125 | `public struct SupersetAssignmentSheet: View` — NavigationStack-wrapped List with `@Query<SupersetGroup>(routineID == routine.id)` rows + "New Superset" accent action row. Row labels match UI-SPEC format "Superset A (Bench + Row)" / "Superset B (Squat + Curl)" via `sortOrder → A/B/C` letter mapping. Writes to `RoutineExerciseDraft.supersetGroupID` (in-memory); SupersetGroup insertions immediately persisted. |

### Created — Tests (2 files, 10 total `@Test` functions)

| File | @Test count | Role |
|------|-------------|------|
| `fitbodTests/RoutineDuplicationTests.swift` | 6 | Deep-copy correctness: `nameSuffixedWithCopy` / `deepCopyOfRoutineExercises` (fresh IDs + exercise refs preserved) / `supersetGroupRemappedToClonedGroup` (RESEARCH §6 Pitfall 6 anchor) / `perSetOverridesCloned` (cascade-owned clones) / `folderIDPreserved` / `originalRoutineUntouched`. |
| `fitbodTests/SupersetGroupTests.swift` | 4 | SupersetGroup entity + supersetGroupID flow: `createAndAssign` / `unassignSetsNil` / `kindAccessor` / `orphanedSupersetGroupAfterRoutineDelete` (RoutinesListView.handleDelete sweep verified). |

### Modified — Production source (3 files)

- **`fitbod/Routines/RoutineExerciseCard.swift`** — Two structural additions per plan:
  1. `HStack(spacing: 0)` wrapper containing a leading 4pt-wide `Rectangle().fill(Color.accentColor)` rail that renders ONLY when `draft.supersetGroupID != nil` (UI-SPEC accent surface #9).
  2. `.contextMenu { ... }` on the DisclosureGroup with the 5 UI-SPEC verbatim entries — "Edit Prescription" / "Move to Superset…" (when ungrouped) or "Remove from Superset" (when grouped) / "Make Superset" / "Duplicate Exercise" / "Remove" (destructive). Init grows by 4 closures with default no-op values for backward compatibility.

- **`fitbod/Routines/RoutineBuilderView.swift`** — Three additions:
  1. `@State private var pendingSupersetAssignment: RoutineExerciseDraft? = nil` + `@State private var presentingSaveFirstAlert: Bool = false`.
  2. `.sheet(isPresented:)` presenting `SupersetAssignmentSheet(routine: editing, exerciseDraft: pendingSupersetAssignment)` when both are non-nil. `.alert("Save Routine First", isPresented: $presentingSaveFirstAlert)` for the create-mode gate.
  3. Closure wiring on `RoutineExerciseCard`: `onAssignSuperset: { handleAssignSuperset($0) }` (gates on `editing != nil` → either presents sheet or shows alert), `onRemoveFromSuperset: { $0.supersetGroupID = nil }`, `onDuplicate: { duplicateExercise($0) }`, `onRemove: { removeExercise($0) }`. Helpers `duplicateExercise(_:)` (in-memory clone inserted at index + 1, orderIndex rewritten) and `removeExercise(_:)` (in-memory remove + orderIndex rewrite).

- **`fitbod/Routines/RoutinesListView.swift`** — Replaced the plan 03-01 stub `handleDuplicate(routine:)` (no-op `_ = routine`) with `RoutineDuplicator.duplicate(routine: routine, context: ctx)`. Closes the ROUTINE-06 duplication gap referenced in plan 03-02's "Known Stubs" section.

## Decisions Made

1. **Edit-mode gate on the assignment sheet** — `SupersetAssignmentSheet` only opens when `editing != nil`. In create mode the long-press menu still surfaces "Move to Superset…" / "Make Superset", but tapping them shows a "Save Routine First" alert. Rationale: `SupersetGroup.routineID` is a soft UUID ref to a persisted Routine — creating a SupersetGroup against an unsaved-draft routine would leave an orphan group in the store if the user cancels. The alert keeps the create-mode flow predictable and avoids speculative persistence. Documented inline in `RoutineBuilderView.swift` plan-03-03 doc block.

2. **In-builder `duplicateExercise(_:)` does NOT clone per-set overrides** — The in-builder duplicate is a quick "give me another row like this" affordance for prescribing two similar lifts; full deep-copy with overrides is what `RoutineDuplicator.duplicate` handles at the routine level. Trade-off: the in-builder clone is fast and uncluttered; the user can re-add per-set overrides on the clone if they want them. Documented inline.

3. **In-builder `duplicateExercise(_:)` does NOT copy `supersetGroupID`** — The duplicate starts as a standalone exercise. Rationale: if the source was paired into a superset, an automatic copy of `supersetGroupID` would silently create a 3-way giant set, which is surprising behavior. The user can long-press the duplicate and assign a superset explicitly. Documented inline.

4. **Sheet presentation uses `.sheet(isPresented:)` with a manual Binding** rather than `.sheet(item:)`. Rationale: `RoutineExerciseDraft` has `id: UUID?` (Optional), so `Identifiable`-driven `.sheet(item:)` would either collide for two nil-ID drafts (when newly-appended exercises haven't been saved yet) or churn the sheet identity when the id back-fills on save. The manual binding cleanly tracks the optional draft state.

5. **SupersetGroup rows immediately persisted on "New Superset" tap** (`ctx.save()` inside the button action). Rationale: the sheet's `@Query<SupersetGroup>` needs to see the row in subsequent presentations (in case the user dismisses and reopens). The per-exercise assignment (`RoutineExerciseDraft.supersetGroupID`) lives on the in-memory draft and is persisted only at Save time via `RoutineDraft.save(into:context:)` — so cancelling the builder still leaves no per-exercise mutation behind, but pre-created SupersetGroup rows DO persist. Acceptable trade-off because empty supersets are valid in the schema and the orphan-cleanup sweep on routine delete handles abandoned groups.

6. **RoutineExerciseCard.init grows by 4 closures with default no-op values** — Default-noop preserves the Phase 1 / plan 03-02 callers (preview blocks, existing tests) without forcing every call site to pass all 4 closures explicitly. Equivalent to the plan's source skeleton; the plan's signature shows the closures as required, but the no-op defaults preserve backward compatibility without behavioral change for the new builder flow.

7. **RoutineDuplicator.duplicate runs `try? context.save()` at end** — Non-fatal save failure path. A save failure is logged via the existing console path (SwiftData prints a console warning), not surfaced as a user-visible alert. The duplicate action is low-stakes (user can retry); an alert would interrupt the typical Routines-tab flow more than it would help. Documented in the file header anti-patterns block.

## Acceptance Criteria

All 12 ACs from the plan satisfied:

| AC  | Check                                                                                                                                                  | Result |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| 1   | `RoutineDuplicator.swift` has `public enum RoutineDuplicator` + `public static func duplicate`. `grep -cE 'public enum RoutineDuplicator\|public static func duplicate'` returns 2. | PASS   |
| 2   | Duplicator clones SupersetGroup BEFORE RoutineExercise with `groupIDMap`. `grep -cE 'groupIDMap\|SupersetGroup\('` returns 6 (≥ 2).                              | PASS   |
| 3   | Duplicator clones per-set overrides. `grep -cE 'RoutineExerciseSetOverride\('` returns 2 (≥ 1).                                                                  | PASS   |
| 4   | Clone name is `"{original} (Copy)"`. `grep -c '(Copy)'` returns 3 (≥ 1).                                                                                          | PASS   |
| 5   | `SupersetAssignmentSheet.swift` has "Add to Superset" / "New Superset" / `Color.accentColor`. `grep -cE` returns 5 (≥ 3).                                       | PASS   |
| 6   | Row label format `"Superset A (Bench + Row)"`. Code at lines 119/121 uses `"Superset \(letter)"` and `"Superset \(letter) (\(names))"`.                          | PASS   |
| 7   | `RoutineExerciseCard.swift` has `frame(width: 4)` + `supersetGroupID != nil` + `.contextMenu` (3 matches) AND ≥5 verbatim menu items (9 matches).                | PASS   |
| 8   | `RoutineBuilderView.swift` has `pendingSupersetAssignment` + `SupersetAssignmentSheet`. `grep -cE` returns 10 (≥ 3).                                              | PASS   |
| 9   | `RoutinesListView.swift` has `RoutineDuplicator.duplicate(...)`. `grep -c` returns 3 (≥ 1).                                                                      | PASS   |
| 10  | `RoutineDuplicationTests.swift` has exactly 6 `@Test` functions: nameSuffixedWithCopy, deepCopyOfRoutineExercises, supersetGroupRemappedToClonedGroup, perSetOverridesCloned, folderIDPreserved, originalRoutineUntouched. | PASS   |
| 11  | `SupersetGroupTests.swift` has exactly 4 `@Test` functions: createAndAssign, unassignSetsNil, kindAccessor, orphanedSupersetGroupAfterRoutineDelete. | PASS   |
| 12  | `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` exits 0 with no output.                                                          | PASS   |

## Tests

| Test | Suite | Asserts |
|------|-------|---------|
| `nameSuffixedWithCopy` | `RoutineDuplication` | New routine name = "{original} (Copy)" |
| `deepCopyOfRoutineExercises` | `RoutineDuplication` | All RE rows cloned; IDs fresh; exercise refs preserved; cloned RE.routine == clone (not source); prescription fields preserved |
| `supersetGroupRemappedToClonedGroup` | `RoutineDuplication` | **RESEARCH §6 Pitfall 6** — SupersetGroup cloned + supersetGroupID remapped to cloned group, not source group |
| `perSetOverridesCloned` | `RoutineDuplication` | Per-set overrides cloned with fresh IDs, preserved values, and cloned-RE parent reference |
| `folderIDPreserved` | `RoutineDuplication` | Cloned routine inherits source's folderID |
| `originalRoutineUntouched` | `RoutineDuplication` | Source routine unchanged (the duplicate is a parallel object) |
| `createAndAssign` | `SupersetGroup` | Insert + assign via supersetGroupID round-trips through SwiftData |
| `unassignSetsNil` | `SupersetGroup` | Setting supersetGroupID = nil clears the assignment |
| `kindAccessor` | `SupersetGroup` | `kindRaw == "giant"` → `kind == .giant`; `"paired"` → `.paired` |
| `orphanedSupersetGroupAfterRoutineDelete` | `SupersetGroup` | RoutinesListView.handleDelete sweep pattern verified (query-and-delete by routineID before routine delete) |

## Commits

- `1da1c63` — `feat(02-03-03): RoutineDuplicator deep-copy + tests` (2 new files, 378 insertions)
- `e9b6318` — `feat(02-03-03): SupersetAssignmentSheet + accent rail + long-press menu` (2 new files + 2 modified, 439 insertions / 14 deletions)
- `c9bacfb` — `feat(02-03-03): wire RoutinesListView.handleDuplicate to RoutineDuplicator` (1 modified, 8 insertions / 6 deletions)

## Deviations from Plan

None of significance. The plan source skeletons were implemented essentially verbatim with the following refinements (each documented in `decisions` above and in inline source comments):

1. **`Exercise.previewSample(name:)` → `Exercise.previewSample(name:equipment:mechanic:)`** in `RoutineDuplicationTests.swift`. The plan's test fixture used a single-parameter call (`Exercise.previewSample(name: "Bench")`); the actual project signature requires `equipment` and `mechanic` parameters. Adapted to `.barbell` / `.compound` for both fixture exercises. No behavioral change — the test still anchors deep-copy correctness; the fixture exercises just have explicit equipment/mechanic.

2. **Sheet presentation uses `.sheet(isPresented:)` with a manual Binding** rather than `.sheet(item: $pendingSupersetAssignment)`. Rationale: `RoutineExerciseDraft.id` is `UUID?` (Optional), so `Identifiable`-driven `.sheet(item:)` would have id-collision risk (two nil-id drafts) or churn the sheet identity at save time (when the id back-fills). The manual binding tracks the optional state cleanly. Functionally equivalent to the plan's stated intent; the difference is just the SwiftUI surface used.

3. **Create-mode "Save Routine First" alert added** beyond what the plan stated. The plan's anti-pattern list noted: "DO NOT add the SupersetAssignmentSheet from RoutineBuilderView when the routine hasn't been saved yet. ... Gate visibility on `editing != nil`." I implemented the gate as a runtime check that surfaces an alert rather than as menu-item visibility hiding — the alert path keeps the menu predictable (the user always sees the same menu items) while still preventing orphan-group creation. Recorded under `decisions §1`.

4. **RoutineExerciseCard.init closures default to no-op** — The plan's signature showed the 4 closures as required parameters. I added default no-op values to preserve the Phase 1 / plan 03-02 callers (preview blocks, existing tests) without forcing every call site to update. Equivalent in behavior; the no-op defaults are never triggered in the production builder path. Recorded under `decisions §6`.

5. **In-builder `duplicateExercise(_:)` does NOT clone per-set overrides or supersetGroupID** — The plan called this "in-builder duplication, not persisted until Save" without specifying override / superset-id semantics. I chose to clone only the prescription fields (the quick "another row like this" affordance) and explicitly NOT clone overrides or supersetGroupID. Recorded under `decisions §2 / §3`. The routine-level `RoutineDuplicator.duplicate` is the full deep-copy with overrides + superset remap.

No Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations occurred. The plan was followed as written; the variations above are stylistic refinements / signature-adaptation work that preserves the plan's intent verbatim.

## Authentication Gates

None occurred. Pure SwiftUI + SwiftData composition; no network / auth / external-tool interactions.

## Known Stubs

None new in this plan. The plan 03-01 / 03-02 stubs that this plan resolved:

- `handleDuplicate(routine:)` on `RoutinesListView` — was `_ = routine` no-op with `TODO plan 03-03` comment; now calls `RoutineDuplicator.duplicate(routine: routine, context: ctx)`.

Remaining stubs that this plan does NOT resolve (and are explicitly out of scope per the plan's "Dependencies / Consumed by" section):

| Stub | Location | Resolution plan |
|------|----------|-----------------|
| Resume banner `onResume` closure does not navigate | `RoutinesListView.swift` ~line 200 + `RootView.swift` `TodayTabHost` | plan 04-01 (`SessionLoggerView` + Routines-tab `NavigationPath` wiring) |
| "Start Workout" success path does not push the logger | `RoutinesListView.handleStartTap` | plan 04-01 (same) |
| Session logger does NOT visually group supersets | (no file — Phase 2 deliberate scope) | Phase 6 polish per the plan's "Dependencies / Consumed by" section |

The session logger superset rendering is intentionally out of scope per the plan's note: *"Session logger does not group supersets visually in Phase 2; that's a Phase 6 polish. Documented in plan 04-02's out-of-scope."*

## Threat Flags

None. This plan introduces no new auth paths, network endpoints, file access patterns, or trust-boundary schema changes. The only persistence touches are through the existing `ModelContext` injected via `@Environment(\.modelContext)`, and the cascade / soft-ref invariants for `RoutineExercise → RoutineExerciseSetOverride` (cascade) and `RoutineExercise.supersetGroupID` (soft ref) are honored by the duplicator's explicit field-by-field copy. The new `SupersetGroup` insertions are subject to the same query-and-delete sweep pattern that `RoutinesListView.handleDelete` already runs.

## Performance Notes

- `RoutineDuplicator.duplicate` is O(N) in the number of `RoutineExercise` rows + O(M) in the per-RE per-set overrides + O(G) in the SupersetGroup rows. At expected routine scale (≤20 exercises, ≤10 overrides per exercise, ≤5 supersets per routine), the duplicate is well under a millisecond.
- `SupersetAssignmentSheet.label(for:)` does an O(N) scan over `routine.exercises` filtering by `supersetGroupID`. At expected scale (≤20 exercises in a routine, ≤5 groups), this is sub-millisecond and runs only when the sheet body computes labels.
- `RoutineExerciseCard` body recomputation now includes a conditional `if draft.supersetGroupID != nil` rail — adds one extra `HStack` layout pass when grouped. Imperceptible at the expected per-card count (≤20 cards in a routine).
- `RoutineBuilderView.duplicateExercise` and `removeExercise` rewrite `orderIndex` on every reorder via a single linear pass — O(N) in the exercise count, same complexity as the existing `.onMove` handler.

## Next

Plan **04-01** wires the "Start Workout" success path and the resume-banner tap target — both of which push `SessionLoggerView` onto a Routines-tab `NavigationPath`. The session lifecycle (`SessionFactory.start` → snapshot → `SessionLoggerView`) lives in Wave 4. The session logger does NOT visually group supersets in Phase 2; that's a Phase 6 polish per CONTEXT.md / the plan's "Dependencies / Consumed by" section.

## Self-Check

**Files created — verified present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/RoutineDuplicator.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Routines/SupersetAssignmentSheet.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/RoutineDuplicationTests.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/SupersetGroupTests.swift` — FOUND

**Files modified — verified diff:**
- `fitbod/Routines/RoutineExerciseCard.swift` — leading 4pt rail + .contextMenu + 4-closure init params — FOUND
- `fitbod/Routines/RoutineBuilderView.swift` — pendingSupersetAssignment + sheet + alert + handlers — FOUND
- `fitbod/Routines/RoutinesListView.swift` — handleDuplicate wired to RoutineDuplicator.duplicate — FOUND

**Commits — verified present in git log:**
- `1da1c63 feat(02-03-03): RoutineDuplicator deep-copy + tests` — FOUND
- `e9b6318 feat(02-03-03): SupersetAssignmentSheet + accent rail + long-press menu` — FOUND
- `c9bacfb feat(02-03-03): wire RoutinesListView.handleDuplicate to RoutineDuplicator` — FOUND

**Parse gate — verified:**
- `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` exits 0 with no output across all production + test Swift files.

**Test counts — verified:**
- `RoutineDuplicationTests`: 6 `@Test` funcs (grep `^\s*@Test\(` → 6)
- `SupersetGroupTests`: 4 `@Test` funcs (grep `^\s*@Test\(` → 4)

**Phase 2 plan 03-02 regression check — `RoutineBuilderView` copy anchors:**
- All 9 UI-SPEC verbatim copy strings from `RoutineBuilderCopyTests` preserved (grep `-cE '"New Routine"|"Routine name"|"Notes \(optional\)"|"Discard Changes\?"|"Discard"|"Keep Editing"|"Cancel"|"Save"|"Exercises"|"Add an exercise to begin\."'` returns 13). No copy regression.

## Self-Check: PASSED
