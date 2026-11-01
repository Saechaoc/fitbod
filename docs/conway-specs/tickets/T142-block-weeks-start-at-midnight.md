---
id: T142
title: A block week starts at local midnight on its first day
phase: 3
items: []
depends_on: [T139]
size: M
sim: small
owns: [fitbod/Prescription/PeriodizationEngine.swift, fitbod/Fatigue/PlateauDetector.swift, fitbod/Periodization/BlockDraft.swift, fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Views/TodayView.swift, fitbodTests/PeriodizationEngineTests.swift]
---

# T142: A block week starts at local midnight on its first day

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F359, which T139's worker found.

- `PeriodizationEngine` counts a block's days in whole 24-hour spans from `block.startDate` (`PeriodizationEngine.swift:109-111`), and `BlockLifecycleService.start` stamps `startDate = now`.
- So a block week starts at the time of day the block was started.
  A block started on Monday at 6:05 am puts the next Monday's 6:00 am workout in week 1, with week 1's prescription, phase and deload.
  Today's band, the block overview and the prescription all read that week.
- A daylight-saving change moves the boundary by an hour as well.

## Target

- `PeriodizationEngine.days(from:to:)`, and `weekContext`'s week start, which adds 7 × 86,400 s.
- Today's week math: `currentTrend` near `TodayView.swift:537` and `checkWeeklyRecap` near `TodayView.swift:625` still step 7 × 86,400 s from this week's start (finding F363, from T139's worker).
- Block-week math outside the engine:
  - `PlateauDetector`'s Branch 3, `isInBlockWeekThreeWithDeloadComing`;
  - `computedDaysRemaining` near `BlockOverviewScreen.swift:349`;
  - `BlockDraft.computedEndDate` at `BlockDraft.swift:118`.

## Change

1. A block's day count is the number of calendar days from the day the block started to the day of the date, so each block week starts at local midnight, a daylight-saving change included.
2. The engine takes a calendar, `.current` by default, so a test can choose the time zone.
3. The spans in Target use the same count, so every screen and the prescription agree on the week.
4. `startDate` keeps the instant the block started; only the counting changes.
5. Today's trend and its weekly-recap check take last week from `FatigueModel.date(byAddingWeeks:to:calendar:)`, as the recap itself does since T139, so twice a year Today neither shows a recap for an empty week nor skips one.

## Constraints

- Only a date on the weekday the block started, before the time of day it started, or within an hour of a daylight-saving change, may change week or phase.
- Keep T78's past-plan rule: `weekIndex` is nil after the last planned week (finding F71).
- No schema change.

## Ownership

You may edit the files in `owns`, plus block, prescription and fatigue tests your change breaks.
Ask before you edit anything else, such as the views that call the engine.

## Repro first

In `PeriodizationEngineTests`, with a calendar in `America/Los_Angeles`:

- A three-week block started on Monday 2026-10-05 at 6:05 am: assert that `weekIndex` on Monday 2026-10-12 at 6:00 am is 1.
  It is 0 today.
- A three-week block started on Monday 2026-10-26 at local midnight: assert that `weekIndex` on Sunday 2026-11-01 at 11:30 pm, after the clocks went back, is 0.
  It is 1 today.

## Observable acceptance

- The repro tests pass with `fitbodTests` on the large phone.
- `SuggestedActionTests`' Branch 3 test builds its block start with calendar math and passes on any day, a daylight-saving week included.
- `BlockWeekCountsUITests`, `BlockOverviewStatesUITests` and `WeeklyRecapUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T139's `notes.md` lists Branch 3's spans and the fixed-second fixture in `SuggestedActionTests`.
- `TrainingDaysWriter` already takes an injected calendar; follow its pattern.
- The engine's callers: `BlockPeriodizedStrategy`, `SessionFactory`, `TodayView`, `BlockContextBand`, `ProgramView`, `BlockOverviewScreen`, `BlockCard`, `BlockRow`, `MesocycleWeekPage` and `SwapExerciseSheet`.
  A default calendar argument keeps their calls unchanged.
- `tradeoffs.md` "Block weeks" records this rule.
