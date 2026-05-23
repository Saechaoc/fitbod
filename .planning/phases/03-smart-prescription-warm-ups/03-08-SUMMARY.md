---
phase: 03-smart-prescription-warm-ups
plan: "08"
subsystem: session-integration
tags: [integration, session-factory, session-logger, prescription, warmup, plate-stack, tdd, red-to-green]
dependency_graph:
  requires: [03-01, 03-02, 03-03, 03-04, 03-05, 03-06, 03-07]
  provides:
    - SessionFactory Phase 3 integration (prescription + warmup)
    - SessionExerciseCard BumpBanner + CalibratingBadge + WarmupRampRows wiring
    - SetRow PrescriptionWeightCell (with range) + PlateStackDisclosure wiring
  affects:
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/Sessions/SessionExerciseCard.swift
    - fitbod/Sessions/SetRow.swift
    - fitbod/Sessions/PlateStackDisclosure.swift (bug fix)
    - fitbodTests/SessionFactoryPhase3Tests.swift
    - fitbodTests/ManualOverrideTests.swift
tech_stack:
  added: []
  patterns:
    - "SessionFactory: ProgressionStrategyFactory.make per RoutineExercise (Block A) + WarmupRamp.shouldGenerate/generate for first compound (Block B)"
    - "SessionFactory: warmupGenerated var outside loop — single-ramp-per-session invariant"
    - "SessionFactory: internal static helpers (fetchHistoryPoints, lastSessionWorkingReps, plateInventory, equipmentKind) — reusable by SessionExerciseCard"
    - "SessionFactory: broad #Predicate + Swift post-filter to avoid type-checking timeout on multi-level optional keypaths"
    - "SessionExerciseCard: currentExplanation() pure-recompute helper at body level — avoids @State cache staleness"
    - "SessionExerciseCard: explanation let-binding computed once in body; shared by Section content + header closures"
    - "SetRow: range: explanation?.range at PrescriptionWeightCell call site — CONTEXT.md Area 1 key wiring"
    - "SetRow: expandedPlateSetID: Binding<UUID?> single-disclosure-at-a-time coordination"
key_files:
  created: []
  modified:
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/Sessions/SessionExerciseCard.swift
    - fitbod/Sessions/SetRow.swift
    - fitbod/Sessions/PlateStackDisclosure.swift
    - fitbodTests/SessionFactoryPhase3Tests.swift
    - fitbodTests/ManualOverrideTests.swift
decisions:
  - "currentExplanation() placed as a call at the top of body (not a computed property) so the let-bound result is accessible in both Section content and Section header closures — SwiftUI body is a ViewBuilder and computed properties cannot be forward-referenced inside ViewBuilder result"
  - "fetchHistoryPoints uses broad predicate + Swift post-filter (not a deeply nested #Predicate) to avoid Swift 6 type-checking timeout on multi-level optional chaining (entry.sessionExercise?.exercise?.id)"
  - "lastSessionWorkingReps likewise simplified: fetches by intentRaw only + post-filters by exerciseID in Swift"
  - "PlateStackDisclosure.plateWidth label mismatch fixed inline (pre-existing bug from plan 03-06 blocking Task 1 build)"
  - "SetRow working-set orderIndices shifted by warmupSetCount so warm-up rows occupy 0..N-1 and working sets start at N"
  - "handleSkipWarmups marks isComplete=true (not ctx.delete) so warm-up history is preserved while WarmupRampRows stops rendering them"
metrics:
  duration_minutes: 45
  completed: "2026-05-23T02:30:00Z"
  tasks_completed: 2
  tasks_total: 3
  files_created: 0
  files_modified: 6
  tests_green: 9
requirements: [PRES-01, PRES-02, PRES-07, PRES-10, WARM-01, WARM-02]
---

# Phase 3 Plan 08: Integration Wave Summary

**One-liner:** SessionFactory invokes ProgressionStrategyFactory + WarmupRamp at session start; SessionExerciseCard + SetRow wire all Phase 3 UI components; 9 RED tests turned GREEN.

## What Was Built

### Task 1 — SessionFactory Phase 3 integration (`774fb3f`)

Three new private-static helpers and two new inline blocks in `SessionFactory.start(...)`:

**Block A (Prescription):** For each `RoutineExercise`, fetches plate inventory, history points, last-session reps array, and prior matching-intent scalars, then calls `ProgressionStrategyFactory.make(for: re.progressionKind).prescribe(...)`. Stores the result as `se.prescribedWeight`.

