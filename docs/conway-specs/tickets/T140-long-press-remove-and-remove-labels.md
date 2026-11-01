---
id: T140
title: Removing an exercise by long press forgets its open editor
phase: 3
items: []
depends_on: [T111]
size: S
sim: small
owns: [fitbod/Routines/RoutineBuilderView.swift]
---

# T140: Removing an exercise by long press forgets its open editor

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F339, which T111's worker found.
Finding F337, how two REMOVE labels reach VoiceOver, is dropped: `docs/DEVELOPMENT.md` asks for uppercase through `.textCase(.uppercase)`.

- The session editor keys an exercise's open editor by the row's address in `expandedExerciseIDs`.
  T111's REMOVE closes the row before removing it, but the long-press menu's Remove calls `RoutineBuilderView.removeExercise`, which never clears that key.
  So after removing an open exercise by long press, a later unsaved exercise at the same address can open by itself.

## Target

- `removeExercise` near `fitbod/Routines/RoutineBuilderView.swift:650`.

## Change

1. Removing an exercise by any path clears its open-editor key, so no later exercise opens by itself.

## Constraints

- Keep the long-press menu's Remove removing at once, as tradeoffs.md "Removing an exercise" says.

## Ownership

You may edit the files in `owns`, plus session editor tests your change breaks.
Commit no new UI test: the user asked for fewer UI tests (T143), and this bug costs no data.
Ask before you edit anything else.

## Repro first

On the small phone, with a throwaway UI test that you do not commit:

- Add two exercises to a new session, open the second one's editor, remove it from its long-press menu, add another exercise, and assert that the new exercise's editor is closed.
  Record in `notes.md` whether it opens by itself today.

## Observable acceptance

- The throwaway repro passes on the small phone after the change; `notes.md` records both runs.
- `SessionEditorRowsUITests` passes on the small phone (T143 deleted `SessionEditorPolishUITests`).
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T111's REMOVE in `fitbod/Routines/RoutineExerciseCard.swift` closes the row before it removes the exercise.
- T111's notes are in `docs/conway-specs/evidence/T111/notes.md`, under its finding F-T111-5.
