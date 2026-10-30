---
id: T68
title: The progress chart's hero numbers add up
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Progress/ExerciseProgressView.swift, fitbodUITests/ProgressChartFitUITests.swift]
---

# T68: The progress chart's hero numbers add up

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F50, which the T56 worker found on an exercise's progress chart.
With the progress history seed, the bench press's hero reads "111 LB", "- 2 LB" and "FROM 112 LB", but 111 is 1 less than 112, not 2.
`heroBand` rounds the latest and earliest e1RM, 110.57 and 112.5, each with `%.0f`, which rounds a half to the even number, so 112.5 shows as 112.
It rounds the change from the unrounded difference, -1.93, which shows as 2.
The PR label also shows "PR 112" for 112.5, while VoiceOver reads that point as 113, because `spokenValue` rounds halves up.

## Target

- `heroBand` and `prLabel` in `fitbod/Progress/ExerciseProgressView.swift`.

## Change

1. The hero's change is its value minus its FROM number, as both are shown.
2. The hero, the PR label and the chart's VoiceOver values round a weight the same way, halves up, so 112.5 reads 113 everywhere.

## Constraints

- Units only relabel the stored numbers; never convert them.
- Keep the copy that `ExerciseProgressViewCopyTests` pins, unless you change it on purpose.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ProgressChartFitUITests.swift`, with the progress history seed (`UITestNavigation.progressHistory`), open the bench press's progress chart and assert both of these:

- The hero's value minus its FROM number equals its signed change.
- The PR label reads "PR 113".

Both fail today.

## Observable acceptance

- The repro test passes on the small phone.
- `ProgressChartFitUITests`, `ProgressChartBRUUITests` and `PRListAndSeriesUITests` pass on the small phone.
- `ExerciseProgressViewCopyTests` passes with `fitbodTests`.
- A screenshot of the hero and the PR label on the small phone is in `screens/`.

## Hints

- `heroBand` is near line 312; it formats the value, the change and the FROM line with `String(format: "%.0f", ...)`.
- `prLabel` is near line 481, and `spokenValue` near line 272 rounds with `value.rounded()`.
- In the seed, the bench press's latest top-set e1RM is 110.57, and its earliest and best is 112.5.