**Block B (Warmup):** After Block A, checks `WarmupRamp.shouldGenerate(for: se, ...)`. If true (and `!warmupGenerated`), calls `WarmupRamp.generate(...)`, inserts the returned `SetEntry` rows, shifts working-set `orderIndex` values up by `warmupSets.count`, and sets `warmupGenerated = true`. Resets `warmupOverride.skipNextSession` after consumption.

**Internal-static helpers** (accessible by `SessionExerciseCard.currentExplanation()`):
- `fetchHistoryPoints(exerciseID:intentRaw:context:) -> [HistoryPoint]` — 50-point cap; RESEARCH §Pitfall 7 nil-RPE filter; broad predicate + Swift post-filter to avoid type-checking timeout
- `lastSessionWorkingReps(exerciseID:intentRaw:context:) -> [Int]` — per-intent reps array for DoubleProgression bump trigger
- `plateInventory(for:context:) -> PlateInventory` — fetches existing or constructs transient default (not inserted)
- `equipmentKind(for:) -> PlateEquipmentKind` — Equipment → PlateEquipmentKind mapping

### Task 2 — SessionExerciseCard + SetRow UI wiring (`6c8cd18`)

**SessionExerciseCard additions:**
- `@State private var bannerDismissed: Bool = false` and `@State private var expandedPlateSetID: UUID? = nil`
- `@Query private var settingsList: [UserSettings]` and `@Query private var inventories: [PlateInventory]` for live recompute
- `currentExplanation() -> PrescriptionExplanation?` helper — calls SessionFactory's internal-static helpers using `@Environment(\.modelContext)`; returns the full explanation including `.range` for calibrating-with-prior-data state
- `BumpBanner` conditional above column-header (bumpOccurred + !bannerDismissed guard)
- `WarmupRampRows` conditional when `warmupEntries` is non-empty; `handleSkipWarmups()` marks them complete
- `CalibratingBadge` inline in section header when `.calibrating` status
- `.onTapGesture { bannerDismissed = true }` on outer Section for tap-anywhere dismiss
- Passes `explanation:`, `prescribed:`, `expandedPlateSetID:` to each `SetRow` in `ForEach`

**SetRow additions:**
- Weight `TextField` replaced by `PrescriptionWeightCell(weight:prescribed:range:explanation:wasManualOverride:isComplete:onTapEmptyCell:)`
- **Critical wiring:** `range: explanation?.range` at the call site — delivers CONTEXT.md Area 1's "{low} – {high} kg" read-only display when calibrating with prior data
- `PlateStackDisclosure` as conditional `VStack` child below main `HStack`
- `.onTapGesture { togglePlateDisclosure(); onTapEmptyCell() }` on weight cell area
- `@Binding var expandedPlateSetID: UUID?` for single-disclosure-at-a-time coordination
- `@Query private var inventories: [PlateInventory]` for plate stack math

### Bug Fix — PlateStackDisclosure.plateWidth label mismatch `[Rule 1 - Bug]`

Pre-existing from plan 03-06: `plateWidth(weight: weight)` called a function declared `plateWidth(_ weight: Double)`, causing extraneous-label build error that blocked Task 1. Fixed inline.

## Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| SessionFactoryPhase3Tests | 5 | GREEN (was RED) |
| ManualOverrideTests | 4 | GREEN (was RED) |
| SessionFactoryTests (Phase 2 regression) | 9 | GREEN (no regression) |

**Total newly-passing tests: 9**

### SessionFactoryPhase3Tests (5/5 GREEN)
- `prescribedWeightSetOnSessionExercise` — PRES-01: non-nil prescribedWeight after start()
- `warmupSetEntriesInsertedForFirstQualifyingCompound` — WARM-01: 4 warmup SetEntry rows for barbell compound
- `workingSetsShiftAfterWarmupInsertion` — working set orderIndices >= warmupCount
- `secondQualifyingCompoundDoesNotGetWarmup` — only first qualifying compound receives ramp
- `warmupSkippedWhenWarmupConfigDisabled` — WARM-03: WarmupConfig(enabled: false) suppresses ramp

