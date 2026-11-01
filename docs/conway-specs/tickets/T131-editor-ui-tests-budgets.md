---
id: T131
title: The editor swipe and session editor UI tests fit the test budgets
phase: 4
items: []
depends_on: []
size: S
sim: small
owns: [fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/SessionEditorPolishUITests.swift]
---

# T131: The editor swipe and session editor UI tests fit the test budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

This is finding F302, from T38's timed runs on the small phone.

- `EditorSwipeDismissUITests.testSessionEditorResistsSwipeDownOnlyWithUnsavedEdits` takes about 50 s, and `testNewBlockBuilderResistsSwipeDownOnlyWithUnsavedEdits` about 40 s.
- `SessionEditorPolishUITests.testKeepSessionClosesTheArchiveDialog` takes about 65 s.
- The guide's case budget is 30 s.

## Target

- The three cases named in Problem.

## Change

1. Each case fits the 30 s case budget with the same assertions.
   Where one cannot, `notes.md` says what its time is spent on.
2. Steps the cases share live in one helper per suite, not in copies.

## Constraints

- Keep every assertion, and add no fixed sleeps.
- Change tests only; the app stays as it is.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else, such as `UITestNavigation.swift`.

## Repro first

- Run both suites three times on the small phone, and record each case's durations in `notes.md` as the "before" numbers.

## Observable acceptance

- Three runs of both suites on the small phone, with each case's durations before and after in `notes.md`.
- Every case fits its budget, or `notes.md` explains the time it still takes.
- `fitbodTests` passes.

## Hints

- T38's notes in the main checkout's `docs/conway-specs/evidence/T38/notes.md`, under Test performance, list the durations.
