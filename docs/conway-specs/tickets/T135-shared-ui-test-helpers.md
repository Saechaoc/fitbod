---
id: T135
title: UI suites share one copy of their helpers, and the swipe-back suite finds rows by name and fits its budgets
phase: 4
items: []
depends_on: [T106]
size: M
sim: small
owns: [new:fitbodUITests/SharedScreenHelpers.swift, fitbodUITests/CopySweepUITests.swift, fitbodUITests/WeeklyRecapUITests.swift, fitbodUITests/SwipeBackUITests.swift, fitbodUITests/TodayPolishUITests.swift, fitbodUITests/NewRoutineFlowUITests.swift, fitbodUITests/PlateScreensFitUITests.swift, fitbodUITests/PlateCalculatorSheetBRUUITests.swift, fitbodUITests/LibraryPolishUITests.swift, fitbodUITests/ProgramDarkModeUITests.swift, fitbodUITests/ExerciseHistoryRowsUITests.swift, fitbodUITests/SmallFixesUITests.swift, fitbodUITests/BlockOverviewAndRoutineAX3UITests.swift, fitbodUITests/BlockAndRoutineTextFitUITests.swift, fitbodUITests/BlockOverviewStatesUITests.swift]
---

# T135: UI suites share one copy of their helpers, and the swipe-back suite finds rows by name and fits its budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These items moved here from T123, which kept its notification and journey-suite items, and gained finding F316 from T106's review.

- Several UI suites keep private copies of the same helpers, so a change to one must be made in every copy:
  - `CopySweepUITests` copies `openToday(afterSeeding:)`, `open(_:in:)`, `waitUntilHittable` and `button(beginningWith:)` from `WeeklyRecapUITests` and `SwipeBackUITests` (finding F280, from T34's review).
  - `TodayPolishUITests` and `NewRoutineFlowUITests` each keep a `pixelCount` (finding F283, from T35's review).
  - `PlateCalculatorSheetBRUUITests.drawnHeight(of:)` and `PlateScreensFitUITests.column(atX:from:to:in:)` with `isInk` each implement the same ink-column reader (finding F288, from T107's review).
  - `LibraryPolishUITests` copies `TextContrast`, `tapWhenReady` and `tabBarTop` from `ProgramDarkModeUITests` and `ExerciseHistoryRowsUITests` (finding F291, from T37's review), and `SmallFixesUITests` holds a third `TextContrast` (finding F303, from T38's review).
  - `BlockOverviewAndRoutineAX3UITests`, `BlockAndRoutineTextFitUITests` and `BlockOverviewStatesUITests` each keep `openRoutine`, `openBlock`, `routinePageTop`, `blockPageTop` and `dragPage` (finding F309, from T108's review).
- `SwipeBackUITests.testVolumeTargetsSwipeBackToSettings` looks for `button(beginningWith: "Chest")`, which also matches Today's volume row and heatmap block under the Settings sheet.
  Its `waitUntilGone` comment blames Volume Targets' rows for lingering, but T38 found that Volume Targets' own row leaves within 1.5 s (finding F301).
- `SwipeBackUITests.testSidewaysDragOnARecordRowOpensNothing` and `testSidewaysDragOnALibraryRowOpensNothing` pick a row by its index, which XCUITest resolves again after the scroll, so a lazy list that drops rows above could make the check compare two different rows (finding F316).
- In the coordinator's run on `5f224ff`, five `SwipeBackUITests` cases ran over the 30 s case budget: `testSwipeOnARootScreenDoesNothing` 83.7 s, `testArchivedRoutinesSwipeBackToProgram` 43.3 s, `testExerciseHistoryAndItsChartOpenOnLibrarysStack` 37.9 s, `testSessionFromTodaySwipesBackToToday` 35.1 s and `testHistoryChartSwipesBackToHistory` 31.4 s (finding F323).

## Target

- The helpers named in Problem, the two `SwipeBackUITests` lookups and its five slow cases.

## Change

1. The helpers named in Problem live once, in `fitbodUITests/SharedScreenHelpers.swift`, and every suite named there uses that one copy.
2. `testVolumeTargetsSwipeBackToSettings` finds Volume Targets' own first row by its identifier or its whole label, and the comment above `waitUntilGone` says why the old lookup was slow.
3. The two sideways-drag tests read their row's label before the drag and find the row again by that label.
4. The five `SwipeBackUITests` cases named in Problem fit the 30 s case budget with the same assertions; where one cannot, `notes.md` says what its time is spent on.

## Constraints

- Every test keeps its assertions; only where its helpers live and how it finds rows change.
- Keep `UITestNavigation`'s helpers where they are; `SharedScreenHelpers.swift` holds only helpers that suites copy today.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else, such as `UITestNavigation.swift`.

## Repro first

- List each copied helper with the files that hold it in `notes.md`, as the "before" state.
- Run every suite named in Problem once on the small phone, and record each suite's duration.

## Observable acceptance

- Every suite named in Problem passes on the small phone, with durations before and after in `notes.md`.
- No helper named in Problem exists in more than one file.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T106's `ponytail-review.md`, in the main checkout's `docs/conway-specs/evidence/T106/`, describes the index-based lookups.
