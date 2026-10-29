---
id: T13
title: PR list and progress chips
phase: 1
items: [31, 32]
depends_on: [T01, T02]
size: L
sim: large
owns: [fitbod/Progress/ExercisePRsView.swift, fitbod/Progress/SeriesToggleChipRow.swift, fitbod/Progress/SeriesBuilder.swift, fitbodTests/Phase6/SeriesBuilderTests.swift, new:fitbodUITests/PRListAndSeriesUITests.swift]
---

# T13: PR list and progress chips

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The PR list can show one set three times, such as three identical "100 lb × 5 @ RPE 8" rows.
Its rows show no exercise name.
Row ids repeat across buckets, so the later buckets render blank.
On the progress chart, the E1RM and VOLUME chips do nothing, and AVG RPE plots the mean e1RM instead of the mean RPE.

## Target

- The PR list in `fitbod/Progress/ExercisePRsView.swift`.
- The chart's chips in `fitbod/Progress/SeriesToggleChipRow.swift`, and the series in `fitbod/Progress/SeriesBuilder.swift`.

## Change

1. Each bucket lists distinct sets only, ranked by the bucket's measure, at most three per exercise.
2. Each row shows the exercise's display name.
3. Row ids are unique across buckets, so every bucket renders its rows.
4. The E1RM chip shows the e1RM series.
5. The VOLUME chip shows volume per workout: weight times reps, summed over logged work sets.
6. The AVG RPE chip shows the mean RPE of logged work sets per workout, skipping sets that have no RPE.
7. Warm-ups never count in any series (T02's logged-work-sets rule).

## Constraints

- PR detection itself does not change.
- Whether a first log counts as a PR stays a roadmap decision (decision 9), so do not change that behavior.
- Update `PRsAndComparisonCopyTests` and `ExerciseProgressViewCopyTests` only where you change pinned copy on purpose.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
You may add a DEBUG seed with several workouts for two exercises next to `DemoWorkoutSeed.swift`.
Ask before you edit anything else.

## Repro first

On the large phone, with a seed of several workouts for two exercises:

- Open the PR list, and assert that no bucket has two rows for the same set.
- Assert that each row shows an exercise name.
- Assert that the 7-10 reps bucket has rows.
- Tap E1RM and then VOLUME, and assert that the chart's accessibility value changes each time.
- Write a unit test: for one workout with work sets at RPE 7, 8 and 9, the AVG RPE series gives 8.

All of these fail today.

## Observable acceptance

- Every repro test passes on the large phone.
- `SeriesBuilderTests` covers each of the three series, including sets without RPE and warm-ups.
- `ProgressChartBRUUITests` and `ProgressHomeBRUUITests` pass on the large phone.
- Screenshots of the PR list and of each chip's chart are in `screens/`.
- `fitbodTests` passes.

## Hints

- `topThree` is near lines 354-376 of `ExercisePRsView.swift`, `prRow` near 294-328, and the offset-based row ids near 277.
- The review verified that composite ids fix the blank buckets.
- The chip actions are TODO stubs near lines 44-47 and 54-57 of `SeriesToggleChipRow.swift`.
- The AVG RPE series is built from e1RM values near lines 110-122 of `SeriesBuilder.swift`.
- Swift Charts marks can carry accessibility labels and values, which UI tests can read.
