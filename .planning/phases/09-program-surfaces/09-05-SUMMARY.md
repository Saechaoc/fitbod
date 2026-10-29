---
phase: 09-program-surfaces
plan: "05"
subsystem: periodization-ui
tags: [swiftui, swiftdata, block-draft, block-builder, bru, copy-tests, split-band]
dependency_graph:
  requires:
    - fitbod/Periodization/BlockDraft.swift
    - fitbod/Periodization/TrainingDaysWriter.swift
    - fitbod/Models/Block.swift
    - fitbod/Models/Split.swift
    - fitbod/Models/Enums/SchedulingMode.swift
    - fitbod/Periodization/BlockOverviewScreen.swift   # ModeChip/DayToggleChip reference
  provides:
    - fitbod/Periodization/BlockDraft.swift            # split/schedulingMode/trainingDays fields + fixed save
    - fitbod/Periodization/BlockBuilderView.swift      # NewBlockSplitBand + NewBlockSplitPickerSheet
    - fitbodTests/BlockBuilderViewCopyTests.swift      # updated copy pins
    - fitbodTests/BlockDraftSaveTests.swift            # 4 new behavior tests + 1 fixed assertion
  affects:
    - Any consumer of BlockDraft.save (builder save path now omits endDate)
    - BlockBuilderView call sites (split band always shown, no isValid guard)
tech_stack:
  added: []
  patterns:
    - "Direct split write in BlockDraft.save (pre-activation builder context); trainingDays via TrainingDaysWriter.sort (T-09-14)"
    - "endDate NOT written by builder — completion freeze marker owned exclusively by BlockLifecycleService.end (T-09-13)"
    - "NewBlockModeChip + NewBlockDayToggleChip copy-adapted from BlockOverviewScreen using NewBlockScreenTokens (separate token worlds per 09-RESEARCH Pattern 3)"
    - "NewBlockSplitPickerSheet: @Query filter !isArchived + NavigationStack title; direct draft.split mutation"
key_files:
  created: []
  modified:
    - fitbod/Periodization/BlockDraft.swift
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/BlockBuilderViewCopyTests.swift
    - fitbodTests/BlockDraftSaveTests.swift
decisions:
  - "endDate write removed from BlockDraft.save — freeze marker set only by BlockLifecycleService.end; computedEndDate accessor preserved for display-only projection"
  - "Split written directly in BlockDraft transaction (builder is pre-activation, not BlockLifecycleService.attachSplit which guards post-activation mutations)"
  - "NewBlockLinkedRoutinesBand renamed to NewBlockSplitBand (not in the 9-struct pinned list; renaming is safe)"
  - "Split band always visible (no isValid guard); saves-as-draft expressed via copy not gating"
  - "NewBlockModeChip/DayToggleChip copy-adapted inline in BlockBuilderView.swift (not extracted to shared — token worlds differ)"
  - "Existing BlockDraftSaveTests endDate assertion updated: endDate == nil replaces old computedEndDate comparison"
metrics:
  duration_seconds: 660
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_created: 0
  files_modified: 4
---

# Phase 9 Plan 05: BlockDraft Split Fields + Split Band Summary

**One-liner:** Extended BlockDraft with split/schedulingMode/trainingDays fields and fixed the endDate-as-completed bug; replaced NewBlockLinkedRoutinesBand with the full split band (routine picker + mode chips + day-chips) in BlockBuilderView; all 3 copy-guardrail suites green.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend BlockDraft (split/mode/days fields + save path) and fix endDate-as-completed bug | 79abeec | BlockDraft.swift, BlockDraftSaveTests.swift |
| 2 | Replace NewBlockLinkedRoutinesBand with split band; update co-located copy test; run all 3 guardrail suites | 8d441aa | BlockBuilderView.swift, BlockBuilderViewCopyTests.swift |

---

## What Was Built

### BlockDraft.swift (extended)

**New fields:**
- `public var split: Split? = nil` — V7 routine reference for the builder
- `public var schedulingMode: SchedulingMode = .rotation` — persisted scheduling mode
- `public var trainingDays: [Int] = []` — training weekdays (written sorted at save)

**`convenience init(block:)` updated:** Round-trips all three V7 fields from an existing block so editing a block pre-populates the split band correctly.

**`save(into:)` fix (T-09-13):** Removed the unconditional `block.endDate = computedEndDate` write. The `endDate` field is the completion freeze marker (spec §3/§4) — it must be written ONLY by `BlockLifecycleService.end`. The builder operates in a pre-activation context (draft/ready) so `endDate` must remain nil post-save. The `computedEndDate` computed property is preserved for display-only projection but is no longer persisted by the builder.

**New field writes in transaction:**
- `block.split = split` (direct — builder is pre-activation; `BlockLifecycleService.attachSplit` is for post-activation)
- `block.schedulingMode = schedulingMode`
- `block.trainingDays = TrainingDaysWriter.sort(weekdays: trainingDays)` (T-09-14 compliance)

### BlockBuilderView.swift (surgically edited)

**Split band replacement (3 changes):**

1. **Call-site**: Removed `if draft.isValid { NewBlockLinkedRoutinesBand(...) }` guard. Split band is now unconditional — optionality expressed via "None — saves as draft" copy. New call: `NewBlockSplitBand(draft: draft, presentSplitPicker: { presentingSplitPicker = true })`.

