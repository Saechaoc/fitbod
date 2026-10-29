---
id: T05
title: Dirty editors resist swipe-down
phase: 1
items: [3, 25]
depends_on: [T01]
size: M
sim: both
owns: [fitbod/Routines/RoutineBuilderView.swift, fitbod/ExerciseLibrary/CustomExerciseEditor.swift, fitbod/Periodization/BlockBuilderView.swift, new:fitbodUITests/DirtySheetDismissUITests.swift]
---

# T05: Dirty editors resist swipe-down

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The session editor, the custom exercise editor and New Block close on a swipe-down even with unsaved changes, and the changes are lost without a warning.
Their Back and Cancel buttons ask first, but the swipe does not.
New Block's CANCEL does not ask at all.
The discard dialogs have no visible way back, because iOS 26 hides cancel buttons.

## Target

- The session editor sheet, `fitbod/Routines/RoutineBuilderView.swift`.
- The custom exercise editor, `fitbod/ExerciseLibrary/CustomExerciseEditor.swift`.
- New Block, `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. While an editor has unsaved changes, a swipe-down does not close it.
2. With no changes, a swipe-down still closes it.
3. The session editor and the custom exercise editor use their existing dirty flags.
4. New Block gets a dirty flag: the draft differs from the state it opened with.
5. New Block's CANCEL asks "Discard this block?" when the draft is dirty, with "Discard" and a visible "Keep editing".
   With no changes, CANCEL closes at once.
6. Every discard dialog in these three editors shows a visible "Keep editing" button without the cancel role.
7. List in `notes.md` every other sheet that edits data, with whether it tracks changes.
   Fix none of them here.

## Constraints

- Use SwiftUI's standard interactive-dismiss modifier, not a UIKit presentation delegate (see "Dirty editors and swipe-down" in [../tradeoffs.md](../tradeoffs.md)).
- Leave the notes sheets alone; T07 makes swipe-down discard there on purpose.
- New Block edits must keep the six guardrail suites passing.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks and guardrail suites whose pinned copy you change on purpose.
Ask before you edit anything else.

## Repro first

On both phones, with the T01 sheet swipe helper:

- Open the session editor, change its name, swipe down from the sheet's top edge, and assert that the editor is still on screen.
- Do the same for the custom exercise editor after changing its name.
- Do the same for New Block after typing a block name.

All three fail today.
Also write the no-change case for each: swipe down and assert that the sheet closed.

## Observable acceptance

- All six swipe tests pass on both phones.
- New Block's CANCEL asks only when the draft is dirty, and "Keep editing" keeps the edits.
- The existing Back and Cancel dialogs still discard when the user confirms.
- The six New Block guardrail suites pass.
- `fitbodTests` passes.

## Hints

- `RoutineBuilderView.swift` near line 522 has `hasUnsavedChanges`, with dialogs near lines 177, 236 and 245.
- `CustomExerciseEditor.swift` near line 252 has `isDirty`, with a dialog near line 137.
- `BlockBuilderView`'s `cancel()` dismisses at once today.
