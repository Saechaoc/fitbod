---
id: T92
title: History and plateau checks read every set of a workout in order
phase: 1
items: []
depends_on: [T91]
size: S
sim: large
owns: [fitbod/Fatigue/PlateauDetector.swift, fitbod/ExerciseLibrary/ExerciseHistoryView.swift, new:fitbodTests/WorkoutSetsInOrderTests.swift]
---

# T92: History and plateau checks read every set of a workout in order

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F121 and F122, which the T91 worker found by reading the code; nobody has reproduced them yet.

- `PlateauDetector.topSet(in:)` reads a workout's logs and each log's sets in the order SwiftData returns them, and the first set read wins a tie in e1RM.
  The top set's RPE feeds the RPE creep check, so two sets with the same e1RM and different RPEs can flip it.
- `ExerciseHistoryView.groupedByDate` groups an exercise's sets by workout, but it reads the top set, the e1RM and the chips from the first log's sets only.
  When a workout logged the exercise twice, its history row leaves out the other log's sets.

T72, T84 and T91 fixed the same causes in the plateau window, the previous top set and the bump reps.

## Target

- `topSet(in:)` in `fitbod/Fatigue/PlateauDetector.swift`.
- `groupedByDate` in `fitbod/ExerciseLibrary/ExerciseHistoryView.swift`.

## Change

1. `topSet(in:)` reads the logs in log order and each log's sets in set order (`orderIndex` both times), so on a tie in e1RM the earlier set wins.
2. A history row reads every log of the exercise in its workout.
   Its top set, e1RM and chips come from all of those working sets, in log order and then set order.
3. Everything else stays as it is, including each row's date, intent, labels, and how the top set and e1RM are chosen.

## Constraints

- Keep the history row's look and copy.
- Keep `PlateauDetector`'s public API.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/WorkoutSetsInOrderTests.swift`:

- Log a finished workout that logs the exercise twice, 100 lb × 5 in the first log and 110 lb × 5 in the second, and assert that its history row's top set is 110 × 5 and that its chips list both logs' sets in order.
  Move the grouping into an internal static function the test can call if it needs one.
  It fails today.
- Log a finished workout whose one log has set 1 at 100 lb × 5 @ 8 and set 2 at 100 lb × 5 @ 9, insert set 2 first, and assert that the top set `PlateauDetector` reads for it has RPE 8.
  Make `topSet(in:)` internal if the test needs it.
  Change 1 makes the pick independent of SwiftData's order, so it applies even if this test passes before the fix; say so in `notes.md` if it does.

## Observable acceptance

- The repro tests pass.
- `OneSamplePerWorkoutTests`, `PlateauUsesFinishedWorkoutsTests`, `ExerciseHistoryIntentSplitTests` and `ExerciseHistoryViewCopyTests` pass.
- `fitbodTests` passes on the large phone.

## Hints

- `topSet(in:)` is near `PlateauDetector.swift:256`, and `finishedSessionLogs` near line 219 appends each workout's logs in fetch order.
- `groupedByDate` is near `ExerciseHistoryView.swift:287`, and it reads `firstPair.sessionExercise.sets` near line 305.
- `PreviousMatchingIntent.lastWorkingSets`, from T91, reads a workout's working sets across its logs in log order and then set order.
