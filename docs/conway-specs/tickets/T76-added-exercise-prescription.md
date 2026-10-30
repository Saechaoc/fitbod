---
id: T76
title: An exercise added mid-workout gets its prescription
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Sessions/AddUnplannedExerciseButton.swift, fitbodTests/AddUnplannedExerciseTests.swift]
---

# T76: An exercise added mid-workout gets its prescription

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F65, which the T59 worker read from the code.
`AddUnplannedExerciseButton.append` adds an exercise to a workout in progress with three planned sets, but leaves its `prescribedWeight` empty.
So the weight cell never marks a typed weight or seeds against a prescription for it, as it does for planned exercises.
`AddUnplannedExerciseTests` re-implements `append` instead of calling it, so it cannot catch this.

## Target

- `append(exercise:)` in `fitbod/Sessions/AddUnplannedExerciseButton.swift`.

## Change

1. An exercise added during a workout gets the prescribed weight a workout start would give it, with this workout's intent, block and start date.
2. Its three planned sets, targets and rest are seeded as today.
3. `AddUnplannedExerciseTests` calls the real append instead of re-implementing it.

## Constraints

- No schema change.
- Keep one way to compute a prescription: call `SessionFactory.prescription` (T59), and do not copy it.

## Ownership

You may edit the files in `owns`, plus session tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/AddUnplannedExerciseTests.swift`, start a workout, add an exercise that has finished history through the real append, and assert that its `prescribedWeight` equals what a fresh workout start prescribes for it.
Today it is empty.

## Observable acceptance

- The repro test passes.
- `AddUnplannedExerciseTests`, `SwapExercisePrescriptionTests` and the `SessionFactory` suites pass with `fitbodTests` on the large phone.

## Hints

- `append(exercise:)` is a private method near line 64; making it a static function that takes the session and context, as T59 did with `SwapExerciseSheet.swap`, lets a test call it.
- `SwapExerciseSheet.swap` shows how to call `SessionFactory.prescription` for a workout in progress.
