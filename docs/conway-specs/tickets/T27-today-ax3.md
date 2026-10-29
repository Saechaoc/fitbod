---
id: T27
title: Today at AX3
phase: 2
items: [46, 24, 25]
depends_on: [T02, T15]
size: M
sim: small
owns: [fitbod/Views/BlackSlabCTA.swift, fitbod/Views/ResumeWorkoutSlab.swift, fitbod/Views/LiftListRow.swift, new:fitbodUITests/TodayAX3UITests.swift]
---

# T27: Today at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On Today, at AX3 on the small phone:

- The start slab's meta line breaks as "EXER", "CISE", "S".
- The resume slab's "RESUME ▸" wraps its arrow to its own line.
- The lift list's number wraps "0" above "1" in a fixed 32pt column.
- The COMPOUND chip breaks as "COMPOUN" over "D".

At every size, the start slab says "1 EXERCISES" for one exercise.

## Target

- The meta line in `fitbod/Views/BlackSlabCTA.swift`.
- The pill in `fitbod/Views/ResumeWorkoutSlab.swift`.
- The number and the chip in `fitbod/Views/LiftListRow.swift`.

## Change

1. At accessibility sizes, the slab's meta line stacks its parts (exercises, sets and minutes) instead of breaking words.
2. The slab's counts use the T02 plural helper, such as "1 EXERCISE", "2 EXERCISES" and "1 SET".
3. "RESUME ▸" stays on one line.
   At accessibility sizes, the pill moves under the slab text if it does not fit beside it, as T15 did for the Program banner.
4. The lift list number shows "01" on one line at every text size.
5. The COMPOUND and WORK chips stay whole.
   At accessibility sizes, the row puts the chip under the exercise name.
6. At default text, Today looks as it does today.

## Constraints

- Use the `dynamicTypeSize.isAccessibilitySize` branch, as the worker rules say.
- T04 changed the resume slab's count, so keep its count rule as it is.

## Ownership

You may edit the files in `owns`, plus Today tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with the demo seed:

- With a session of one exercise, assert that the start slab shows "1 EXERCISE".
  It shows "1 EXERCISES" today.
- At AX3, assert with frame checks that the lift list number and the chip are each one line tall.
- At AX3, assert that the meta line's parts do not intersect each other.
- At AX3, with an unfinished workout, save a screenshot of the resume slab and record in `notes.md` whether the arrow sits on its own line.

## Observable acceptance

- Every repro test passes on the small phone.
- A screenshot shows "RESUME ▸" on one line at AX3.
- `HistoryAndTodayUITests` passes on the small phone.
- Screenshots of the start slab, the resume slab and the lift list, at default text and AX3, are in `screens/`.

## Hints

- The meta line is near `BlackSlabCTA.swift:84-110`.
- The pill is near `ResumeWorkoutSlab.swift:119`, and T15 fixed the same pill in `ResumeWorkoutBanner.swift`.
- The number is near `LiftListRow.swift:59-64`, a 22pt grotesk in a fixed 32pt frame, and the chip is near line 81.
