---
id: T75
title: A swap rebuilds the warm-ups for the new exercise, and the swap tests drive the real swap
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Sessions/SwapExerciseSheet.swift, fitbod/Sessions/SessionFactory.swift, fitbodTests/MidSessionSwapTests.swift, fitbodTests/Logger/SessionSnapshotFidelityTests.swift, new:fitbodTests/SwapWarmupTests.swift]
---

# T75: A swap rebuilds the warm-ups for the new exercise, and the swap tests drive the real swap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F64 and F66, which the T59 worker found.
`SwapExerciseSheet.swap` re-seeds every pending set, warm-ups included, with the new exercise's last top working weight.
After a swap of an exercise that has a warm-up ramp, every ramp row shows that working weight, or 0.
The ramp also stays when the new exercise would get none, such as push-ups.
`MidSessionSwapTests` checks a hand-written copy of the old swap code, not `SwapExerciseSheet.swap`, and `SessionSnapshotFidelityTests` copies the swap too.
Neither notices when the real swap changes.

## Target

- `SwapExerciseSheet.swap` in `fitbod/Sessions/SwapExerciseSheet.swift`.
- The warm-up step in `SessionFactory.start`, if the swap needs to share it.
- The swap code that `MidSessionSwapTests` and `SessionSnapshotFidelityTests` copy.

## Change

1. If the swapped exercise had pending warm-up rows, the swap replaces them with the ramp a workout start would build for the new exercise from its new prescribed weight.
   When the new exercise would get no ramp, the swap removes them.
2. A swap never adds a ramp to an exercise that had none, and completed warm-up rows stay as they were.
3. Pending working sets are re-seeded as T59 made them.
4. `MidSessionSwapTests` and `SessionSnapshotFidelityTests` call `SwapExerciseSheet.swap` instead of copying it.

## Constraints

- No schema change.
- Keep one way to build a ramp: reuse `SessionFactory`'s warm-up step and `WarmupRamp`, and do not copy them.
- The swap still applies to this workout only, and the session template does not change.

## Ownership

You may edit the files in `owns`, plus session tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/SwapWarmupTests.swift`, start a workout whose first exercise is a barbell compound that gets a warm-up ramp:

- Swap it for push-ups, and assert that no pending warm-up rows remain.
  Today they stay, each at the working weight hint.
- Swap it for another barbell compound, and assert that its pending warm-up rows match `WarmupRamp.generate` for the new prescribed weight.
  Today they all hold the working weight hint.

## Observable acceptance

- The repro tests pass.
- `MidSessionSwapTests`, `SessionSnapshotFidelityTests`, `SwapExercisePrescriptionTests`, `WarmupRampTests` and `WarmupDeloadIntegrationTests` pass with `fitbodTests`.
- `WorkoutSwapJourneyUITests` passes on the small phone.

## Hints

- `SwapExerciseSheet.swap` is near line 72 of `SwapExerciseSheet.swift`; it re-seeds every set that is not complete.
- `start`'s warm-up step is near line 250 of `SessionFactory.swift`: `WarmupRamp.shouldGenerate` and `WarmupRamp.generate`, for the first qualifying exercise only.
- T59 moved the prescription step into `SessionFactory.prescription`, which `swap` already calls; its result carries the bar and plates the ramp needs.
- `MidSessionSwapTests` copies the old swap near line 55.
