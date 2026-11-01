---
id: T119
title: The kept UI tests fit the test budgets
phase: 4
items: []
depends_on: [T143]
size: M
sim: small
owns: [fitbodUITests/ArchiveRoutineUITests.swift, fitbodUITests/BlockLifecycleEntryPointsUITests.swift, fitbodUITests/BlockOverviewStatesUITests.swift, fitbodUITests/BlockReviewAfterEndUITests.swift, fitbodUITests/BlockWeekCountsUITests.swift, fitbodUITests/CalibratingWeightUITests.swift, fitbodUITests/CustomExerciseEditorBRUUITests.swift, fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/EmptyWorkoutCountsUITests.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, fitbodUITests/NewBlockSavesUITests.swift, fitbodUITests/PRListAndSeriesUITests.swift, fitbodUITests/PerMuscleDetailUITests.swift, fitbodUITests/ReseedRelaunchUITests.swift, fitbodUITests/SettingsExportUITests.swift, fitbodUITests/SkipWarmupsUITests.swift, fitbodUITests/SwipeBackUITests.swift, fitbodUITests/WeeklyRecapUITests.swift, fitbodUITests/WhyThisWeightControlUITests.swift, fitbodUITests/WorkoutLoggerJourneyUITests.swift, fitbodUITests/WorkoutSwapJourneyUITests.swift]
---

# T119: The kept UI tests fit the test budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies its section 5.4 budgets: a UI case adds at most 30 s, and a journey at most 90 s.

## Problem

These are T143's findings 1 and 2 (F369), and findings F266 and F267 from T123, which T101's worker found.
The user asked for a faster UI suite; T143 cut it to 77 cases that guard data, and the whole target now takes 39.6 minutes on the small phone.

- 23 kept cases run past 30 s, 8.9 minutes over in all, and `MilestoneOneJourneyUITests.testAuthorRoutineLogRelaunchFinishAndHistory` takes 178 s against the 90 s journey budget.
  `docs/conway-specs/evidence/T143/notes.md`, under Findings, lists them with their times.
- Some kept data cases also check presentation: `CalibratingWeightUITests.testCompletedSetShowsLoggedWeight` relaunches at AX3 only for screenshots, `BlockReviewAfterEndUITests.testHeroCountsTheBlocksPRs` checks its stat row's layout, and `SkipWarmupsUITests` checks SKIP's tap target.
- T143 kept `WeeklyRecapUITests`, `PerMuscleDetailUITests`, `EmptyWorkoutCountsUITests`, `BlockWeekCountsUITests` and `BlockOverviewStatesUITests` whole, because T139 and T142 were running them; both have merged.
  Some of their cases check layout, such as `testWeekStripDayLabelsGrowWithTextSizeAndStayWhole`.
- `MilestoneOneJourneyUITests.tearDownWithError` attaches a screenshot and the whole accessibility tree after every test, and its `reveal` scrolls a page at a time.

## Target

- The suites in `owns`.

## Change

1. Apply T143's rule to the five suites it kept whole: delete each case that does not guard data.
2. Drop presentation-only steps inside kept data cases, such as AX3 relaunches for screenshots, layout checks and tap-target checks, and keep every data assertion.
3. Each listed case fits 30 s, and the journey fits 90 s, with the same data assertions.
   Where one cannot, `notes.md` says what its time is spent on.
4. `MilestoneOneJourneyUITests` attaches its screenshot and accessibility tree only when a test fails, and its `reveal` scrolls in long drags and waits with `UITestNavigation.waitUntilStill`.
5. `WorkoutLoggerJourneyUITests` launches through `UITestNavigation.launch`, so a run of that suite alone never opens the previous run's store (finding F11, seen again by T123's worker).

## Constraints

- No app code changes.
- Shared steps may move into one helper per suite; leave `UITestNavigation.swift` as it is (T39 changes it).
- Keep every case's accessibility identifiers and seeds as they are.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

There is no bug to reproduce.
Record T143's run as the baseline in `notes.md`.

## Observable acceptance

- The whole `fitbodUITests` target passes on the small phone in one run of at most 32 minutes.
  `notes.md` records the run's duration, its case count, its 20 slowest cases, and each listed case's time before and after.
- `notes.md` lists each deleted case with its category from T143's rule.
- `fitbodTests` passes, and the app and the widget build.
