---
id: T114
title: The weekly recap measures last week against its plan
phase: 3
items: []
depends_on: [T103]
size: S
sim: small
owns: [fitbod/Fatigue/WeeklyRecapSheet.swift, new:fitbodTests/WeeklyRecapTargetTests.swift]
---

# T114: The weekly recap measures last week against its plan

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F242, which T103's worker found.
The weekly recap's sessions chip reads "N / N sessions", because its target is the number of sessions logged.
So the logged count always meets the target, and the headline always reads "A strong week.", however little was trained.

## Target

- The sessions target, the sessions chip and the headline in `fitbod/Fatigue/WeeklyRecapSheet.swift`.

## Change

1. The target is the number of training days that the block active last week planned for that week.
2. With a target, the chip reads "N / M sessions", and the headline compares N with M, as it does today.
3. With no block active last week, the chip reads "N sessions" with no target, and the headline never claims a target was met: it follows the sessions and PRs alone.
4. Put the target and the headline choice in functions a unit test can call.

## Constraints

- Keep T103's rule that empty workouts do not count, and its "Across M routines" line.
- Keep the recap's other numbers and copy as they are.
- Read the plan from the block as it is; no schema change.

## Ownership

You may edit the files in `owns`, plus weekly recap tests your change breaks.
Ask before you edit anything else.

## Repro first

In `WeeklyRecapTargetTests`:

- With a block that planned four training days last week and one finished workout, assert that the target is 4 and the headline is not "A strong week.".
  It fails today.
- With no block last week and one finished workout, assert that the chip reads "1 session" and names no target.
  It fails today.

## Observable acceptance

- The repro tests pass with `fitbodTests` on the large phone.
- `WeeklyRecapUITests`, `EmptyWorkoutCountsUITests` and `HistoryAndTodayUITests` pass on the small phone.
- Screenshots of a recap with a target and one without, on the small phone, are in `screens/`.

## Hints

- `sessionsTarget` returns `sessionsLogged` near `WeeklyRecapSheet.swift:234`, and `coverHeadline` is near line 209.
- A block's training days are read through its `trainingDaysJoined` and `TrainingDaysWriter`.
- T103's seeds in `DemoWorkoutSeed.swift` set last week's workouts; T87's `-fitbod-seed-ended-block-recap` has a block that ended last week.
