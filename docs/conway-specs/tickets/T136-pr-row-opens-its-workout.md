---
id: T136
title: A PR row opens the workout it was set in
phase: 3
items: []
depends_on: [T106]
size: S
sim: small
owns: [fitbod/Progress/ExercisePRsView.swift, fitbod/Progress/ProgressHomeView.swift, new:fitbodUITests/PRRowOpensWorkoutUITests.swift]
---

# T136: A PR row opens the workout it was set in

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F319, which T106's worker found.

- Tapping a row in Progress → Personal Records pushes `placeholderPRsDestination`, a stub that reads "Session of <date>".
  It hides the navigation bar and has no ‹ BACK, so only an edge swipe leaves it.
- Its comment calls it a v1 placeholder, because no completed-session screen existed then.
  History's rows now open the real workout summary through `SessionHistoryRoute.summary(sessionID:)`.

## Target

- `placeholderPRsDestination` and `PRsRouteDestination` near `fitbod/Progress/ExercisePRsView.swift:555`, and where `ProgressHomeView` attaches them.

## Change

1. A PR row opens the summary of the workout it was set in, the same screen a History row opens, with its ‹ BACK.
2. The placeholder destination goes.
3. VoiceOver reads the row as a button, as it does today.

## Constraints

- Keep T85's row text and T106's `.bruRow` style.
- Keep the PR row's identifiers, so `PRListAndSeriesUITests` and `SwipeBackUITests` keep finding the rows.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else, such as the History summary's own files.

## Repro first

On the small phone, with `ProgressHistorySeed`'s seed:

- Open Progress, then Personal Records, tap the first PR row, and assert that the workout summary opens and shows a ‹ BACK.
  It opens the stub today.

## Observable acceptance

- The repro test passes on the small phone, and ‹ BACK returns to Personal Records.
- `PRListAndSeriesUITests` and `SwipeBackUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of the opened summary at default text and AX3 on the small phone are in `screens/`.

## Hints

- The PR row's route carries the PR set's `setEntryID`; its `SetEntry` leads to its `Session`.
- T106's notes in the main checkout's `docs/conway-specs/evidence/T106/notes.md` describe the stub.
