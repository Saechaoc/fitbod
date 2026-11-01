---
id: T131
title: The session editor's UI tests fit the test budgets
phase: 4
items: []
depends_on: []
size: S
sim: small
owns: [fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/SessionEditorPolishUITests.swift, fitbodUITests/PrescriptionEditorUITests.swift, fitbodUITests/PerSetOverridesRemovedUITests.swift]
---

# T131: The session editor's UI tests fit the test budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F302 and F338, from T38's and T111's timed runs on the small phone.

- `EditorSwipeDismissUITests.testSessionEditorResistsSwipeDownOnlyWithUnsavedEdits` takes about 50 s, and `testNewBlockBuilderResistsSwipeDownOnlyWithUnsavedEdits` about 40 s.
- `SessionEditorPolishUITests.testKeepSessionClosesTheArchiveDialog` takes about 65 s, and T111 timed its other cases at 34 to 74 s: `testMoveOpensTheReorderMenu` 54 s, `testRowIdentifiersAreUnique` 34 s, `testRestReadsAsMinutesAndSeconds` 38 s, `testTogglesUseTheBRUStyle` 45 s, `testEditorAtDefaultText` 51 s and `testEditorAtAX3` 74 s.
- `PrescriptionEditorUITests`' four cases take 37 to 65 s, and `PerSetOverridesRemovedUITests.testSessionEditorOffersNoPerSetOverrides` about 39 s.
- Each of them reaches the session editor through Today or Program and several screens first.
- The guide's case budget is 30 s.

## Target

- The cases named in Problem.

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

- Run the four suites three times on the small phone, and record each case's durations in `notes.md` as the "before" numbers.

## Observable acceptance

- Three runs of the four suites on the small phone, with each case's durations before and after in `notes.md`.
- Every case fits its budget, or `notes.md` explains the time it still takes.
- `fitbodTests` passes.

## Hints

- One shared way to reach the session editor faster, used by every case, saves the most; T111's notes in `docs/conway-specs/evidence/T111/notes.md` list its durations under Test performance.
- T38's notes in `docs/conway-specs/evidence/T38/notes.md`, under Test performance, list the durations.
