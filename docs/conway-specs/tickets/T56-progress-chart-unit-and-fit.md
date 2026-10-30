---
id: T56
title: Progress chart hero shows the right unit, and its name and PR mark fit
phase: 1
items: []
depends_on: []
size: S
sim: both
owns: [fitbod/Progress/ExerciseProgressView.swift, new:fitbodUITests/ProgressChartFitUITests.swift]
---

# T56: Progress chart hero shows the right unit, and its name and PR mark fit

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F24, F25 and F26, which the T13 worker found on an exercise's progress chart.
The hero above the chart always says "LB" ("111 LB", "- 2 LB", "FROM 112 LB"), whatever the unit setting or the exercise's unit override.
The chart's own readouts already use the effective unit.
The chart's "PR 112" label is cut off at the chart's right edge on both phones.
On the small phone at default text, the header cuts the exercise name short, such as "BARBELL BENCH PRESS - MEDIUM G…".

## Target

- `heroBand` and the PR `RuleMark` annotation in `fitbod/Progress/ExerciseProgressView.swift`.
- How that screen passes the exercise name to its header.

## Change

1. The hero's value, change and "FROM" line use the exercise's effective unit, as the chart's readouts do.
2. The PR label is fully inside the chart on both phones.
3. The header shows the whole exercise name on the small phone at default text.

## Constraints

- Units only relabel the stored numbers; never convert them.
- `BRUHeaderBar` is shared by every screen; ask before you change it.
- Keep the copy that `ExerciseProgressViewCopyTests` pins, unless you change it on purpose.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ProgressChartFitUITests.swift`, with the progress history seed (`-fitbod-seed-progress-history`, from T13):
- Set the bench press's unit override to KG, open its progress chart, and assert that the hero reads KG, not LB.
- On the small phone, assert that the header shows the whole name, and that the PR label's frame is inside the chart's frame (`UITestNavigation.assertInside`).

These fail today.

## Observable acceptance

- The repro tests pass on both phones.
- `ProgressChartBRUUITests`, `PRListAndSeriesUITests` and `ExerciseProgressViewCopyTests` pass.
- `fitbodTests` passes.
- Screenshots of the chart in KG on both phones, and of the header on the small phone, are in `screens/`.

## Hints

- The chart readouts get their unit from `WeightUnit.effective(for:default:)` near line 249.
- `heroBand` is near line 283, and the PR annotation uses `.topTrailing` near line 361.
- `BRUHeaderBar` allows two lines for a title with spaces and shrinks it to 85%, which is not enough for long names on the small phone.
