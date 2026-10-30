---
id: T49
title: Holding an RPE chip opens the decimal picker
phase: 1
items: []
depends_on: [T01]
size: M
sim: both
owns: [fitbod/Sessions/InlineRPEChipRow.swift, fitbod/Routines/RoutineExerciseCard.swift, new:fitbodUITests/RPEDecimalHoldUITests.swift]
---

# T49: Holding an RPE chip opens the decimal picker

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F1 from the coordinator's review of `704f5c4..1ae54b0`, recorded in the run log.
Since `2529e90` (review item 6), the session editor sets Target RPE with the logger's chip row: the whole numbers 6 to 10, plus NO TARGET.
The row says a long press on a chip opens the decimal RPE picker, so a half step such as 8.5 can be set.
That never happens.
The chip's `Button` swallows its `.onLongPressGesture`, and in the session editor the exercise card's press-and-hold menu, which covers the whole card, takes the hold first.
A stored 8.5 also shows chip "8" as selected, and a tap on it saves 8.0.
Before `2529e90` the editor's RPE field took decimals, so half-step targets were lost in the fix.
The quick-task run noted that the logger's set-type menu may also take the hold.

## Target

- The RPE chip row, `fitbod/Sessions/InlineRPEChipRow.swift`, used by the session editor and the workout logger.
- The exercise card's press-and-hold menu in the session editor, `fitbod/Routines/RoutineExerciseCard.swift`.

## Change

1. Holding any RPE chip for the long-press time opens the decimal RPE picker with that chip's value selected, in the session editor and in the workout logger.
2. The picker's value is written: a half step such as 8.5 becomes the exercise's target RPE in the editor, and the set's RPE in the logger.
3. The exercise card's press-and-hold menu still opens from the card's title row, with the same items, but a hold inside the open prescription editor no longer opens it.
4. A stored half step is shown as that value, for example 8.5, on screen and to VoiceOver, never as a selected whole-number chip.
5. A tap on a whole-number chip still sets that whole number, and NO TARGET still clears the target.

## Constraints

- Keep the chips' look, their 44pt targets and their accessibility labels "RPE 6" to "RPE 10".
- Keep the NO TARGET chip and the logger's five chips without it.
- No schema change: `targetRPE` and the set's RPE stay `Double?`.
- T06 is skipped: the editor keeps the chip row that `2529e90` shipped, not a toggle and a stepper.
- If the logger's set-type menu takes the hold, its file is outside `owns`, so ask before you edit it.

## Ownership

You may edit the files in `owns`, plus existing UI suites your change breaks, such as `PrescriptionEditorUITests`.
Ask before you edit anything else.

## Repro first

On the small phone, with the T01 helpers:
- Open the session editor on a seeded session, expand an exercise, hold the "8" RPE chip, and assert that the decimal picker shows.
  Today the card's menu shows instead.
- Start the seeded workout, hold an RPE chip on a set, and assert that the decimal picker shows.
- Pick 8.5 in the editor, save, reopen the session, and assert that 8.5 shows and that chip "8" is not selected.

## Observable acceptance

- The repro tests pass on both phones.
- The card's press-and-hold menu still opens from the title row, and its Remove item still works.
- `PrescriptionEditorUITests`, `SessionLoggerBRUUITests` and `WorkoutLoggerJourneyUITests` pass on both phones.
- `fitbodTests` passes.
- Screenshots of the open picker in the editor and in the logger, at default text on both phones, are in `screens/`.

## Hints

- Branch `undine` holds `c35e0eb`, a fix the quick-task run made after its review but never merged.
  It moves the card's menu to the title row and watches the hold with a simultaneous `LongPressGesture`.
  Read it with `git show c35e0eb`, but write the change yourself; workers never cherry-pick.
- The quick-task run's note says that in the logger the set-type menu still takes the hold, so check the logger on both phones.
