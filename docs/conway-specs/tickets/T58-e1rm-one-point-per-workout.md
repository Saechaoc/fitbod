---
id: T58
title: e1RM chart plots one point per workout
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Progress/SeriesBuilder.swift, fitbodTests/Phase6/SeriesBuilderTests.swift]
---

# T58: e1RM chart plots one point per workout

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F29, which the T13 worker read from the code.
`SeriesBuilder.buildPoints` makes the e1RM points for each logged exercise in a workout.
So an exercise logged twice in one workout gets two top-set points and two all-set averages on the same date.
The VOLUME and AVG RPE series already combine an exercise's sets per workout.

## Target

- `SeriesBuilder.buildPoints(from:)` in `fitbod/Progress/SeriesBuilder.swift`.

## Change

1. Each workout gives at most one top-set point and one all-set average for the exercise, across every time it was logged in that workout.
2. The top set and the average follow today's rules (top set by highest e1RM, then highest weight, then latest completion; sets over 10 reps have no e1RM).
3. Workouts that log the exercise once plot exactly as today.

## Constraints

- No schema change.
- Keep `E1RMSeriesPoint` and the chart's callers as they are.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

In `fitbodTests/Phase6/SeriesBuilderTests.swift`, build one workout that logs the same exercise twice, and assert that `buildPoints` gives one top-set point and one all-set average for that date.
Today it gives two of each.

## Observable acceptance

- The repro test passes.
- `SeriesBuilderTests` passes, including the existing one-log-per-workout cases.
- `fitbodTests` passes on the large phone.

## Hints

- `workoutPoints(from:series:value:)` in the same file already groups the VOLUME and AVG RPE sets per workout.
