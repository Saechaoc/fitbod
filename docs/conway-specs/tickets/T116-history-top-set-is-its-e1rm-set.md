---
id: T116
title: Exercise history's TOP line names the set its e1RM comes from
phase: 3
items: []
depends_on: [T112]
size: S
sim: small
owns: [fitbod/ExerciseLibrary/ExerciseHistoryView.swift, new:fitbodTests/HistoryTopSetTests.swift]
---

# T116: Exercise history's TOP line names the set its e1RM comes from

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F-ext-3, which T112-ext's worker found, with two clean-ups from the coordinator's review of T112-ext.

- A history row's TOP line names the set with the most volume, weight times reps.
  The row's e1RM is the highest e1RM of any set in that workout, so the two can name different sets.
  With the progress-history seed, the Oct 24 row reads "TOP 95×6 @8" while its heaviest set is 107.5×2 @9.5.
- Elsewhere in the app, the top set is the set with the highest e1RM: the progress chart's top-set line and the plateau check both use that rule.
- `prs30d` runs the PR replay a second time in each render, although T112 already runs it for the rows.
- `DateGroup` now holds exactly one entry, so the list builds groups only to flatten them again.
- The count line, such as "6 sets across 4 workouts", and "Workouts · 30d" count every workout that holds the exercise, an in-progress or empty one included, and ignore the intent filter (finding F278, from T34's worker).

## Target

- The TOP line, the PR replay and the row list in `fitbod/ExerciseLibrary/ExerciseHistoryView.swift`.

## Change

1. The TOP line names the set with the highest e1RM in that workout, the same set the row's e1RM comes from.
   An earlier set wins a tie, as it does today.
2. When no set has an e1RM, the TOP line keeps today's fallback.
3. Each render runs the PR replay once, and both the row chips and "PRs · 30d" use that one result.
4. The list is built straight from one entry per workout, without one-entry date groups.
5. The count line and "Workouts · 30d" count the workouts the list shows: those with a completed set of this exercise under the intent filter, so an in-progress or empty workout never counts.

## Constraints

- Keep T94's rule of one row per workout, T112's row content and "★ PR" rule, and T96's navigation and count.
- No change to how e1RM or PRs are computed.
- Keep `ExerciseRowsPerWorkoutTests`, `WorkoutSetsInOrderTests` and `HistoryPRCountTests` passing; update them only where they name the removed grouping, and keep what they check.

## Ownership

You may edit the files in `owns`, plus exercise history tests your change breaks.
Ask before you edit anything else.

## Repro first

In `HistoryTopSetTests`, build a workout with 107.5 × 2 at RPE 9.5 and 95 × 6 at RPE 8, and assert that its TOP line names 107.5 × 2.
It fails today.

## Observable acceptance

- The repro test passes with `fitbodTests` on the large phone.
- `ExerciseHistoryRowsUITests` and `SwipeBackUITests` pass on the small phone.
- A screenshot of the history on the small phone, with the Oct 24 row's TOP line, is in `screens/`.

## Hints

- The TOP set is picked with `max(by:)` on weight times reps near `ExerciseHistoryView.swift:439`, and the row's e1RM is computed near line 454.
- T112 added `ExerciseHistoryView.prSets(from:)`, which both the rows and `prs30d` call.
- `groupedByDate` and `DateGroup` are near lines 397 to 480.
