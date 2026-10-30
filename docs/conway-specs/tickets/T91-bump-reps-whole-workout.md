---
id: T91
title: Bump reps read the whole workout
phase: 1
items: []
depends_on: [T84]
size: S
sim: large
owns: [fitbod/Sessions/SessionFactory.swift, fitbod/Sessions/PreviousMatchingIntent.swift, new:fitbodTests/LastWorkoutRepsAcrossLogsTests.swift]
---

# T91: Bump reps read the whole workout

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F116, which the T84 worker found by reading the code; nobody has reproduced it yet.
`SessionFactory.lastSessionWorkingReps` walks the exercise's logs one at a time, newest workout first, and returns the working reps of the first log that has any.
When a finished workout logged the exercise twice, both logs share the workout's start time, so either can come first, and the other log's sets are left out.
Double progression decides its weight bump from those reps, so the bump can depend on which log comes first.
T84 fixed the same cause in `PreviousMatchingIntent.fetchTopWorkingSet`.

This is also finding F117.
Inside one log, `fetchTopWorkingSet` picks the top set with `max(by:)` over the log's sets, which SwiftData returns in no fixed order.
Two working sets at the same top weight, such as 100 lb × 8 and 100 lb × 6, can then give either set's reps.

## Target

- `lastSessionWorkingReps` in `fitbod/Sessions/SessionFactory.swift`.
- The pick inside one log in `fetchTopWorkingSet`, in `fitbod/Sessions/PreviousMatchingIntent.swift`.

## Change

1. `lastSessionWorkingReps` reads the newest finished workout with the matching intent once, across all of its logs of the exercise.
   It returns those working sets' reps in log order, then set order.
2. A workout whose logs have no working set is still skipped, and the walk back stops after five workouts, where today it stops after five logs.
3. In `fetchTopWorkingSet`, on a tie in weight inside one log, the earlier set (lower `orderIndex`) wins, as the earlier log already wins a tie across logs.
4. Everything else stays as it is: the intent and finished-workout rules, both signatures, and the hit's fields.

## Constraints

- Keep both functions' signatures; `SessionExerciseCard` and `SessionFactory` call `lastSessionWorkingReps`, and five callers use `fetchTopWorkingSet`.
- Do not change the progression strategies.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/LastWorkoutRepsAcrossLogsTests.swift`:

- Log a finished workout that logs the exercise twice, 100 lb × 10 and 10 in the first log, then 100 lb × 8 in the second, and assert that `lastSessionWorkingReps` returns [10, 10, 8].
  Run it with each log saved first; at least one order fails today.
- Log a finished workout whose one log has set 1 at 100 lb × 8 and set 2 at 100 lb × 6, insert set 2 first, and assert that the hit's reps are 8.
  Change 3 makes the pick independent of SwiftData's order, so it applies even if this test passes before the fix; say so in `notes.md` if it does.

## Observable acceptance

- The repro tests pass.
- `WhyUsesFinishedWorkoutsTests` and `PreviousTopSetAcrossLogsTests` pass.
- `fitbodTests` passes on the large phone.

## Hints

- `lastSessionWorkingReps` is near `SessionFactory.swift:565`, and it sorts logs by their workout's start time near line 596.
- T84 groups an exercise's logs by workout in `fetchTopWorkingSet`, near `PreviousMatchingIntent.swift:120-140`; share that grouping with `lastSessionWorkingReps` instead of writing another copy.
- Swift's `max(by:)` keeps the first of equal elements, so sorting a log's working sets by `orderIndex` first makes the earlier set win.
