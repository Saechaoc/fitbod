---
id: T95
title: The deload banner and session comparison name their exercises steadily
phase: 1
items: []
depends_on: [T93]
size: S
sim: large
owns: [fitbod/Fatigue/DeloadAdvisor.swift, fitbod/Progress/SessionComparator.swift, new:fitbodTests/StableExerciseNamesTests.swift]
---

# T95: The deload banner and session comparison name their exercises steadily

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F127 and F128, which the T93 worker found by reading the code; nobody has reproduced them yet.

- When two exercises creep by the same RPE amount, the deload advisor's RPE creep signal names whichever one its Dictionary yields first.
  Swift seeds Dictionary order per launch, so the banner can name a different exercise each launch.
- `SessionComparator.compare` names each row with the live catalog name, or "" when there is none.
  Deleting a custom exercise (`ExerciseDeletion`) leaves its logs with no exercise, so its comparison row has an empty name.
  A renamed exercise shows its new name, while history shows the name it was logged under.

## Target

- The worst-creep pick in Sig-2 of `DeloadAdvisor.evaluate`, in `fitbod/Fatigue/DeloadAdvisor.swift`.
- The row name in `compare`, in `fitbod/Progress/SessionComparator.swift`.

## Change

1. On a tie in creep, the signal names the exercise whose last matched workout is the newest; on a further tie, the first by name.
2. Each comparison row takes its name from its first log's `displayName`: the name the workout logged it under, else the live name.
3. Everything else stays as it is, including the creep threshold, the banner copy and the row's other fields.

## Constraints

- Keep the deload advisor's public API and `SessionComparisonRow`'s fields.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodTests/StableExerciseNamesTests.swift`:

- Give two exercises the same creep of 1.0 over three workouts each, with squat's last workout newer than bench's, and assert that the signal names squat.
  Change 1 makes the name independent of Dictionary order, so it applies even if this test passes before the fix; say so in `notes.md` if it does.
- Log a workout of a custom exercise, delete the exercise with `ExerciseDeletion.delete`, and assert that its comparison row has the logged name.
  It fails today.

## Observable acceptance

- The repro tests pass.
- `DeloadAdvisorTests`, `DeloadAdvisoryBannerBRUTests`, `SessionComparatorTests` and `WholeWorkoutReadersTests` pass.
- `fitbodTests` passes on the large phone.

## Hints

- The worst-creep loop is near `DeloadAdvisor.swift:237-252`, over `perPair`, a Dictionary keyed by exercise and intent.
- The row name is near `SessionComparator.swift:153`, and `SessionExercise.displayName` is in `fitbod/Models/SessionExercise.swift`.
