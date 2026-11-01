---
id: T143
title: The UI suite keeps only the tests that guard the lifter's data
phase: 3
items: []
depends_on: []
size: L
sim: small
owns: [fitbodUITests/ActionPopoverFitUITests.swift, fitbodUITests/AddPhaseSheetUITests.swift, fitbodUITests/ArchiveRoutineUITests.swift, fitbodUITests/BlockAndRoutineTextFitUITests.swift, fitbodUITests/BlockBuilderBackLabelUITests.swift, fitbodUITests/BlockDraftKeepsUITests.swift, fitbodUITests/BlockLifecycleEntryPointsUITests.swift, fitbodUITests/BlockNameTypingUITests.swift, fitbodUITests/BlockOverviewAndRoutineAX3UITests.swift, fitbodUITests/BlockOverviewStatesUITests.swift, fitbodUITests/BlockReviewAfterEndUITests.swift, fitbodUITests/BlockTemplateCatalogUITests.swift, fitbodUITests/BlockWeekCountsUITests.swift, fitbodUITests/BodySilhouetteUITests.swift, fitbodUITests/CalibratingStepCopyUITests.swift, fitbodUITests/CalibratingWeightUITests.swift, fitbodUITests/CopySweepUITests.swift, fitbodUITests/CustomExerciseEditorBRUUITests.swift, fitbodUITests/CustomExerciseEntryUITests.swift, fitbodUITests/DeloadAdvisoryBannerUITests.swift, fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/EmptyWorkoutCountsUITests.swift, fitbodUITests/ExerciseCopyEditSheetUITests.swift, fitbodUITests/ExerciseDisplayNameUITests.swift, fitbodUITests/ExerciseHistoryRowsUITests.swift, fitbodUITests/HeatmapHitAreaUITests.swift, fitbodUITests/HistoryAndTodayUITests.swift, fitbodUITests/LibraryPolishUITests.swift, fitbodUITests/LoggerPlateStackUITests.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, fitbodUITests/MuscleVolumeTargetEditorUITests.swift, fitbodUITests/NewBlockLayoutUITests.swift, fitbodUITests/NewBlockModalUITests.swift, fitbodUITests/NewBlockSavesUITests.swift, fitbodUITests/NewRoutineFlowUITests.swift, fitbodUITests/NoteSheetsUITests.swift, fitbodUITests/PRListAndSeriesUITests.swift, fitbodUITests/PerMuscleDetailUITests.swift, fitbodUITests/PerSetOverridesRemovedUITests.swift, fitbodUITests/Phase5BRUSmokeUITests.swift, fitbodUITests/Phase6/ProgressHomeBRUUITests.swift, fitbodUITests/Phase6/SettingsBRUUITests.swift, fitbodUITests/PhaseRowsVoiceOverUITests.swift, fitbodUITests/PinnedNoteCapsuleTapTargetUITests.swift, fitbodUITests/PinnedNoteSheetBRUUITests.swift, fitbodUITests/PlateCalculatorSheetBRUUITests.swift, fitbodUITests/PlateInventoryNavigationUITests.swift, fitbodUITests/PlateInventorySwipeUITests.swift, fitbodUITests/PlateScreensFitUITests.swift, fitbodUITests/PlateauOverrideUITests.swift, fitbodUITests/PrescriptionEditorUITests.swift, fitbodUITests/PrescriptionWeightCellBRUUITests.swift, fitbodUITests/ProgramDarkModeUITests.swift, fitbodUITests/ProgramEmptyStateAX3UITests.swift, fitbodUITests/ProgramHeaderAndSheetsAX3UITests.swift, fitbodUITests/ProgressChartFitUITests.swift, fitbodUITests/RPEDecimalHoldUITests.swift, fitbodUITests/RampAndStripsAX3UITests.swift, fitbodUITests/ReseedRelaunchUITests.swift, fitbodUITests/RestSheetAndRPEChipsUITests.swift, fitbodUITests/RoutineBuilderBRUUITests.swift, fitbodUITests/SessionComparisonUITests.swift, fitbodUITests/SessionEditorPolishUITests.swift, fitbodUITests/SessionEditorRowsUITests.swift, fitbodUITests/SessionHistoryBRUUITests.swift, fitbodUITests/SessionLoggerBRUUITests.swift, fitbodUITests/SettingsExportUITests.swift, fitbodUITests/SkipWarmupsUITests.swift, fitbodUITests/SmallFixesUITests.swift, fitbodUITests/StallBadgeWindowUITests.swift, fitbodUITests/StripeAndBleedUITests.swift, fitbodUITests/TabBarBleedUITests.swift, fitbodUITests/TodayAX3UITests.swift, fitbodUITests/TodayPolishUITests.swift, fitbodUITests/TodaySheetOrderUITests.swift, fitbodUITests/UITestHelpersSelfTests.swift, fitbodUITests/VolumeBarsUITests.swift, fitbodUITests/WeeklyRecapUITests.swift, fitbodUITests/WeeklyTonnageUITests.swift, fitbodUITests/WhyThisWeightControlUITests.swift, fitbodUITests/WhyThisWeightSheetBRUUITests.swift, fitbodUITests/WorkoutLoggerJourneyUITests.swift, fitbodUITests/WorkoutSwapJourneyUITests.swift, fitbodUITests/fitbodUITests.swift, fitbodUITests/fitbodUITestsLaunchTests.swift]
---

