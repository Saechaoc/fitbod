---
id: T106
title: A sideways drag on a row does not open it
phase: 3
items: []
depends_on: [T18]
size: M
sim: both
owns: [new:fitbod/Design/BRURowButtonStyle.swift, fitbod/Periodization/ProgramView.swift, fitbod/Sessions/SessionHistoryRow.swift, fitbod/Progress/ExercisePRsView.swift, fitbod/ExerciseLibrary/ExerciseRow.swift, fitbodUITests/SwipeBackUITests.swift]
---

# T106: A sideways drag on a row does not open it

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F183, which T18's worker found.
A sideways drag that starts and ends on a full-width row button presses it: Program's template rows, History's rows, the PR rows and Library's rows.
So an edge swipe on a root screen that starts on a row opens that row, while the same swipe on a pushed screen goes back.
T28's worker also saw a History row break its weekday, "WED" as "WE" over "D", at AX3 on the large phone (finding F187).

## Target

- The row buttons in `ProgramTemplateRow`, `SessionHistoryRow`, the PR rows of `ExercisePRsView` and `ExerciseRow`.

## Change

1. A row opens only on a tap: a touch that moves more than about 10pt before it lifts does not open it.
2. A tap still opens the row at once, and a vertical scroll that starts on a row still scrolls.
3. One shared row button style does this, and all four rows use it.
4. VoiceOver's activate still opens each row.
5. At AX3 on both phones, a History row keeps its weekday whole.

## Constraints

- Keep each row's look and its pressed state.
- Keep T18's edge swipe on pushed screens as it is.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- On Program's template list, History, an exercise's PR list and Library, drag from a row's left edge 200pt to the right, and assert that no screen opened.
  Each opens its row today.
- Tap each of those rows, and assert that it opens.
- At AX3 on the large phone, assert with the shared `readText` that a History row's weekday reads whole on one line.

## Observable acceptance

- The repro tests pass on the phones they name.
- `SwipeBackUITests`, `ProgramEmptyStateAX3UITests`, `SessionHistoryBRUUITests` and `PRListAndSeriesUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- The rows are `ProgramTemplateRow` near `ProgramView.swift:1401`, `SessionHistoryRow`, the row buttons near `ExercisePRsView.swift:142` and `ExerciseRow`.
- A `PrimitiveButtonStyle` whose gesture fires only when the drag stayed short can keep a button's look and pressed state.
- T18's notes in the main checkout's `docs/conway-specs/evidence/T18/notes.md` describe the drag.
