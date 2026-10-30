---
id: T50
title: WHY suggests from finished workouts only
phase: 1
items: []
depends_on: []
size: M
sim: large
owns: [fitbod/Sessions/SessionFactory.swift, fitbod/Sessions/PreviousMatchingIntent.swift, new:fitbodTests/WhyUsesFinishedWorkoutsTests.swift]
---

# T50: WHY suggests from finished workouts only

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F2, which the T02 worker read from the code and recorded in the run log.
During a workout, the WHY explanation, `SessionExerciseCard.currentExplanation()`, gets the last session's working reps from `SessionFactory.lastSessionWorkingReps`.
That function sorts every matching `SessionExercise` by its workout's `startedAt` and returns the newest one with completed working sets.
It never leaves out the workout in progress.
So once a working set is logged today, today's reps count as the last session, and the bump decision behind the suggested weight can change in the middle of the workout.

## Target

- `SessionFactory.lastSessionWorkingReps` and `SessionFactory.fetchHistoryPoints` in `fitbod/Sessions/SessionFactory.swift`.
- `PreviousMatchingIntent.fetchTopWorkingSet` in `fitbod/Sessions/PreviousMatchingIntent.swift`.
- These are the history inputs that `SessionExerciseCard.currentExplanation()` reads.

## Change

1. The explanation's last-session reps come from the newest finished workout (one with `completedAt` set) for that exercise and intent, never from the workout in progress.
2. Check the other history inputs of the explanation the same way, and fix any that read the workout in progress.
   Fix each one in its shared function, not in the caller.
3. Building a new workout in `SessionFactory` gives the same prescription as before for the same history.
4. No screen changes, and the explanation's copy stays the same.

## Constraints

- No schema change.
- Follow the `#Predicate` rule in `CLAUDE.md`: no multi-level optional chain inside a predicate; filter in Swift after a broad fetch.
- Do not edit `fitbod/Sessions/SessionExerciseCard.swift`, which T04 and T34 own.
  If the fix needs a caller change, ask the coordinator first.
- Keep the existing exclusion that `PreviousPerformanceExclusionTests` covers working.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

Write unit tests first, in `fitbodTests/WhyUsesFinishedWorkoutsTests.swift`:
- A finished workout logs working reps 12, 12 and 12 for an exercise.
  A later workout of the same exercise and intent is still in progress and has one completed working set of 8 reps.
  Assert that the last-session reps are 12, 12 and 12.
  Today the function returns 8.
- Write the same kind of test for each other history input of the explanation that reads the workout in progress.

## Observable acceptance

- The repro tests pass.
- `PreviousMatchingIntentTests`, `PreviousPerformanceExclusionTests`, `MidSessionSwapTests` and `ManualOverrideTests` pass.
- `fitbodTests` passes on the large phone.
- `notes.md` names each history input, says whether it read the workout in progress before the change, and how it was fixed.

## Hints

- `fitbodTests/Logger/PreviousPerformanceExclusionTests.swift` already tests how the logger's Previous column leaves out the current workout, so reuse its setup.
- `SessionFactory` refuses to build a workout while another one is active, so leaving out unfinished workouts should not change what it builds.
