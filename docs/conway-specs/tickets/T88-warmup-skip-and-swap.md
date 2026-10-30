---
id: T88
title: "Skip warm-ups this session only" skips, and a swap rebuilds skipped warm-ups
phase: 1
items: []
depends_on: []
size: M
sim: large
owns: [fitbod/Prescription/WarmupRamp.swift, fitbod/Sessions/SessionFactory.swift, fitbod/Sessions/SwapExerciseSheet.swift, fitbodTests/SwapWarmupTests.swift, new:fitbodTests/SkipNextSessionWarmupTests.swift]
---

# T88: "Skip warm-ups this session only" skips, and a swap rebuilds skipped warm-ups

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F98 and F99, which the T75 worker found.

- A routine exercise's "Skip warm-ups this session only" never skips.
  `WarmupConfigSheet` saves `skipNextSession: true`, but `WarmupRamp.shouldGenerate` reads only `enabled`.
  So the next workout start builds the ramp anyway, and `SessionFactory.start` then clears the flag.
- SKIP WARM-UPS is the only way to complete a warm-up, so every completed warm-up is a skipped one.
  T75 (`12581e9`) keeps completed warm-ups across a swap.
  After SKIP WARM-UPS and a swap, UNDO brings back the old exercise's ramp under the new one, for example 40/60/75/90 under "WORK SETS BEGIN AT 140" after bench 100 to squat 140.

## Target

- `WarmupRamp.shouldGenerate` in `fitbod/Prescription/WarmupRamp.swift`.
- The warm-up step and the flag reset in `fitbod/Sessions/SessionFactory.swift`.
- `rebuildPendingWarmups` in `fitbod/Sessions/SwapExerciseSheet.swift`.

## Change

1. With "Skip warm-ups this session only" on, the next workout start builds no ramp for that exercise and then clears the flag, so the start after it builds the ramp again.
2. The flag is cleared at that start even though no ramp was built, so it never keeps suppressing the ramp.
3. A swap rebuilds skipped warm-ups as well as pending ones, and the rebuilt rows stay skipped, so UNDO brings back the new exercise's ramp.
4. Everything else about warm-ups stays as it is, including a ramp only on the first qualifying compound and no ramp in a deload week.

## Constraints

- No schema change; keep `WarmupConfig`'s fields as they are.
- Keep T75's rules that a swap never adds a ramp the exercise did not have, and that sets stay numbered contiguously.

## Ownership

You may edit the files in `owns`, plus warm-up, swap and session tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/SkipNextSessionWarmupTests.swift`, start a workout from a routine whose first compound has `skipNextSession` on, and assert that it gets no warm-ups, that the flag is cleared, and that the next start builds the ramp.
  The first assertion fails today.
- In `fitbodTests/SwapWarmupTests.swift`, skip the warm-ups, swap bench 100 for squat 140, undo the skip, and assert that the warm-ups are squat's ramp.
  It fails today.

## Observable acceptance

- The repro tests pass.
- `fitbodTests` passes on the large phone.
- `WorkoutSwapJourneyUITests` passes on the small phone.

## Hints

- `shouldGenerate` is near line 47 of `WarmupRamp.swift`.
- `SessionFactory.start` clears the flag near line 268, inside the branch that only runs when a ramp was built.
- SKIP WARM-UPS and UNDO only flip `isComplete` on every warm-up, near line 533 of `SessionExerciseCard.swift`.
