---
id: T07
title: Notes sheets edit a local copy
phase: 1
items: [33, 41]
depends_on: [T01]
size: M
sim: small
owns: [fitbod/Sessions/WorkoutNotesSheet.swift, fitbod/Sessions/PerSetNoteSheet.swift, fitbod/Sessions/PinnedNoteSheet.swift, new:fitbodUITests/NotesSheetsUITests.swift]
---

# T07: Notes sheets edit a local copy

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The workout note, set note and pinned note sheets write straight to the model as the user types.
So CANCEL keeps whatever was typed.
The first work set's note is titled "SET 5 NOTE", because its number also counts the warm-ups.

## Target

The three notes sheets in `fitbod/Sessions/`: `WorkoutNotesSheet`, `PerSetNoteSheet` and `PinnedNoteSheet`.

## Change

1. Each sheet edits a local copy of the note (decision 4).
2. SAVE writes the copy to the model and closes the sheet.
3. CANCEL and swipe-down close the sheet and throw the copy away.
4. The set note title uses the set's display number from `SessionSetActions.displayNumber(of:)`, so the first work set reads "SET 1 NOTE".

## Constraints

- Change behavior only.
  `PinnedNoteSheet` keeps its stock look until T33 rebuilds it in BRU.
- The sheets must not resist swipe-down; swipe-down discards on purpose.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with the demo seed:

- Open the workout note, type "Probe", tap CANCEL, reopen, and assert the note is empty.
- Do the same for a set note and the pinned note.
- Open the workout note, type "Probe", swipe the sheet down, reopen, and assert the note is empty.
- Open the first work set's note and assert the title reads "SET 1 NOTE".

All of these fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- A UI test types a note, taps SAVE, reopens, and sees the saved text, for each of the three sheets.
- Editing an existing note and cancelling keeps the old text.
- `fitbodTests` passes.

## Hints

- `PerSetNoteSheet.swift` near line 72 numbers sets with the order index plus one, which counts warm-ups.
- `SetRow.swift` near lines 275-281 already uses `displayNumber(of:)`.
