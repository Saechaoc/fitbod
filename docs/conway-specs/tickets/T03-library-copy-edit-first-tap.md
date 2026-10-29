---
id: T03
title: Library Copy and Edit open on the first tap
phase: 1
items: [1, 19]
depends_on: [T01]
size: S
sim: small
owns: [fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/ExerciseLibrary/ExerciseLibraryView.swift, fitbod/ExerciseLibrary/CustomExerciseDraft.swift, new:fitbodUITests/CustomExerciseEntryUITests.swift]
---

# T03: Library Copy and Edit open on the first tap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On an exercise detail screen, COPY on a built-in exercise and EDIT on a custom one open a blank sheet on the first tap.
The user has to swipe it away and tap again.
In the Library, CREATE CUSTOM EXERCISE after a search with no match opens the editor with an empty name, so the search text is lost.

## Target

- COPY and EDIT on the exercise detail screen, `fitbod/ExerciseLibrary/ExerciseDetailView.swift`.
- CREATE CUSTOM EXERCISE in the Library's no-match state, `fitbod/ExerciseLibrary/ExerciseLibraryView.swift`.

## Change

1. The editor sheet is driven by the draft itself, so the first tap always shows a filled editor.
   Remove the separate "is presenting" flag.
2. COPY shows the copied exercise's details on the first tap, exactly what the second tap shows today.
3. EDIT shows the custom exercise's current name, image and details on the first tap.
4. CREATE CUSTOM EXERCISE from the no-match state puts the trimmed search text in the name field.
5. The draft survives re-renders of the parent while the sheet is open, so typed input is never wiped.

## Constraints

- Do not restyle the editor; T32 rebuilds it in BRU.
- Keep the `customExercise.name` accessibility identifier.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open "Barbell Bench Press - Medium Grip", tap COPY once, and assert that `customExercise.name` exists within 3 seconds.
- Create a custom exercise, open it, tap EDIT once, and assert that the name field shows its name within 3 seconds.
- Search the Library for "Zercher Probe", tap CREATE CUSTOM EXERCISE, and assert that the name field holds "Zercher Probe".

All three fail today.

## Observable acceptance

- The three repro tests pass on the small phone.
- Cancelling and reopening the editor still works.
- Saving a copy creates a new custom exercise, and saving an edit changes the existing one.
- `fitbodTests` passes.

## Hints

- Cause of item 1: `ExerciseDetailView.swift` near lines 146-168 presents the sheet from a boolean and reads the draft only inside the sheet closure, so the first sheet is built with the old empty value.
- The review's fix uses an item-driven sheet.
  `CustomExerciseDraft` is a final class (`CustomExerciseDraft.swift` near line 82), so it can be identified by its object identity.
- Cause of item 19: `ExerciseLibraryView.swift` near line 117 builds a fresh draft inside the sheet closure.
