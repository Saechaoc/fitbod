---
id: T93
title: Deload advice and session comparison read every log of a workout in order
phase: 1
items: []
depends_on: [T92]
size: S
sim: large
owns: [fitbod/Fatigue/DeloadAdvisor.swift, fitbod/Progress/SessionComparator.swift, new:fitbodTests/WholeWorkoutReadersTests.swift]
---

# T93: Deload advice and session comparison read every log of a workout in order

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F123 and F124, which the T92 worker found by reading the code; nobody has reproduced them yet.

- The deload advisor's RPE creep signal (Sig-2) picks each workout's top set from its logs' sets in the order SwiftData returns them, and the first set read wins a tie in e1RM.
  Two sets with the same e1RM and different RPEs can then flip the signal.
- `SessionComparator.compare` makes one row per log of the current workout, and `findPriorMatch` takes the first log of the exercise it meets in the prior workout, in SwiftData's order.
  When a workout logged the exercise twice, the comparison has two rows with one exercise id, which `SessionComparisonView` uses as its `ForEach` id, and each row compares against an arbitrary prior log.

T72, T84, T91 and T92 fixed the same causes in other readers.

## Target

- Sig-2 in `DeloadAdvisor.evaluate`, in `fitbod/Fatigue/DeloadAdvisor.swift`.
- `compare` and `findPriorMatch` in `fitbod/Progress/SessionComparator.swift`.

## Change

1. Sig-2 reads each workout's logs in log order and each log's sets in set order (`orderIndex` both times), so the earlier set wins a tie in e1RM.
2. `compare` makes one row per exercise in the current workout, in the order of its first log, and reads the row's top set across all of that exercise's logs in the workout.
3. The row's prior side reads all of the exercise's logs in the most recent matching workout together, and compares against their top set.
4. Everything else stays as it is: the 14-day window, the routine and intent match, the top-set rule (highest e1RM, then weight, then latest completion) and the row's fields.

## Constraints

- Keep `compare`'s signature, `SessionComparisonRow` and `SessionComparisonView` as they are.
  `findPriorMatch` may change shape; update `SessionComparatorTests` to match.
- Keep the deload advisor's public API and thresholds.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/WholeWorkoutReadersTests.swift`:

- Log three finished workouts at 100 lb × 5 whose top-set RPEs are 7, 7.5 and a tie in the third: set 1 at RPE 7.5 and set 2 at RPE 8.5, with set 2 inserted first.
  Assert that the RPE creep signal does not fire, because the earlier set's 7.5 gives a creep of 0.5.
  Change 1 makes the pick independent of SwiftData's order, so it applies even if this test passes before the fix; say so in `notes.md` if it does.
- Log a current workout that logs the exercise twice, 100 lb × 5 and then 110 lb × 5, and a prior workout in the window that logs it twice, 105 lb × 5 and then 95 lb × 5.
  Assert that `compare` returns one row for the exercise, with 110 × 5 this week and 105 × 5 last week.
  It fails today.

## Observable acceptance

- The repro tests pass.
- `DeloadAdvisorTests`, `OneSamplePerWorkoutTests` and `SessionComparatorTests` pass.
- `fitbodTests` passes on the large phone.

## Hints

- Sig-2 starts near `DeloadAdvisor.swift:191`, and its top-set loop flattens the logs near line 212.
- `compare` is near `SessionComparator.swift:121` and `findPriorMatch` near line 174; `SessionComparisonView.swift:68` keys its rows by `exerciseID`.
- `PreviousMatchingIntent.lastWorkingSets` (T91) and `ExerciseHistoryView.groupedByDate` (T92) read a workout's sets across its logs in log order and then set order.
