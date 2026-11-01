---
id: T140
title: Removing an exercise by long press forgets its open editor, and REMOVE controls read normally to VoiceOver
phase: 3
items: []
depends_on: [T111]
size: S
sim: small
owns: [fitbod/Routines/RoutineBuilderView.swift, fitbod/Periodization/SplitDetailView.swift, fitbod/ExerciseLibrary/MuscleWeightRow.swift, fitbodUITests/SessionEditorRowsUITests.swift]
---

# T140: Removing an exercise by long press forgets its open editor, and REMOVE controls read normally to VoiceOver

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F337 and F339, which T111's worker found.

- The session editor keys an exercise's open editor by the row's address in `expandedExerciseIDs`.
  T111's REMOVE closes the row before removing it, but the long-press menu's Remove calls `RoutineBuilderView.removeExercise`, which never clears that key.
  So after removing an open exercise by long press, a later unsaved exercise at the same address can open by itself.
- T111 found that a label drawn with `.textCase(.uppercase)` reaches VoiceOver in capitals, even with an `.accessibilityLabel`, so it wrote its REMOVE's capitals in the copy instead.
  The routine screen's edit-mode REMOVE near `SplitDetailView.swift:650` and `MuscleWeightRow`'s REMOVE are built the old way.

## Target

- `removeExercise` near `fitbod/Routines/RoutineBuilderView.swift:650`.
- The REMOVE labels in `fitbod/Periodization/SplitDetailView.swift` and `fitbod/ExerciseLibrary/MuscleWeightRow.swift`.

## Change

1. Removing an exercise by any path clears its open-editor key, so no later exercise opens by itself.
2. Both REMOVE controls show "REMOVE" in capitals while VoiceOver reads "Remove" and the name, as T111's REMOVE does.

## Constraints

- Keep the long-press menu's Remove removing at once, as tradeoffs.md "Removing an exercise" says.
- Keep each control's look, size and identifier.

## Ownership

You may edit the files in `owns`, plus routine and custom exercise tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, in `SessionEditorRowsUITests`:

- Add two exercises to a new session, open the second one's editor, remove it from its long-press menu, add another exercise, and assert that the new exercise's editor is closed.
  Record in `notes.md` whether it opens by itself today.
- Assert that the routine screen's edit-mode REMOVE and a custom exercise's muscle REMOVE expose labels that start "Remove " with only the first letter capital.

## Observable acceptance

- The repro tests pass on the small phone.
- `SessionEditorRowsUITests`, `SessionEditorPolishUITests` and the custom exercise editor's suites pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T111's REMOVE in `fitbod/Routines/RoutineExerciseCard.swift` shows both patterns: it closes the row before removing, and it writes "REMOVE" in the copy rather than through `textCase`.
- T111's notes are in `docs/conway-specs/evidence/T111/notes.md`, under its findings F-T111-1 and F-T111-5.
