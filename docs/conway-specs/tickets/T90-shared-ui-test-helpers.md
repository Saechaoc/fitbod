---
id: T90
title: UI tests share one set of helpers
phase: 1
items: []
depends_on: []
size: M
sim: both
owns: [fitbodUITests/UITestNavigation.swift, fitbodUITests/UITestHelpersSelfTests.swift, fitbodUITests/BlockLifecycleEntryPointsUITests.swift, fitbodUITests/BlockReviewAfterEndUITests.swift, fitbodUITests/AddPhaseSheetUITests.swift, fitbodUITests/BlockTemplateCatalogUITests.swift, fitbodUITests/NewBlockSavesUITests.swift, fitbodUITests/CustomExerciseEntryUITests.swift, fitbodUITests/BlockBuilderBackLabelUITests.swift, fitbodUITests/ProgramDarkModeUITests.swift, fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/PlateInventorySwipeUITests.swift, fitbodUITests/StripeAndBleedUITests.swift, fitbodUITests/ProgressChartFitUITests.swift, fitbodUITests/ProgramHeaderAndSheetsAX3UITests.swift, fitbodUITests/PRListAndSeriesUITests.swift]
---

# T90: UI tests share one set of helpers

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The coordinator's reviews of T63 to T77 found the same private helpers copied across UI test files.

- `hittable(_:_:)` is in 9 files, and `revealAboveBottomBar`, `type(_:into:)` and `waitUntilStill` are in 4 each.
- The Vision text reader `readText(in:of:)` is in `ProgressChartFitUITests` and `ProgramHeaderAndSheetsAX3UITests`, each with its own screenshot crop and pixel reader.
- `PRListAndSeriesUITests` has a private `LargerTextSize` and `saveScreenshot(_:_:size:)`, which repeat `UITestNavigation.TextSize` and its screenshot names.
- `PlateInventorySwipeUITests.waitForAbsence` repeats XCTest's own `waitForNonExistence(timeout:)`.

A fix to how any of them waits or picks a match has to be made in every copy, and each new test copies them again.

## Target

- `fitbodUITests/UITestNavigation.swift`, and every private copy in the other files in `owns`.

## Change

1. `UITestNavigation` gets one shared `hittable`, `revealAboveBottomBar`, `type(_:into:)`, `waitUntilStill`, `readText(in:of:)` and screenshot pixel reader.
   Every copy calls the shared one, and the private copies are deleted.
   Where copies differ, as in a timeout or a match rule, the shared helper takes a parameter whose default keeps each caller's behavior.
2. `UITestNavigation.TextSize` gets `xl`, `xxl` and `xxxl`, and `saveScreenshot` names them; `PRListAndSeriesUITests` uses them and drops its private enum and screenshot helper.
3. `waitForAbsence`'s callers use `waitForNonExistence(timeout:)`.
4. No test changes what it checks, its name or its screenshot names, and no app code changes.

## Constraints

- Change test code only.
- Leave `topSheet`, the stepper helpers and number entry as they are; T39 changes those.

## Ownership

You may edit the files in `owns`.
If another UI test file has gained a copy by the time you start, ask before you edit it.
Ask before you edit anything else.

## Repro first

This ticket changes no behavior, so it has no failing repro.
Before changing anything, run every suite in `owns` on the phones listed below, save the counts as the baseline in `repro-fail.txt`, and say in `notes.md` that the ticket has no failing repro.
In `fitbodUITests/UITestHelpersSelfTests.swift`, add checks for the new `TextSize` cases' launch arguments and screenshot names.

## Observable acceptance

- Every suite in `owns` passes on the small phone with the baseline's test count, and `StripeAndBleedUITests` and `PRListAndSeriesUITests` also pass on the large phone.
- `rg "private func (hittable|revealAboveBottomBar|type|waitUntilStill|readText|waitForAbsence)\(" fitbodUITests` finds nothing, and `LargerTextSize` is gone.
- The screenshot names these suites save are the same before and after.

## Hints

- `saveScreenshot` and `phoneName` are near lines 172 to 193 of `UITestNavigation.swift`, and `color(at:in:)` near line 325.
- `TextSize` is near line 21.
