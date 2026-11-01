---
id: T119
title: Progress UI tests fit the test budgets
phase: 4
items: []
depends_on: [T104, T118]
size: M
sim: small
owns: [fitbodUITests/WeeklyTonnageUITests.swift, fitbodUITests/Phase6/ProgressHomeBRUUITests.swift, fitbod/Progress/ProgressHomeView.swift]
---

# T119: Progress UI tests fit the test budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F250, which the coordinator found in T104's test timings, and F246 and F248, which T104's worker found.

- `WeeklyTonnageUITests.testOpensTwentyTimesWithoutCrashing` opens Weekly Tonnage in 20 fresh launches, so it costs about 245 s per phone in every full run, against the guide's 90 s journey budget.
  It passed all 29 opens of the old code, so it cannot catch the crash it was written for.
  T104's unit tests pin the cause instead: Swift Charts no longer gets a calendar to bin weeks by.
- `WeeklyTonnageUITests.testAxisTitleNamesTheUnitSetting` takes 35 to 42 s, over the 30 s case budget, and `heroTotal(in:)` waits without reading `exists` first.
- `ProgressHomeBRUUITests` launches three times only to check that headings exist, which guide section 2.1 says not to do.
  It finds the tab and the headings with `label CONTAINS[c]` scans, and keeps its own 60 s "Preparing library…" wait, although `UITestNavigation.launch` already waits for the tab bar.
- `WeeklyTonnageUITests.testEightWeeksReadEightWeeks` takes about 36 s, and the suite taps the newest bar in three copies of the same code: `openNewestWeek(in:)`, `testChartAndWeekDetailGoBackWithBack` and `checkSundayWorkoutsWeek` (finding F343, from T118's run).

## Target

- `fitbodUITests/WeeklyTonnageUITests.swift`.
- `fitbodUITests/Phase6/ProgressHomeBRUUITests.swift`.

## Change

1. The 20-open crash check runs only when asked.
   It skips with `XCTSkip` unless the test runner's environment has `FITBOD_SOAK=1`, which `TEST_RUNNER_FITBOD_SOAK=1` on the `xcodebuild` command line sets, and its comment says how to run it.
2. `testAxisTitleNamesTheUnitSetting` takes at most 30 s and keeps its assertions.
3. Every wait in `WeeklyTonnageUITests`' helpers reads `exists` before it waits.
4. `ProgressHomeBRUUITests` becomes one journey with one launch that keeps every assertion it makes today.
   It finds the Progress tab, the header and the section heads by identifier, and has no splash wait of its own.
5. If a section head on Progress home has no accessibility identifier, add one in `fitbod/Progress/ProgressHomeView.swift`, and change nothing else there.
6. `testEightWeeksReadEightWeeks` takes at most 30 s with its assertions, and the two older tests open the newest week through `openNewestWeek(in:)`.

## Constraints

- No assertion gets weaker, and no test is deleted except the `ProgressHomeBRUUITests` cases that the one journey replaces.
- The rest of `WeeklyTonnageUITests` keeps running in every full run.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

- Run `WeeklyTonnageUITests` and `ProgressHomeBRUUITests` three times on the small phone with `-test-iterations 3`.
- Record each case's three durations in `notes.md` as the "before" numbers.

## Observable acceptance

- Three runs of both suites on the small phone, with each case's durations before and after in `notes.md`.
- Every case fits the 30 s case budget, and every journey fits the 90 s budget.
- `testOpensTwentyTimesWithoutCrashing` is skipped in a normal run, and with `TEST_RUNNER_FITBOD_SOAK=1` it runs once on the small phone and passes.
- `fitbodTests` passes, and the app builds.

## Hints

- T104's per-case durations are under "Test performance" in `docs/conway-specs/evidence/T104/notes.md`.
- `UITestNavigation.launch` waits up to 90 s for the Today tab, so a test that launches through it needs no splash wait.
- `xcodebuild` passes each `TEST_RUNNER_`-prefixed variable to the test runner without its prefix.
