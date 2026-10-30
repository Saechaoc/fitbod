---
id: T51
title: Plateau check reads finished workouts only
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Fatigue/PlateauDetector.swift, new:fitbodTests/PlateauUsesFinishedWorkoutsTests.swift]
---

# T51: Plateau check reads finished workouts only

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F3, which the T50 worker read from the code and recorded in the run log.
During a workout, `SessionExerciseCard.evaluatePlateau()` asks `PlateauDetector.evaluate` whether the exercise has stalled, and shows a suggested action when it has.
`evaluate` and its private `hasRPECreep` sort every matching `SessionExercise` by its workout's `startedAt` and take the newest ones.
Neither leaves out the workout in progress.
So once a working set is logged today, today's partial top set joins the stall window, and the stall signal and its suggested action can change in the middle of the workout.
T50 fixed the same mistake in the WHY explanation's history (`f9c79b7`), and `PreviousMatchingIntent.fetchTopWorkingSet` already reads finished workouts only.

## Target

- `PlateauDetector.evaluate` and `PlateauDetector.hasRPECreep` in `fitbod/Fatigue/PlateauDetector.swift`.

## Change

1. The stall window and the RPE-creep check read only finished workouts, those with `completedAt` set, for that exercise and intent.
2. For finished history alone, the stall signal and the suggested action stay the same as before.
3. No screen changes, and the suggested actions keep their copy.

## Constraints

- No schema change.
- Follow the `#Predicate` rule in `CLAUDE.md`: no multi-level optional chain inside a predicate; filter in Swift after a broad fetch, as T50 did.
- Do not edit `fitbod/Sessions/SessionExerciseCard.swift`, which T04 and T34 own.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

Write unit tests first, in `fitbodTests/PlateauUsesFinishedWorkoutsTests.swift`, with the fixtures in `fitbodTests/Fatigue/FatigueTestFixtures.swift`:
- Finished workouts that do not stall, plus a workout in progress whose one logged working set is light enough to look like a stall.
  Assert that `evaluate` does not report a stall.
  Today it does.
- The same for the RPE-creep check, through `evaluate`.

## Observable acceptance

- The repro tests pass.
- `PlateauDetectorTests` and `SuggestedActionTests` pass.
- `fitbodTests` passes on the large phone.
- `notes.md` says what each check read before the change and what it reads now.

## Hints

- `git show f9c79b7` shows how T50 left out unfinished workouts in a Swift post-filter.
- If the repro shows that the workout in progress cannot reach the stall window, report "not reproduced" as the worker rules say.
