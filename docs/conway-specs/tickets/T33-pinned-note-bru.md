---
id: T33
title: Pinned Note sheet in BRU
phase: 2
items: [42]
depends_on: [T07, T31]
size: M
sim: small
owns: [fitbod/Sessions/PinnedNoteSheet.swift, fitbodTests/BRUGrepAuditTests.swift, fitbodTests/Phase3BRUGrepAuditTests.swift, new:fitbodUITests/PinnedNoteSheetBRUUITests.swift]
---

# T33: Pinned Note sheet in BRU

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In the workout logger, open an exercise's menu and choose "Edit Pinned Note".
The sheet is stock iOS: a `Form` with rounded cells, the system navigation bar, the title "Pinned Note", and system Cancel and Save buttons.
The workout notes sheet next to it is already BRU.

## Target

`fitbod/Sessions/PinnedNoteSheet.swift`.

## Change

1. Rebuild the sheet to look and work like `WorkoutNotesSheet`, unless T31's `export-diff.md` shows a newer design for it.
2. The header is a `BRUHeaderBar` with "CANCEL", "PINNED NOTE" and "SAVE".
3. The note is a bordered BRU text editor on the paper background, with a short muted hint under it: "Note for this exercise".
4. Remove `PinnedNoteSheet.swift` from the exclusion lists in `BRUGrepAuditTests` and `Phase3BRUGrepAuditTests`, so the BRU audits cover it.

## Constraints

- Keep T07's behavior exactly: the sheet edits a local copy, SAVE writes it, and CANCEL and swipe-down throw it away.
- An empty note still saves as no note, so the pinned note capsule hides.
- Keep the menu entry and the capsule that open the sheet as they are.

## Ownership

You may edit the files in `owns`, plus notes tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with the demo seed, open the Pinned Note sheet from an exercise's menu in the logger:

- Assert that no navigation bar exists in the sheet.
- Assert that the BRU header's "CANCEL" and "SAVE" exist.

Both fail today.

## Observable acceptance

- The repro test passes on the small phone.
- A UI test types a note, taps SAVE, and sees the capsule show the note.
- `NoteSheetsUITests` passes on the small phone, and `NotesPersistenceTests` passes in `fitbodTests`.
- Both BRU audit suites pass with the file no longer excluded.
- Screenshots of the sheet in light and dark mode, at default text and AX3, are in `screens/`.

## Hints

- `WorkoutNotesSheet.swift` is the model to copy: it hides the system bar and puts `BRUHeaderBar` in a top safe-area inset.
- The menu entry is "Edit Pinned Note" in `SessionExerciseCard.swift`, and the logger presents the sheet from `SessionLoggerView.swift`.
- `PinnedNoteSheet.swift` is excluded near `BRUGrepAuditTests.swift:44` and near `Phase3BRUGrepAuditTests.swift:93`.
