---
id: T84
title: The previous top set reads the whole workout
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Sessions/PreviousMatchingIntent.swift, new:fitbodTests/PreviousTopSetAcrossLogsTests.swift]
---

# T84: The previous top set reads the whole workout

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F90, which the T72 worker found by reading the code; nobody has reproduced it yet.
`PreviousMatchingIntent.fetchTopWorkingSet` walks the exercise's logs one at a time, newest workout first, and returns the heaviest working set of the first log that has one.
When a finished workout logged the exercise twice, both logs share the workout's start time, so either can come first.
The lighter log can then stand in for that workout's top set.
That set seeds new workouts' weights, fills the logger's PREVIOUS column and feeds Why this weight.
T58 and T72 fixed the same cause in the progress series and the plateau checks.

## Target

- `fetchTopWorkingSet` in `fitbod/Sessions/PreviousMatchingIntent.swift`.

## Change

1. A finished workout that logged the exercise more than once counts once, and its top set is the heaviest working set across all of its logs.
2. On a tie in weight, the earlier log's set wins.
3. A workout whose logs have no working set is still skipped, and the walk back still stops after five workouts.
4. Everything else stays as it is: the intent and finished-workout rules, the excluded session, and the hit's fields.

## Constraints

- Keep `fetchTopWorkingSet`'s signature and `PreviousMatchingIntentHit` as they are; six callers use them.
- Do not change the progression strategies or `SessionFactory`.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/PreviousTopSetAcrossLogsTests.swift`, log a finished workout that logs the exercise twice, 100 lb × 5 and then 80 lb × 8, and assert that the hit's weight is 100.
Run it with the heavy log first and with the heavy log second; at least one order fails today.

## Observable acceptance

- The repro tests pass.
- `fitbodTests` passes on the large phone.

## Hints

- `fetchTopWorkingSet` is near line 88 of `PreviousMatchingIntent.swift`; it sorts logs by their workout's start time near line 124.
- `PlateauDetector.finishedSessionLogs`, from T72, groups an exercise's logs by workout the same way.
