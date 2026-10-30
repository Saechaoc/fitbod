---
id: T59
title: Swapping an exercise resets its prescription and override marks
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Sessions/SwapExerciseSheet.swift, fitbod/Sessions/SessionFactory.swift, new:fitbodTests/SwapExercisePrescriptionTests.swift]
---

# T59: Swapping an exercise resets its prescription and override marks

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F30, which the T09 worker read from the code.
In the workout logger, swapping an exercise re-seeds the pending sets' weights from the new exercise's last matching set.
But the session exercise keeps the old exercise's prescribed weight, and the pending sets keep their "M" (changed from prescription) mark.
The weight cell then compares and seeds against the old exercise's prescription, so a set can show the old exercise's weight, or an "M" that has nothing to do with the new exercise.

## Target

- The swap in `fitbod/Sessions/SwapExerciseSheet.swift`.
- The prescription step in `fitbod/Sessions/SessionFactory.swift`.

## Change

1. After a swap, the session exercise's prescribed weight is the new exercise's, computed the way a workout start computes it.
2. The pending sets lose their "M"; logged sets stay exactly as they were.
3. The swap still applies to this workout only, and the session template does not change.

## Constraints

- No schema change.
- Keep one way to compute a prescription: reuse `SessionFactory`'s step, and do not copy it.
- Follow the `#Predicate` rule in `CLAUDE.md`.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

Write unit tests first, in `fitbodTests/SwapExercisePrescriptionTests.swift`:
- Start a workout, mark a pending set as changed from prescription, and swap its exercise for one with different history.
  Assert that the session exercise's prescribed weight equals what a fresh workout start prescribes for the new exercise.
- Assert that the pending set's mark is cleared and a logged set is unchanged.

Today both keep the old exercise's values.

## Observable acceptance

- The repro tests pass.
- `WorkoutSwapJourneyUITests` passes on the small phone.
- `fitbodTests` passes.

## Hints

- The swap sets `sessionExercise.exercise` near line 43 of `SwapExerciseSheet.swift` and re-seeds the pending sets from `PreviousMatchingIntent.fetchTopWorkingSet`.
- `SessionFactory.swift` computes the prescription with `strategy.prescribe(...)` near lines 285-303.
- Since T09 (`e47c09d`), only typing sets the "M".
