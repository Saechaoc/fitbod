---
phase: quick-260528-gr0
plan: 01
subsystem: Periodization / BlockBuilderView
tags: [new-block, sheets, swiftui, refactor]
decisions:
  - Replace inline steppers with tappable read-only cells opening editor sheets
  - metricsHeight grown 74 → 92 to accommodate micro hint lines without clipping
  - New sheets implemented inline as fileprivate structs (token + StepperButton access, consistent with NewBlockTemplateSheet pattern)
  - Days picker built as BRU-styled 1-7 bordered cell row (not default segmented Picker)
key_files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/BlockBuilderViewCopyTests.swift
---

# Phase quick-260528-gr0 Plan 01: New Block Value Editor Sheets Summary

**One-liner:** Replaced NewBlockMetricsBand stepper closures with tappable read-only cells (TAP TO EDIT PHASES / TAP TO EDIT) opening two new BRU-styled editor sheets, and trimmed the redundant APPLY PRESET button from the phases header.

## Files Changed

| File | Change |
|------|--------|
| `fitbod/Periodization/BlockBuilderView.swift` | Main production change — new sheet structs, restructured metrics band, trimmed phases header, wiring, cleanup |
| `fitbodTests/BlockBuilderViewCopyTests.swift` | Deleted obsolete `"APPLY PRESET"` assertion (line 33); `"Apply Preset?"` dialog assertion kept |

## New Sheet Structs Added

### `NewBlockDurationSheet` (fileprivate)
- NavigationStack, paper background, `presentationDetents([.medium])`
- Title "Edit Block Duration" + live total readout recomputing from `draft.totalWeeks`
- ScrollView with one row per phase: `ForEach` keyed by `draftID`, `[−] N [+]` using `NewBlockStepperButton`, decrement clamped to `max(1, weeks - 1)`
- "Done" button calls `dismiss()`

### `NewBlockDaysSheet` (fileprivate)
- NavigationStack, paper background, `presentationDetents([.medium])`
- BRU-styled 1-7 selector: HStack of 7 bordered cells matching `NewBlockPresetChip` idiom (selected = ink fill + paper text)
- Binds `draft.daysPerWeek` directly; "Recommended: 3-6" hint shown only inside the sheet
- "Done" button calls `dismiss()`

## metricsHeight Value

`NewBlockScreenTokens.metricsHeight` set to **92** (was 74). The added micro hint line ("TAP TO EDIT PHASES" / "TAP TO EDIT") under each value requires ~18pt of additional vertical space.

## Commit

`afa03ba66719d7379894a6ab329e3917d4ca30f0`

## Build Result

**BUILD SUCCEEDED** — simulator: iPhone 17 (iOS Simulator)

## Per-Suite Pass Counts

| Suite | Tests | Result |
|-------|-------|--------|
| NewBlockBuilderFidelityTests | 5/5 | PASSED |
| BlockBuilderViewActivationTests | 3/3 | PASSED |
| BlockBuilderViewCopyTests | 1/1 | PASSED |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `fitbod/Periodization/BlockBuilderView.swift` — exists, contains `NewBlockDurationSheet`, `NewBlockDaysSheet`, `onEditWeeks`, `onEditDays`, all required anchors
- `fitbodTests/BlockBuilderViewCopyTests.swift` — `"APPLY PRESET"` assertion removed, `"Apply Preset?"` kept
- Commit `afa03ba` confirmed in git log
- BUILD SUCCEEDED on iPhone 17 simulator
- All 9 unique test cases passed (5 + 3 + 1)
