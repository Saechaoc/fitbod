---
id: T52
title: RPE creep skips workouts without a logged set
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Fatigue/PlateauDetector.swift, new:fitbodTests/RPECreepEmptyWorkoutTests.swift]
---

# T52: RPE creep skips workouts without a logged set

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F4, which the T51 worker read from the code and recorded in the run log.
When an exercise has stalled, `PlateauDetector.suggestedAction` asks the private `hasRPECreep` whether the exercise's top-set RPE has crept up across the window.
`hasRPECreep` takes one pick per finished workout.
A finished workout that holds the exercise but no logged working set for it still becomes a pick, with 0 kg and no RPE.
`evaluate` skips such workouts, so the two checks read different windows, and the empty pick can hide real RPE creep.

## Target

- `PlateauDetector.hasRPECreep` in `fitbod/Fatigue/PlateauDetector.swift`.

## Change

1. The RPE-creep check skips a finished workout that has no logged working set for the exercise, the same way `evaluate` does.
2. With no such workouts in the window, the suggested action stays the same as before.
3. No screen changes.

## Constraints

- No schema change.
- Keep `hasRPECreep` private, and drive tests through `evaluate` and `suggestedAction`, as `SessionExerciseCard.evaluatePlateau()` does.
- Follow the `#Predicate` rule in `CLAUDE.md`.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

Write a unit test first, in `fitbodTests/RPECreepEmptyWorkoutTests.swift`, with the fixtures in `fitbodTests/Fatigue/FatigueTestFixtures.swift`:
- Finished history that stalls with clear RPE creep, plus one finished workout in the window where the exercise has no logged working set.
  Assert that `suggestedAction` reports RPE creep (`.dropIntensity`), as it does without the empty workout.
  Today the empty workout hides it.

## Observable acceptance

- The repro test passes.
- `PlateauDetectorTests`, `SuggestedActionTests` and `PlateauUsesFinishedWorkoutsTests` pass.
- `fitbodTests` passes on the large phone.
- `notes.md` says how the creep window chooses its workouts before and after the change.

## Hints

- `git show c0027aa` shows T51's change to the same function and its tests.
