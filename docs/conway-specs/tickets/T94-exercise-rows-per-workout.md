---
id: T94
title: Exercise screens show one row per workout
phase: 1
items: []
depends_on: [T92]
size: S
sim: large
owns: [fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/ExerciseLibrary/ExerciseHistoryView.swift, fitbod/ExerciseLibrary/ExerciseHistoryRow.swift, new:fitbodTests/ExerciseRowsPerWorkoutTests.swift]
---

# T94: Exercise screens show one row per workout

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are finding F125, which the T92 worker found, and finding F126, which the coordinator found while looking for T92's kind of bug; nobody has reproduced them yet.

- The exercise history list keys its workout rows by `dateKey`, the start of the workout's day, so two workouts on one day share a `ForEach` id.
- Each history row keys its set chips by their text, so a workout with three sets of 100×5 @8 has three chips with one id.
  SwiftUI can draw the wrong rows or chips when ids repeat.
- Exercise detail's "Recent performance" makes one entry per log, so a workout that logged the exercise twice shows two entries, though its empty state promises "Your best set from each workout".

## Target

- The workout rows in `fitbod/ExerciseLibrary/ExerciseHistoryView.swift` and the chips in `fitbod/ExerciseLibrary/ExerciseHistoryRow.swift`.
- `entries` in "Recent performance", in `fitbod/ExerciseLibrary/ExerciseDetailView.swift`.

## Change

1. Each history row's `ForEach` id is its workout, so two workouts on one day show as two rows.
2. Each chip's id is its place in the row, so repeated chips all show.
3. "Recent performance" makes one entry per finished workout, from the working sets of all of its logs: the best set (heaviest, then most reps, the earlier set winning a tie) and the working-set count.
   It keeps the newest five workouts.
4. Everything else stays as it is, including the rows' look, copy, dates and order.

## Constraints

- Keep both screens' look and copy.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/ExerciseRowsPerWorkoutTests.swift`:

- Log two finished workouts of the exercise on one day, and assert that the ids the history list gives their rows differ.
  Today that id is `dateKey`, so this fails.
- Log a finished workout that logs the exercise twice, 100 lb × 5 and then 110 lb × 5, and assert that "Recent performance" has one entry for it, with best set 110 × 5 and 2 working sets.
  Move `entries` into a static function the test can call if it needs one.
  It fails today.

Change 2 follows SwiftUI's rule that `ForEach` ids are unique; no repro is needed for it.

## Observable acceptance

- The repro tests pass.
- `WorkoutSetsInOrderTests`, `ExerciseHistoryIntentSplitTests`, `ExerciseHistoryViewCopyTests`, `HistoryBRUCopyTests` and `ExerciseDetailPlateauCopyTests` pass.
- `fitbodTests` passes on the large phone.

## Hints

- The rows' `ForEach(grouped, id: \.dateKey)` is near `ExerciseHistoryView.swift:197`; since T92, `groupedByDate` already groups by workout.
- The chips' `ForEach(rows[rowIndex], id: \.self)` is near `ExerciseHistoryRow.swift:126`.
- "Recent performance" `entries` is near `ExerciseDetailView.swift:592`.
