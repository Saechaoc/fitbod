---
id: T23
title: Weekly Tonnage fixes
phase: 2
items: [38, 25]
depends_on: [T01, T02]
size: M
sim: small
owns: [fitbod/Progress/WeeklyTonnageView.swift, fitbod/Progress/WeeklyTonnageFilterChips.swift, fitbodTests/Phase6/WeeklyTonnageViewCopyTests.swift, new:fitbodUITests/WeeklyTonnageUITests.swift]
---

# T23: Weekly Tonnage fixes

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The axis title "TONNAGE (KG)" is hard-coded, whatever the unit setting says.
The range label reads "TOTAL · 1 WEEKS".
The chart bins workouts by the device calendar's weeks, which start on Sunday in the US.
The aggregator uses the user's week-start setting, which defaults to Monday, so a Sunday workout can land in a different week in the chart than in the totals.
With one week of data, a single bar fills the whole chart.
The block filter's empty message reads "No block data yet — define a block in Routines.", which names the wrong tab and uses an em dash.

## Target

The Weekly Tonnage chart in `fitbod/Progress/WeeklyTonnageView.swift`, and the empty message in `fitbod/Progress/WeeklyTonnageFilterChips.swift`.

## Change

1. The axis title shows the unit from settings: "TONNAGE (LB)" or "TONNAGE (KG)".
   Units relabel the stored numbers and never convert them, as `CLAUDE.md` says.
2. The range label uses the T02 plural helper, such as "TOTAL · 1 WEEK" and "TOTAL · 8 WEEKS".
3. The chart bins weeks with the aggregator's rule (see "Weekly Tonnage weeks" in [../tradeoffs.md](../tradeoffs.md)).
4. The chart's week axis covers the whole selected range, so one week of data draws one narrow bar.
5. Tapping a bar still opens that week's detail.
6. The empty message reads "No block data yet. Define a block in Program."

## Constraints

- The aggregator's math stays as it is.
- If exercise unit overrides mix units inside one week's total, write it in `notes.md` as a finding, and do not convert.

## Ownership

You may edit the files in `owns`, plus Weekly Tonnage tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Set the unit to lb in Settings, open Weekly Tonnage, and assert that the axis title says LB.
  It says KG today.
- With one week of data, assert that the range label reads "TOTAL · 1 WEEK".
- With one week of data, prove from a screenshot or the chart's accessibility elements that the bar uses less than half of the plot width.
- Write a test that proves the chart and the aggregator put a Sunday workout in the same week, with the setting at Monday and at Sunday.
- Open the block filter with no block, and assert the new empty message.

## Observable acceptance

- Every repro test passes.
- `WeeklyTonnageViewCopyTests` pins the new copy, and it passes with `WeeklyTonnageAggregatorTests` and `WeeklyTonnageFilterStateTests`.
- `ProgressHomeBRUUITests` passes on the small phone.
- Screenshots of the chart with one week and with eight weeks, in lb and in kg, are in `screens/`.

## Hints

- "TONNAGE (KG)" is near `WeeklyTonnageView.swift:226`, the range label near 182, the bins near 238 and 253, and the axis marks near 277.
- The view already reads `weekStartsMonday` from settings near line 152, and its bar taps use it near line 315.
- The aggregator builds its calendar from the same flag near `WeeklyTonnageAggregator.swift:110-113`.
- The empty message is near `WeeklyTonnageFilterChips.swift:110`.
