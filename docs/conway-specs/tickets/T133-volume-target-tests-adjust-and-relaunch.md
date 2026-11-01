---
id: T133
title: Volume target tests cover VoiceOver's adjust and a relaunch, and the fatigue smoke test launches cleanly
phase: 4
items: []
depends_on: [T109]
size: S
sim: small
owns: [fitbod/Fatigue/MuscleVolumeTargetStepper.swift, fitbodTests/MuscleVolumeTargetStepperBRUTests.swift, fitbodUITests/Phase5BRUSmokeUITests.swift, fitbodUITests/MuscleVolumeTargetEditorUITests.swift, fitbodUITests/PerMuscleDetailUITests.swift]
---

# T133: Volume target tests cover VoiceOver's adjust and a relaunch, and the fatigue smoke test launches cleanly

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F310 to F313, which T109's worker found.

- Since T109, each volume target is one adjustable VoiceOver element, and its adjust action steps the target inside 1 to 30 sets.
  No test covers that action: XCUI on iOS cannot send increment or decrement, so the UI tests step through the visible − and + cells.
- No test edits a target, relaunches the app and checks that the edit stayed.
  `MuscleVolumeTargetSeeder` runs at every launch and must skip a target the lifter edited.
- `Phase5BRUSmokeUITests.testFatigueSurfaceViewRenders` launches with a bare `app.launch()` on whatever store the phone holds, as guide section 2.7 warns against.
- `MuscleVolumeTargetEditorUITests` keeps an `.any` query from before T109's change, and `PerMuscleDetailUITests`' bar-tap test repeats `openMuscle` instead of calling it.

## Target

- The adjust action in `fitbod/Fatigue/MuscleVolumeTargetStepper.swift`, and the tests named in Problem.

## Change

1. A unit test covers the adjust action: increment and decrement step by one, and stop at 1 and at 30.
   The row and the test share one function for the step, so the test checks the code the row runs.
2. A UI test edits a target, relaunches the app without the reset flag, and finds the edited value still shown.
3. `testFatigueSurfaceViewRenders` launches through `UITestNavigation.launch`.
4. `MuscleVolumeTargetEditorUITests` drops the old `.any` query, and the bar-tap test calls `openMuscle`.

## Constraints

- The app behaves exactly as it does today; only the step moves into a function the test can call.
- Every test keeps its assertions.
- Each unit case runs in under 1 s, and the relaunch case fits the 90 s journey budget.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- Write the unit test against the step as the row has it today, and record in `notes.md` that the row's closure cannot be called from a test.
- Run `Phase5BRUSmokeUITests` on a store you just reset, and record its durations as the "before" numbers.

## Observable acceptance

- The new tests pass: the unit test with `fitbodTests`, and the relaunch test on the small phone.
- `Phase5BRUSmokeUITests`, `MuscleVolumeTargetEditorUITests` and `PerMuscleDetailUITests` pass on the small phone, with durations before and after in `notes.md`.
- The app and the widget build.

## Hints

- T109's notes in `docs/conway-specs/evidence/T109/notes.md`, under Findings, describe each gap.
- `-fitbod-reset-store` works on the initial launch only, so the relaunch must launch without it.