# T143: The UI suite keeps only the tests that guard the lifter's data

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../DEVELOPMENT.md](../../DEVELOPMENT.md) too; this ticket applies its "Scale effort to the change" and "Deferred work" sections.

## Problem

The user asked for this on 2026-11-01: the UI suite has grown until it slows development, and at this stage only the tests that guard data are worth their time.

- At Gate 2 (`dc9f92d`, 2026-10-31) the UI tests took 179.8 of the run's 180 minutes on one phone: 359 cases in 76 suites.
- Eleven suites were added since, and `fitbodUITests` now holds 87 suites.
- Most of the time goes to checks that `docs/DEVELOPMENT.md` defers to release readiness: layout sizes and text fit, AX3, dark mode, VoiceOver, BRU look, copy, and swipe-back on every screen.
  The ten slowest suites take 72 minutes; only `ArchiveRoutineUITests` and `MilestoneOneJourneyUITests` among them mainly check data.

## Target

- Every UI test suite in `fitbodUITests`; the shared helper files stay as they are.

## Change

1. Keep a UI test case only when it guards data: it fails if the app loses, corrupts or misreports what the lifter saved or logged.
   That covers relaunch and persistence, saves, deletes, archive and restore, backup and export, a removal that asks first, the weight and reps a set logs, counts, PRs and history built from logged workouts, and one end-to-end journey per workflow.
2. Delete every other case:
   - layout sizes, frames and text fit;
   - AX3, dark mode and Pro Max checks;
   - VoiceOver labels and traversal;
   - BRU look and smoke tests that only check a screen draws;
   - copy and labels;
   - tap targets, hit areas and back labels;
   - swipe-back on every screen;
   - loops that open a screen many times;
   - the Xcode template tests (`fitbodUITests.swift`, `fitbodUITestsLaunchTests.swift`) and `UITestHelpersSelfTests`.
3. In `SwipeBackUITests`, keep two cases: an edge swipe on a pushed screen in a tab returns to its parent, and an edge swipe on a tab's root screen does nothing.
4. Delete a suite's file when no case is left.
5. Keep these suites whole, because a live or next ticket runs them: `WeeklyRecapUITests`, `PerMuscleDetailUITests`, `EmptyWorkoutCountsUITests`, `BlockWeekCountsUITests` and `BlockOverviewStatesUITests`.
6. Do not merge or speed up the cases you keep; only delete.

## Constraints

- No app code changes, and no changes to `fitbodTests`.
- Leave `UITestNavigation.swift`, `SheetUITestNavigation.swift` and `WorkoutUITestNavigation.swift` as they are, even where a helper becomes unused.
- Leave the app's DEBUG launch flags and seeds as they are.
- A deleted test stays in git history; release readiness can bring it back.

## Ownership

You may edit or delete the files in `owns`.
Ask before you edit anything else.

## Repro first

There is no bug to reproduce.
Record the baseline in `notes.md` from the inventory in Hints, and do not run the old suite again.

## Observable acceptance

- The whole remaining `fitbodUITests` target passes on the small phone in one run of at most 40 minutes.
  `notes.md` records the run's duration, its case count and its 20 slowest cases.
  A case that also fails on `main` without your change is reported in `notes.md` and does not block.
- `fitbodTests` passes, and the app and the widget build.
- `notes.md` has two tables:
  - each kept suite, with the data it guards in one line;
  - each deleted suite or case, with its Gate 2 minutes and its category from Change 2.
- `git diff --stat` against the dispatch base shows only `fitbodUITests` files and your evidence.

## Hints

- `/Users/csaechao4/.copilot/session-state/31f45423-f2e1-4745-ac16-85e63f38cb45/files/conway/ui-inventory-2026-11-01.txt` lists every suite with its Gate 2 minutes, its case count and its own doc comment.
  The three suites in `fitbodUITests/Phase6/` ran 0.5, 0.6 and 0.7 minutes at Gate 2.
- Gate 2's result bundle is `/Users/csaechao4/.copilot/session-state/31f45423-f2e1-4745-ac16-85e63f38cb45/files/conway/gate2/gate2.xcresult`; `xcrun xcresulttool get test-results tests --path <bundle>` gives each case's duration.
- The Xcode project uses synchronized folders, so deleting a file needs no project edit.
- Likely kept, after reading them: `MilestoneOneJourneyUITests`, `WorkoutLoggerJourneyUITests`, `WorkoutSwapJourneyUITests`, `ReseedRelaunchUITests`, `BlockDraftKeepsUITests`, `ArchiveRoutineUITests`, `NewBlockSavesUITests`, `BlockLifecycleEntryPointsUITests`, `SettingsExportUITests`, `EditorSwipeDismissUITests` (unsaved edits resist the swipe), `CalibratingWeightUITests`, `PRListAndSeriesUITests` and the suites in Change 5.
  Each keeps only its data cases.
- `SwipeBackUITests.swift` and `Phase6/ProgressChartBRUUITests.swift` are held by live T136 and T129, which are finishing.
  Ask for each when you reach it; the coordinator grants it once its holder has merged.
- Pending tickets that name a suite you delete are re-scoped by the coordinator after your merge; do not edit tickets.