2. **`NewBlockSplitBand` struct** (renamed from `NewBlockLinkedRoutinesBand` — NOT in the 9-struct pinned list):
   - "Routine" section head (NewBlockType.chrome, muted)
   - Ink divider (2pt heavyRule)
   - Split picker row: "Routine" label + if split attached: name + "SWAP ▸" signal button; else: "None — saves as draft" muted + "+ ATTACH ▸" signal button
   - Hair divider
   - Scheduling row: "Scheduling" label + `NewBlockModeChip` pair ("ROTATION" / "FIXED WEEKLY")
   - Day-chip row (fixedWeekly only): 7 `NewBlockDayToggleChip` views (M T W T F S S), amber mismatch hint when `trainingDays.count != slotCount`
   - Ink divider (bottom)
   - All tokens: `NewBlockScreenTokens.*` / `NewBlockType.*` (NOT `Color.bru*`)

3. **`NewBlockSplitPickerSheet`**: `@Query` filter `!isArchived`, sorted by name; NavigationStack title "Choose Routine"; tap selects + dismisses; `.presentationDetents([.medium, .large])`.

**`NewBlockModeChip` + `NewBlockDayToggleChip`**: Fileprivate structs copy-adapted from `BlockOverviewScreen` (identical visual logic, NewBlockScreenTokens substituted for Color.bru* — separate token worlds).

### BlockBuilderViewCopyTests.swift (updated)

- **Removed** pin: `#expect(builder.contains("\"ROUTINES · \\(count) LINKED\""))`
- **Added** 7 new pins for split band copy:
  - `"Routine"`, `"Scheduling"`, `"None — saves as draft"`, `"ROTATION"`, `"FIXED WEEKLY"`, `"+ ATTACH ▸"`, `"SWAP ▸"`
- All other existing pins (NEW BLOCK, BLOCK NAME, PHASES, etc.) untouched

### BlockDraftSaveTests.swift (updated + extended)

- **Fixed** existing test "saving draft persists block and ordered phases": changed `block.endDate == computedEndDate` expectation to `block.endDate == nil` (endDate no longer written by builder)
- **Added 4 new behavior tests:**
  - `savedDraftWithoutSplitIsDraftAndHasNoEndDate`: draft save → `.draft` + endDate nil (T-09-13)
  - `savedDraftWithSplitAndRotationIsReady`: split attached → `.ready` + endDate nil (T-09-13)
  - `trainingDaysArePersistedSorted`: unsorted days written → stored sorted via TrainingDaysWriter (T-09-14)
  - `initFromBlockRoundTripsSchedulingFields`: init(block:) round-trips split/schedulingMode/trainingDays

---

## Deviations from Plan

### Auto-fixed Issues

**[Rule 1 - Bug] Existing BlockDraftSaveTests endDate assertion**
- **Found during:** Task 1 test run
- **Issue:** Existing test "saving draft persists block and ordered phases" asserted `block.endDate == startDate.addingTimeInterval(Double(8 * 7) * 86_400)` — this relied on the old unconditional endDate write. Removing that write made the test fail.
- **Fix:** Updated the assertion to `block.endDate == nil` (correct per spec §3/§4 and T-09-13).
- **Files modified:** fitbodTests/BlockDraftSaveTests.swift
- **Commit:** 79abeec (included in Task 1)

---

## Known Stubs

None — split band is fully wired to BlockDraft fields. The split picker sheet lists all non-archived splits and writes `draft.split` directly (persisted by `BlockDraft.save`'s direct split write added in Task 1).

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes. All mutations are local SwiftData writes.

Threat mitigations confirmed:
- **T-09-13**: `block.endDate = computedEndDate` removed from `BlockDraft.save`. Behavior test `savedDraftWithoutSplitIsDraftAndHasNoEndDate` + `savedDraftWithSplitAndRotationIsReady` both assert `endDate == nil` and `derivedStatus != .completed`.
- **T-09-14**: `block.trainingDays = TrainingDaysWriter.sort(weekdays: trainingDays)` — single sort-at-write call site. Behavior test `trainingDaysArePersistedSorted` pins this.
- **T-09-15**: The 9 pinned NewBlock* struct names are untouched. `NewBlockLinkedRoutinesBand` is renamed to `NewBlockSplitBand` (not in the pinned list). `NewBlockBuilderFidelityTests` passes confirming all 9 names present.

---

## Self-Check: PASSED

- [x] `fitbod/Periodization/BlockDraft.swift` exists (extended, 3 new fields, fixed save)
- [x] `fitbod/Periodization/BlockBuilderView.swift` exists (NewBlockSplitBand + NewBlockSplitPickerSheet)
- [x] `fitbodTests/BlockBuilderViewCopyTests.swift` exists (updated pins)
- [x] `fitbodTests/BlockDraftSaveTests.swift` exists (fixed + 4 new tests)
- [x] Commit 79abeec exists (Task 1)
- [x] Commit 8d441aa exists (Task 2)
- [x] Build: SUCCEEDED (iPhone 17 Pro)
- [x] BlockDraftSave tests: ALL PASSED (8 tests including 4 new behavior tests)
- [x] BlockBuilderViewCopyTests: PASSED
- [x] NewBlockBuilderFidelityTests: PASSED (all 6 tests — 9 pinned struct names intact)
- [x] ProgramViewFidelityTests: PASSED
