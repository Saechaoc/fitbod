---
id: T82
title: VoiceOver reads each e1RM point's rounded weight
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Progress/ExerciseProgressView.swift, fitbodUITests/ProgressChartFitUITests.swift]
---

# T82: VoiceOver reads each e1RM point's rounded weight

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F84, which the T68 worker found on an exercise's progress chart.
On the default E1RM chip, Swift Charts groups the top-set and all-set-avg points that share a date into one VoiceOver element with its own raw summary.
With the progress history seed, one element has the label "Oct 2, 2026 at 12 AM to Oct 4, 2026 at 12 AM" and the value "112.5 to 109.71, 2 values".
So VoiceOver hears unrounded e1RMs with no unit and no series, and never reads the points' own text, such as "113 lb".
TOP SET, VOLUME and AVG RPE plot one point per date, and VoiceOver reads their points' own text there.

## Target

- The E1RM chart's points in `fitbod/Progress/ExerciseProgressView.swift`.

## Change

1. On the E1RM chip, VoiceOver reads each point by itself, with its series and date as the label and `spokenValue` as the value, as the other chips do.
2. No VoiceOver element on any chip reads an unrounded weight.
3. The chart looks exactly as it does today.

## Constraints

- Keep the point labels and values that `PRListAndSeriesUITests` reads on TOP SET, VOLUME and AVG RPE.
- Keep T68's halves-up rounding and its hidden PR rule.

## Ownership

You may edit the files in `owns`, plus progress chart tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ProgressChartFitUITests.swift`, with the progress history seed, open the bench press's progress chart on the E1RM chip and assert both of these:

- An element reads "113 lb", with a top-set label for its date.
- No element's label or value contains "112.5".

Both fail today.

## Observable acceptance

- The repro test passes on the small phone.
- `ProgressChartFitUITests`, `ProgressChartBRUUITests` and `PRListAndSeriesUITests` pass on the small phone.
- Before and after screenshots of the E1RM chart on the small phone at default text are in `screens/`, and they match pixel for pixel.

## Hints

- The points and their VoiceOver label and value are near lines 407 to 428 of `ExerciseProgressView.swift`, and `spokenValue` is near line 272.
- The other chips plot one point per date; the E1RM chip plots two series on the same dates.
