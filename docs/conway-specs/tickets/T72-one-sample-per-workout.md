---
id: T72
title: The plateau and RPE-creep checks count each workout once
phase: 1
items: []
depends_on: []
size: M
sim: large
owns: [fitbod/Fatigue/PlateauDetector.swift, fitbod/Fatigue/DeloadAdvisor.swift, new:fitbodTests/Fatigue/OneSamplePerWorkoutTests.swift]
---

# T72: The plateau and RPE-creep checks count each workout once

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F58 and F59, which the T58 worker read from the code and the coordinator confirmed.
They have the same cause as F29, which T58 fixed for the e1RM chart: a check takes one sample per `SessionExercise`, so an exercise logged twice in one workout counts as two sessions.

- `PlateauDetector.evaluate` takes one top set per logged exercise row and fills its window of `plateauWindowSessions` with them.
  An exercise logged twice in one finished workout takes two places in the window, so STALLED can show after fewer workouts than the window.
  The private `hasRPECreep` reads its window the same way.
- `DeloadAdvisor`'s RPE-creep signal (Sig-2) adds one pick per logged exercise row for each exercise and intent.
  One workout can fill two of the "last three sessions" it compares.

## Target

- The window loops in `evaluate` and `hasRPECreep` in `fitbod/Fatigue/PlateauDetector.swift`.
- The Sig-2 loop in `fitbod/Fatigue/DeloadAdvisor.swift`.

## Change

1. The plateau check and its RPE-creep check count each finished workout once.
   A workout that logs the exercise several times gives one top set, picked across all of those logs by today's top-set rule.
2. The deload advisor's RPE-creep signal takes one top set per workout for each exercise and intent, so the three sessions it compares are three different workouts.
3. Workouts that log an exercise once give the same results as today.

## Constraints

- No schema change.
- Keep the window sizes, tolerances, thresholds and copy.
- Keep the multi-hop optional chains out of `#Predicate`, as `CLAUDE.md` says.

## Ownership

You may edit the files in `owns`, plus fatigue tests your change breaks.
`fitbodTests/Fatigue/PlateauDetectorTests.swift` belongs to T64, so put new tests in the new file and ask before you edit it.
Ask before you edit anything else.

## Repro first

In `fitbodTests/Fatigue/OneSamplePerWorkoutTests.swift`:

- With a plateau window of three, log two finished workouts with flat top sets, one of which logs the exercise twice.
  Assert that `PlateauDetector.evaluate` reports not enough data; today it fills the window and reports a stall.
- Log two workouts in the last three weeks at the same load with rising RPE, one of which logs the exercise twice.
  Assert that the deload advisor reports no RPE creep; today it counts three sessions and reports creep.

## Observable acceptance

- The repro tests pass.
- `PlateauDetectorTests` and `DeloadAdvisorTests` pass unchanged with `fitbodTests` on the large phone.

## Hints

- `evaluate` is near line 86 of `PlateauDetector.swift` and fills its window near line 125; `hasRPECreep` is near line 258.
- The Sig-2 loop is near line 191 of `DeloadAdvisor.swift`.
- `SeriesBuilder.buildPoints` and `workoutPoints` in `fitbod/Progress/SeriesBuilder.swift` group logs by `Session.id`, as T58 and T13 did.
