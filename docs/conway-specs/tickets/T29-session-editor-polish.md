---
id: T29
title: Session editor polish
phase: 2
items: [12, 13, 17, 25]
depends_on: [T06]
size: L
sim: both
owns: [fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/SetRowsContainer.swift, fitbod/Routines/PerSetOverrideRow.swift, fitbod/Routines/RoutineExerciseCard.swift, fitbod/Routines/RoutineBuilderView.swift, new:fitbodUITests/SessionEditorPolishUITests.swift]
---

# T29: Session editor polish

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In the session editor, at default text on both phones, each exercise row shows "•••" where its number ("01") should be.

At AX3:

- The per-set overrides count is clipped at the right edge.
- The set labels ("S1", "S2") stay at a tiny fixed size while everything around them grows.
- "WORK" breaks as "WOR" over "K", and "+ ADD EXERCISE" breaks as "EXERCIS" over "E".
- "Track partial reps" is cut to "Track partial r…".

At every size:

- "Track tempo", "Track partial reps" and "Auto warm-up" are stock iOS switches that turn green.
- Rest time has three formats: "180S" in the exercise subtitle, "3 min rest" in the chip and "180s" in the stepper.
- The "⋮⋮" control looks like a drag handle, but it opens a menu.
  Its row also merges its children for accessibility, so element identifiers repeat.

## Target

The session editor: `RoutineBuilderView`, `RoutineExerciseCard`, `PrescriptionEditorRow`, `SetRowsContainer` and `PerSetOverrideRow`, all in `fitbod/Routines/`.

## Change

1. Every label scales with a `BRUFont` role; no label keeps a tiny fixed size.
2. At accessibility sizes, fixed column widths go away, and toggle labels wrap.
3. The overrides count is never clipped.
4. The exercise number shows "01" in full at every text size, on both phones.
5. "WORK" and "+ ADD EXERCISE" stay whole.
6. All three toggles use the `.bru` toggle style.
7. Rest time shows as minutes and seconds in the subtitle, the chip and the stepper, such as "3:00" (see "Rest time format" in [../tradeoffs.md](../tradeoffs.md)).
8. A labeled BRU "MOVE" control replaces "⋮⋮" and opens the same menu (see "Reorder control").
9. The exercise row stops merging its children, so each identifier is unique.

## Constraints

- Keep T06's reps and RPE controls exactly as they are.
- Do not change what the reorder menu does.

## Ownership

You may edit the files in `owns`, plus session editor tests your change breaks.
Ask before you edit anything else.

## Repro first

On both phones, open a session with two exercises in the session editor:

- At default text, assert that the first row's number frame is wider than the 28pt column that truncates it today, and save a screenshot.
- Turn on "Track tempo", sample the switch's pixels, and assert that they are not iOS green.
- With a 180-second rest, assert that the subtitle, the chip and the stepper each show "3:00".
- Assert that a "MOVE" control exists on each row and opens the reorder menu.
- Assert that each row's element identifiers match exactly one element.
- At AX3 on the small phone, save screenshots of the editor and write one line per defect in `notes.md`.

## Observable acceptance

- Every repro test passes on both phones.
- The AX3 screenshots show no clipped, truncated or mid-word labels.
- `RoutineBuilderBRUUITests` and `PrescriptionEditorUITests` pass on both phones.
- Screenshots of the editor at default text and AX3, in light and dark mode on the small phone, are in `screens/`.

## Hints

- The overrides label uses a one-line fixed-size layout near `PrescriptionEditorRow.swift:353-365`, and "Track partial reps" is near 299.
- The toggles are near `PrescriptionEditorRow.swift:249`, 298 and 314; `ExerciseDetailView` already uses the `.bru` style.
- The set label uses a fixed 10pt monospaced font in a 24pt column near `SetRowsContainer.swift:94-105`, and `PerSetOverrideRow.swift:39` uses the same font.
- The number is 26pt grotesk in a 28pt frame near `RoutineExerciseCard.swift:130-138`; "⋮⋮" is near 163, the merge near 177 and the subtitle's rest near 200.
- The chip's rest text is near `PrescriptionEditorRow.swift:95`, and the stepper's near 242.
- The rest timer already shows minutes and seconds, so reuse its formatter if it has one.
