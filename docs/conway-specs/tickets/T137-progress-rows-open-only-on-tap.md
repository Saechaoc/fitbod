---
id: T137
title: Progress's rows open only on a tap
phase: 3
items: []
depends_on: [T106]
size: S
sim: small
owns: [fitbod/Progress/ProgressHomeView.swift, new:fitbodUITests/ProgressRowsTapOnlyUITests.swift]
---

# T137: Progress's rows open only on a tap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F320, which T106's worker found by reading the code.

- Progress's own rows, built by `ProgressHomeView.progressRow` (Workouts, the recent exercises, Weekly Tonnage, Personal Records and This week vs last week), are full-width `.plain` buttons.
  So a sideways drag or an edge swipe on Progress that starts on one of them opens it, as T106 found on Program, History, the PR list and Library.
- Other full-width `.plain` rows that open a screen may do the same.

## Target

- `progressRow` in `fitbod/Progress/ProgressHomeView.swift`.

## Change

1. Progress's rows use T106's `.bruRow` style, so only a tap opens them.
2. A tap still opens a row at once, and a vertical scroll that starts on a row still scrolls.
3. `notes.md` lists every other full-width `.plain` row button in the app that opens a screen, with its file and line, for the coordinator to route.

## Constraints

- Keep each row's look and its pressed state.
- Keep T18's edge swipe on pushed screens.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with `ProgressHistorySeed`'s seed:

- Drag from a Progress row's left edge 200pt to the right, and assert that no screen opened.
  It opens the row today; record the result in `notes.md` if it does not.
- Tap the same row, and assert that it opens.

## Observable acceptance

- The repro tests pass on the small phone.
- `SwipeBackUITests` and the Progress suites that open these rows pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- `.bruRow` is in `fitbod/Design/BRURowButtonStyle.swift`.
- T106's sideways-drag tests in `fitbodUITests/SwipeBackUITests.swift` show the drag and the checks.
