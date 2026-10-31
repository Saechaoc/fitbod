---
id: T103
title: Today's day streak and the weekly recap skip empty workouts
phase: 2
items: []
depends_on: [T22]
size: M
sim: small
owns: [fitbod/Views/TodayView.swift, fitbod/Fatigue/WeeklyRecapSheet.swift, fitbod/App/DemoWorkoutSeed.swift, fitbodTests/EmptyWorkoutCountTests.swift, fitbodUITests/EmptyWorkoutCountsUITests.swift, fitbodUITests/WeeklyRecapUITests.swift]
---

# T103: Today's day streak and the weekly recap skip empty workouts

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F151 and F152, which T22's worker found, and finding F211, which T30's worker found.
Decision 6 leaves empty workouts out of session counts, and T22 did that for Today's Sessions, This week and trend, Progress, History and Compare.

- Today's Day streak still counts a day whose only finished workout is empty.
  In T22's screenshot it reads 2 while Sessions reads 1, because the empty workout fell on the next day.
- An empty workout last week still makes the weekly recap due.
- The recap's "N / M sessions" chip still counts empty workouts.
- `WeeklyRecapUITests` launches with a plain `app.launch()`, so whether the recap shows depends on the workouts the phone's store already holds.

## Target

- The Day streak and the recap trigger in `fitbod/Views/TodayView.swift`.
- The sessions count in `fitbod/Fatigue/WeeklyRecapSheet.swift`.
- The launches in `fitbodUITests/WeeklyRecapUITests.swift`.

## Change

1. Today's Day streak counts only days that have a workout that counts as a session.
2. The weekly recap is due only when last week has a workout that counts as a session.
3. The recap's sessions chip counts only workouts that count as sessions.
4. Use T22's shared rule, `SessionSetActions.countedWorkouts` or Today's cached empty workout ids, and never write a second rule.
5. Nothing reads every workout's sets on each render, so Today keeps T22's timings.
6. `WeeklyRecapUITests` launches through `UITestNavigation.launch` with a seed that sets last week's workouts, so its result never depends on what the phone held before.

## Constraints

- Keep how Today presents the recap and the block review, and keep the recap's other numbers as they are.
- No schema change.

## Ownership

You may edit the files in `owns`, plus Today and weekly recap tests your change breaks.
You may add DEBUG seed flags in `DemoWorkoutSeed.swift` next to T22's empty-workout flags.
Ask before you edit anything else.

## Repro first

- In `EmptyWorkoutCountTests`, assert that a real workout two days ago, an empty one yesterday and a real one today give a Day streak of 1.
  Move the streak into a function the test can call.
  It gives 3 today.
- In `EmptyWorkoutCountsUITests`, on the small phone, seed a real workout yesterday and an empty one today, and assert that Today's Day streak reads 1.
- Seed only an empty workout last week, and assert that the weekly recap does not show on Today.
- Seed a real and an empty workout last week, and assert that the recap's sessions chip counts 1.

## Observable acceptance

- The repro tests pass, the UI tests on the small phone.
- `WeeklyRecapTriggerTests`, `WeeklyRecapSheetBRUTests` and `TodayViewBRUCopyTests` pass with `fitbodTests`.
- `WeeklyRecapUITests` and `HistoryAndTodayUITests` pass on the small phone, `WeeklyRecapUITests` also right after a store reset.
- Screenshots of Today's strip and of the recap from the repro seeds are in `screens/`.

## Hints

- `computedStreak` is near `TodayView.swift:459`, and `lastWeekSessionsCount(start:end:)` near line 617 decides whether the recap is due, near line 599.
- `WeeklyRecapSheet.lastWeekSessionsCount()` near line 570 feeds `sessionsLogged` near line 230 and the chip near line 183.
- Today already caches `emptyWorkoutIDs` in a `.task(id:)`, which T22 added.
- `DemoWorkoutSeed.seedFinished` builds finished Push As from a list of start offsets, and its flags mark this week's recap seen, which a recap repro must not do.
