---
id: T112
title: Exercise history shows its workouts again
phase: 2
items: []
depends_on: [T96]
size: M
sim: both
owns: [fitbod/ExerciseLibrary/ExerciseHistoryView.swift, fitbod/ExerciseLibrary/IntentFilterChipRow.swift, new:fitbodUITests/ExerciseHistoryRowsUITests.swift]
---

# T112: Exercise history shows its workouts again

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F229 to F231, which T96's worker found once VIEW ALL HISTORY started opening the history.

- Every workout row in an exercise's history is blank: only the date section headers show, and the rows are missing from the screen and from the accessibility tree.
  Since T94, each section's `ForEach` id is the workout's id, and so is the id of the section's one row, so SwiftUI drops the row.
- On the small phone at default text, the intent chip "STRENGTH · 6" breaks as "STRENGT" over "H · 6", and the stat label "SESSIONS · 30D" wraps onto two lines.
- A row's "★ PR" chip can never show, because the rows are built with `isPR: false`, a placeholder for PR detection that never came.

## Target

- The history list's sections and rows, the stat strip and the row PR chip in `fitbod/ExerciseLibrary/ExerciseHistoryView.swift`.
- The chips in `fitbod/ExerciseLibrary/IntentFilterChipRow.swift`.

## Change

1. Every workout in an exercise's history shows its row: date line, intent chip, e1RM, TOP line and set chips.
   Keep T94's rule of one row per workout.
2. Each workout's date shows once, not in both the section header and the row.
3. A row whose workout set a PR shows "★ PR", by the same rule T96's "PRs · 30d" count uses.
4. On the small phone at default text and at AX3, every intent chip and stat label keeps its words whole.

## Constraints

- Keep T96's navigation on Library's stack, its "PRs · 30d" count and its state handling.
- T34 later renames "Sessions · 30d" to "Workouts · 30d", so the stat label must also fit that longer text.
- No change to how PRs are detected.

## Ownership

You may edit the files in `owns`, plus exercise history and Library tests your change breaks.
Ask before you edit anything else.

## Repro first

On both phones, with the T13 progress-history seed:

- Open an exercise's history through VIEW ALL HISTORY, and assert that the first workout's row shows its e1RM and set chips.
  It fails today.
- Assert that a workout which set a PR shows "★ PR" in its row.
  It fails today.
- On the small phone at default text, assert with the shared `readText` that the "STRENGTH" chip and the "Sessions · 30d" label each break only between words.

## Observable acceptance

- The repro tests pass on both phones.
- `SwipeBackUITests`, `HistoryPRCountTests` and the exercise history suites pass, the UI tests on both phones.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of the history at default text and AX3 on both phones are in `screens/`.

## Hints

- The sections are near `ExerciseHistoryView.swift:202-204`, `DateGroup` near line 396, and `isPR: false` near line 481.
- T96 added `ExerciseHistoryView.prs30d(from:now:)`, which replays the shown sets through `PRDetector.check`.
- T96's diagnosis and its reverted experiment, which keyed the sections by `\.dateKey`, are in the main checkout's `docs/conway-specs/evidence/T96/findings/`.
