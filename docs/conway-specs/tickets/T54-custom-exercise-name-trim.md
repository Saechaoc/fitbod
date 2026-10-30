---
id: T54
title: Custom exercise names save without outer spaces
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/ExerciseLibrary/CustomExerciseDraft.swift, fitbodTests/CustomExerciseDraftTests.swift]
---

# T54: Custom exercise names save without outer spaces

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F16, which the T03 worker read from the code and recorded in the run log.
The custom exercise editor checks the name with `CustomExerciseDraft.isValid`, which trims spaces and line breaks before it checks that the name is not empty.
Saving does not trim.
`materialize(into:allMuscles:)` and `updateExisting(in:allMuscles:)` store the name as typed, both in `name` and in the search key `canonicalName`.
So a name typed as "Zercher Squat " (with the space a keyboard suggestion adds) is saved as "Zercher Squat " and "zercher squat ", and a leading space shows as an indent wherever the name is shown.

## Target

- `CustomExerciseDraft.materialize(into:allMuscles:)` and `CustomExerciseDraft.updateExisting(in:allMuscles:)` in `fitbod/ExerciseLibrary/CustomExerciseDraft.swift`.

## Change

1. Saving a new or an edited custom exercise stores the name without leading or trailing spaces and line breaks, in both `name` and `canonicalName`.
2. Spaces inside the name stay as typed.
3. The editor's name field keeps showing what the user typed until they save.
4. No screen changes, and names saved before this change stay as they are.

## Constraints

- No schema change, and no migration of stored names.
- `canonicalName` stays lowercased and diacritic-folded as today; only the trimming is new.
- Do not change `isValid` or the editor's unsaved-changes check (`snapshot()`).

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

Add unit tests first to `fitbodTests/CustomExerciseDraftTests.swift`, next to `materializeInsertsExerciseAndStimuli`, with an in-memory `ModelContainer` set up the same way:
- A new draft named " Zercher Squat " with one primary muscle.
  After `materialize`, the exercise's `name` is "Zercher Squat" and its `canonicalName` is "zercher squat".
- An existing custom exercise whose draft is edited to " Zercher Squat ".
  After `updateExisting`, it has the same two values.

Today both tests fail, because both values keep the spaces.

## Observable acceptance

- The repro tests pass.
- `CustomExerciseDraftTests` passes.
- `fitbodTests` passes on the large phone.

## Hints

- `isValid` near line 162 already trims with `trimmingCharacters(in: .whitespacesAndNewlines)`.
- T03 (`062467f`) trims the search text when the no-match state opens the editor, in `ExerciseLibraryView.openNewCustom(named:)`.
