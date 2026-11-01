---
id: T133
title: A volume target edit survives a relaunch, and the fatigue smoke test launches cleanly
phase: 4
items: []
depends_on: [T109]
size: S
sim: small
owns: [fitbodUITests/Phase5BRUSmokeUITests.swift, fitbodUITests/MuscleVolumeTargetEditorUITests.swift, fitbodUITests/PerMuscleDetailUITests.swift]
---

# T133: A volume target edit survives a relaunch, and the fatigue smoke test launches cleanly

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F311 to F313, which T109's worker found.
Finding F310, a test of each target's VoiceOver adjust action, is deferred under `docs/DEVELOPMENT.md` as VoiceOver refinement.

- No test edits a target, relaunches the app and checks that the edit stayed.
  `MuscleVolumeTargetSeeder` runs at every launch and must skip a target the lifter edited.
- `Phase5BRUSmokeUITests.testFatigueSurfaceViewRenders` launches with a bare `app.launch()` on whatever store the phone holds, as guide section 2.7 warns against.
- `MuscleVolumeTargetEditorUITests` keeps an `.any` query from before T109's change, and `PerMuscleDetailUITests`' bar-tap test repeats `openMuscle` instead of calling it.

## Target

- The tests named in Problem.

## Change

1. A UI test edits a target, relaunches the app without the reset flag, and finds the edited value still shown.
2. `testFatigueSurfaceViewRenders` launches through `UITestNavigation.launch`.
3. `MuscleVolumeTargetEditorUITests` drops the old `.any` query, and the bar-tap test calls `openMuscle`.

## Constraints

- Change tests only; the app behaves exactly as it does today.
- Every test keeps its assertions.
- The relaunch case fits the 90 s journey budget.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- Run `Phase5BRUSmokeUITests` on a store you just reset, and record its durations as the "before" numbers.

## Observable acceptance

- The relaunch test passes on the small phone.
- `Phase5BRUSmokeUITests`, `MuscleVolumeTargetEditorUITests` and `PerMuscleDetailUITests` pass on the small phone, with durations before and after in `notes.md`.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T109's notes in `docs/conway-specs/evidence/T109/notes.md`, under Findings, describe each gap.
- `-fitbod-reset-store` works on the initial launch only, so the relaunch must launch without it.
