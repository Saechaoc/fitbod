---
id: T104
title: Weekly Tonnage stops crashing, keeps whole weeks and works with VoiceOver
phase: 2
items: []
depends_on: [T23]
size: L
sim: small
owns: [fitbod/Progress/WeeklyTonnageView.swift, fitbod/Progress/WeekDetailView.swift, fitbod/Progress/WeeklyTonnageAggregator.swift, fitbod/App/WeeklyTonnageSeed.swift, fitbodTests/Phase6/WeeklyTonnageFilterStateTests.swift, fitbodTests/Phase6/WeeklyTonnageChartWeeksTests.swift, fitbodUITests/WeeklyTonnageUITests.swift]
---

# T104: Weekly Tonnage stops crashing, keeps whole weeks and works with VoiceOver

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F158 to F161, which T23's worker found, F162, which the coordinator saw in T23's screenshots, and F165, which T18's worker hit.

- Opening Weekly Tonnage crashed the app once in six tries, inside Swift Charts, with a Dictionary key Hashable violation, after T23's change.
- With Last 26 wk, VoiceOver hears the bars grouped by month, such as "Sep 1, 2026 to Oct 1, 2026" with "1,238 to 1,350", instead of one element per week.
- VoiceOver cannot open a week's detail from the chart, because the tap overlay has no accessibility action.
- WeekDetailView lists workouts by their start, while the chart and the totals count each set by when it was completed.
  So a workout that crosses midnight at the edge of a week can land in one week on the chart and in another in the detail.
- Last 8 wk can hold 9 bars and read "TOTAL · 9 WEEKS", because its lower bound rolls with the clock.
- The chart and its week detail go back with a bare "‹", while worker-rules says pushed screens go back with "‹ BACK".
- The chart's week calendar copies the aggregator's inline one, so the two can drift apart.

## Target

- The chart, its range bounds and its header in `fitbod/Progress/WeeklyTonnageView.swift`.
- `fitbod/Progress/WeekDetailView.swift`.
- The week calendar in `fitbod/Progress/WeeklyTonnageAggregator.swift`.

## Change

1. Weekly Tonnage never crashes when it opens.
   Find what breaks Hashable in the chart's keys, and fix it at its cause.
2. VoiceOver reads one element per week in every range, named with its week and tonnage, as the bars already are.
3. Each week's element opens its week detail when activated, as a tap on its bar does.
4. WeekDetailView shows the work its bar counts: each set lands in the week that holds its completion time, by the user's week-start setting, and the detail's total equals the bar.
5. Last 8 wk and Last 26 wk start at the start of a week, so the chart shows exactly 8 or 26 week slots, and the label never reads more weeks than the range.
6. The aggregator and the chart read one shared week calendar, and the aggregator's math stays as it is.
7. The chart and its week detail go back with "‹ BACK".

## Constraints

- Units relabel the stored numbers and never convert them, as `CLAUDE.md` says.
- Keep T23's axis, unit label and bar names.
- Update `WeeklyTonnageFilterStateTests` only where change 4 moves the range bounds on purpose.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

- On the small phone, open Weekly Tonnage 20 times in a row, each in a fresh launch, and assert that the app never crashes.
  With about one crash in six opens, 20 opens almost always crash today.
- In `WeeklyTonnageChartWeeksTests`, assert that Last 8 wk spans exactly 8 week slots from the start of a week, on every weekday and for both week-start settings.
- In a unit test, log a workout that starts on the last evening of a week and completes its sets after midnight, and assert that the week detail and the bar count those sets in the same week.
  Move the week detail's grouping into a function the test can call.
- In `WeeklyTonnageUITests`, on the small phone with Last 26 wk, assert that each week with data is its own accessibility element, and that activating one opens its week detail.
- Assert that the chart and the week detail each show "‹ BACK".

## Observable acceptance

- The repro tests pass, the UI tests on the small phone.
- Weekly Tonnage opens 20 times in a row without a crash on both phones.
- `WeeklyTonnageAggregatorTests`, `WeeklyTonnageFilterStateTests`, `WeeklyTonnageChartWeeksTests` and `WeeklyTonnageViewCopyTests` pass with `fitbodTests`.
- `WeeklyTonnageUITests` and `ProgressHomeBRUUITests` pass on the small phone.
- Screenshots of Last 8 wk with nine weeks of data and of a week's detail on the small phone are in `screens/`.

## Hints

- T18's crash report and its crash line are in the main checkout's `docs/conway-specs/evidence/T18/`.
- One suspect: the chart passes a `Calendar` with a changed `firstWeekday` to its week values, and two such calendars may compare equal but hash differently.
- `ExerciseProgressView` replaces Swift Charts' grouped VoiceOver elements with `.accessibilityChildren`, near `ExerciseProgressView.swift:459`.
- `TimeRangeChoice.lowerBound(now:)` is near `WeeklyTonnageView.swift:54`, and `WeeklyTonnageChartWeeks` is at the end of that file.
- The aggregator builds its calendar near `WeeklyTonnageAggregator.swift:110`.
- `WeeklyTonnageSeed` seeds one workout on each of the last N Sundays with `-fitbod-seed-weekly-tonnage`.