### ManualOverrideTests (4/4 GREEN)
- `manualOverrideFlagSetWhenWeightDiverges` — model-layer: wasManualOverride=true survives round-trip
- `manualOverrideFlagFalseWhenWeightMatchesPrescription` — stays false when weight matches
- `nextSessionReadsActualNotPrescribed` — PRES-07: fetchHistoryPoints reads SetEntry.weight (actual), not prescribedWeight
- `userSettingsMinCalibrationSetsHonored` — SET-07: minCalibrationSets=20 keeps strategy in .calibrating(15,20) at 15 sets

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 — SessionFactory + tests | `774fb3f` | feat(03-08): SessionFactory Phase 3 integration — strategy + warmup invocation |
| 2 — SessionExerciseCard + SetRow | `6c8cd18` | feat(03-08): SessionExerciseCard + SetRow UI wiring — BumpBanner, CalibratingBadge, WarmupRampRows, PrescriptionWeightCell, PlateStackDisclosure |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing PlateStackDisclosure.plateWidth extraneous argument label**
- **Found during:** Task 1 (first build attempt)
- **Issue:** `plateRect` called `plateWidth(weight: weight)` but the function signature is `plateWidth(_ weight: Double)` (anonymous external label). Swift 6 / Xcode 26 raises this as a build error.
- **Fix:** Changed call site to `plateWidth(weight)` (removed the `weight:` label).
- **Files modified:** `fitbod/Sessions/PlateStackDisclosure.swift`
- **Commit:** `774fb3f`

**2. [Rule 3 - Blocking] #Predicate type-checking timeout on multi-level optional keypath**
- **Found during:** Task 1 (second build attempt)
- **Issue:** The `fetchHistoryPoints` predicate `entry.sessionExercise?.exercise?.id == targetID` caused `the compiler is unable to type-check this expression in reasonable time` on the Swift 6 toolchain.
- **Fix:** Replaced the deep predicate with a broad filter (`isWarmup == false && isComplete == true`) + Swift-level post-filter for `intentRaw` and `exercise?.id`. Also simplified `lastSessionWorkingReps` predicate similarly.
- **Files modified:** `fitbod/Sessions/SessionFactory.swift`
- **Commit:** `774fb3f`

**3. [Rule 3 - Blocking] `explanation` scope error in SessionExerciseCard**
- **Found during:** Task 2 (first build attempt)
- **Issue:** `explanation` was declared as a `let` inside the `Section` content closure but referenced in the `header:` closure — different SwiftUI ViewBuilder scopes.
- **Fix:** Moved the `let explanation = currentExplanation()` call to the top of `body` (before the `Section`) so it's in scope for both the content and header closures.
- **Files modified:** `fitbod/Sessions/SessionExerciseCard.swift`
- **Commit:** `6c8cd18`

## Task 3 Status

Task 3 is a `checkpoint:human-verify` — paused here. The human-verify checkpoint
covers visual + interaction compliance on simulator per the 7-step verification
protocol in 03-08-PLAN.md Task 3.

## Known Stubs

None. All Phase 3 components are fully wired:
- `prescribedWeight` is non-nil on every `SessionExercise` after `start()`
- `range` is passed to `PrescriptionWeightCell` at the call site
- `BumpBanner` / `CalibratingBadge` / `WarmupRampRows` render conditionally based on live data
- `PlateStackDisclosure` shows for the correct `expandedPlateSetID`
- `wasManualOverride` is written by `PrescriptionWeightCell.onChange`

## Threat Flags

None. Changes are confined to session-local UI and SwiftData query helpers. No new network endpoints, no auth paths, no file access. The internal-static helpers on `SessionFactory` are read-only (no `context.insert` or `context.save`).

## Self-Check: PASSED

- FOUND: `fitbod/Sessions/SessionFactory.swift` — contains `ProgressionStrategyFactory.make` (×1), `WarmupRamp.shouldGenerate` (×2), `WarmupRamp.generate` (×2), `fetchHistoryPoints` (×4), `warmupGenerated` (×5)
- FOUND: `fitbod/Sessions/SessionExerciseCard.swift` — contains `BumpBanner(` (×1), `CalibratingBadge(` (×1), `WarmupRampRows(` (×1), `bannerDismissed` (×8)
- FOUND: `fitbod/Sessions/SetRow.swift` — contains `PrescriptionWeightCell(` (×1), `range: explanation?.range` (×2 — comment + call), `PlateStackDisclosure(` (×1), `expandedPlateSetID` (×12)
- FOUND: commit `774fb3f` (Task 1)
- FOUND: commit `6c8cd18` (Task 2)
- All 9 newly-passing tests GREEN; 9 Phase 2 regression tests GREEN
