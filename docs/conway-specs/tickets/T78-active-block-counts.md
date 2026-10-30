---
id: T78
title: The active block's week and session counts tell the truth
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Periodization/ProgramView.swift, fitbod/Views/BlockContextBand.swift, fitbod/App/BlockStatesSeed.swift, new:fitbodUITests/BlockWeekCountsUITests.swift, new:fitbodTests/BlockPastPlanTests.swift]
---

# T78: The active block's week and session counts tell the truth

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F69, F71 and F75, which the T12 worker found on the active block's overview.

- The week strip, its "SESSIONS DONE" count and the NOW phase's "In progress" count include empty workouts.
  With T12's seed, the empty finished "Upper B" shows as a done day, and the strip reads "2 / 2 SESSIONS DONE · 0 LEFT".
  Decision 6 leaves empty workouts out of session counts, and T12's completed-block list already does.
- An active block past its last planned week falls back to week 1: "W1 / 4" on the overview hero with phase 1 marked NOW, "WEEK 1 OF 4" with a "W2 ›" link over the overview's week strip, and "Week 1 of 4 · Accumulation" on Program's block row.
  VoiceOver reads "week 1 of 4" on the overview hero and Program's row.
  Today's band marks week 1 in its week ticker, and its phase chip falls back to "Accumulation".
  `PeriodizationEngine.weekIndex` and `PeriodizationEngine.phase` return nil after the plan, and the callers treat nil as week 1 or the first phase.
- The strip's day labels use a fixed 9pt font, which does not grow with text size.

## Target

- The active strip and phase counts in `fitbod/Periodization/BlockOverviewScreen.swift`.
- The week text on the overview hero and week strip header, Program's active block row in `fitbod/Periodization/ProgramView.swift`, and Today's block band in `fitbod/Views/BlockContextBand.swift`.
- A past-plan launch flag in `fitbod/App/BlockStatesSeed.swift`, for the screenshots.

## Change

1. The week strip, its sessions-done count and the NOW phase's count leave out empty workouts, as decision 6 says.
2. After its last planned week, an active block shows "PLAN COMPLETE" as the overview hero's headline, in place of "‹phase› week", with no week, volume or intensity row under it.
   It also shows "PLAN COMPLETE" in place of its week on the overview's week strip header and on Program's block row.
   Every phase row shows DONE, and none shows NOW.
   The strip header shows no ‹ › week links, Program's row drops its phase name, no day cell speaks a phase name, and VoiceOver says "plan complete" where it said the week.
   On Today's band, a "PLAN COMPLETE" chip takes the phase chip's place, and the week ticker shows every week as past and none as current.
   See "A block past its plan" in [../tradeoffs.md](../tradeoffs.md).
3. The strip's day labels grow with text size and stay whole on the small phone at AX3.
4. Before its last planned week, a block reads as it does today.

## Constraints

- No schema change, and do not change how `PeriodizationEngine` computes weeks.
- Use `SessionSetActions.isEmptyWorkout` for the empty-workout rule; do not write a second one.
- Keep the multi-hop optional chains out of `#Predicate`, as `CLAUDE.md` says.

## Ownership

You may edit the files in `owns`, plus block and Today tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodUITests/BlockWeekCountsUITests.swift`, on the small phone with T12's seed (`UITestNavigation.blockStates`), open Spring Block's overview from Today.
  Assert that the strip marks only Upper A's day as done and that the count reads one of two sessions done.
  Today it marks both and reads "2 / 2".
- In the same file, at default text and at AX3, assert that a strip day label is taller at AX3.
  Today it is the same 9pt at both.
- In `fitbodTests/BlockPastPlanTests.swift`, for an active block that started five weeks ago with a four-week plan, assert that the overview hero's headline, the overview's week strip header, Program's block row and Today's band chip read "PLAN COMPLETE", that the band's ticker has no current week, and that every phase is done and none is current.
  Today they show week 1.
- Add a launch flag to `BlockStatesSeed` that seeds the same blocks with Spring Block started five weeks ago instead of three days ago, so its four-week plan is over.

## Observable acceptance

- The repro tests pass, the UI tests on the small phone.
- `BlockOverviewStatesUITests` and `BlockLifecycleEntryPointsUITests` pass on the small phone.
- `BlockOverviewStatesTests` and `BlockNumberingTests` pass with `fitbodTests`.
- Screenshots of Spring Block's strip at default text and AX3 on the small phone are in `screens/`.
- With the past-plan flag, screenshots of Spring Block's overview, Program's block row and Today's band on the small phone are in `screens/`, before and after the fix.

## Hints

- `weekSessions` is the `@Query` near line 150 of `BlockOverviewScreen.swift`, and `dayState` near line 355 marks a day done from it.
- "SESSIONS DONE" is near line 707, the 9pt labels near line 787, and "In progress" near line 995.
- The callers that treat nil as week 1 are near line 312 of `BlockOverviewScreen.swift`, line 450 of `ProgramView.swift` and line 55 of `BlockContextBand.swift`; the band's "Accumulation" fallback is near line 42.
- The overview's strip header and its ‹ › links are near lines 657–669 of `BlockOverviewScreen.swift`, and the hero's VoiceOver label near line 537.
  The hero's headline is near line 497 and its week, volume and intensity row near lines 504–525; `SessionFactory` applies no phase after the plan, so those numbers would be wrong.
  The phase rows' NOW and DONE are near lines 971–972, and a day cell speaks a phase name near line 774.
  Program's row puts the phase beside the week near lines 470 and 486, and speaks it near line 521.
- `WeekTickerCells` shows a week as past when its number is below `currentWeek`.
- `BlockStatesSeed` starts Spring Block near line 113 through `BlockLifecycleService.start(block:context:now:)`.
- T12's completed-block list leaves empty workouts out near line 1155.
