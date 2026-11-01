---
id: T111
title: Session editor rows are announced, removable and easy to hit
phase: 3
items: []
depends_on: [T29, T110]
size: M
sim: small
owns: [fitbod/Routines/RoutineExerciseCard.swift, fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/PerSetOverrideRow.swift, fitbodUITests/PrescriptionEditorUITests.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, new:fitbodUITests/SessionEditorRowsUITests.swift]
---

# T111: Session editor rows are announced, removable and easy to hit

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F217, F219 and F220, which T29's worker found in the session editor.

- T29 stopped the exercise row from merging its parts, so its name is now a plain text, and VoiceOver no longer says that tapping it opens the exercise's editor.
- The exercise rows' swipe actions do nothing, because the editor lists its rows in a stack, not a `List`.
  So an exercise can be removed only from its long-press menu, which nothing on screen shows.
- The tempo fields are 40pt wide and about 17pt tall at default text, under the 44pt target.
- Since T110, nothing shows `PerSetOverrideRow`: only its own previews and two tests that read its source refer to it (finding F256, from the coordinator's review of T110-ext).

## Target

- The exercise row's name, swipe actions and menus in `fitbod/Routines/RoutineExerciseCard.swift`.
- The tempo fields in `fitbod/Routines/PrescriptionEditorRow.swift`.

## Change

1. VoiceOver reads an exercise's name as a button, and says whether its editor is open.
2. The swipe actions that cannot fire go.
3. Each exercise can be removed without a long press, through a visible REMOVE control in its open editor, which asks before it removes, as the long-press Remove does today.
4. Each tempo field has a touch target at least 44pt tall, with its look unchanged at default text.
5. Delete `fitbod/Routines/PerSetOverrideRow.swift`, with `RoutineBuilderBRUCopyTests.topSetRowUsesBruSignal` and its line in `Phase3BRUGrepAuditTests`' file list.

## Constraints

- Keep T29's MOVE chip, its menu and the per-part identifiers.
- Keep the long-press menu as it is.
- Tests that find the name by its identifier keep working, so update their element queries rather than their checks.

## Ownership

You may edit the files in `owns`, plus session editor tests your change breaks, and `Phase3BRUGrepAuditTests` for change 5.
Ask before you edit anything else.

## Repro first

On the small phone, in `SessionEditorRowsUITests`:

- Assert that the first exercise's name element has the button trait.
- Open the first exercise's editor, and assert that a REMOVE control exists in it.
- Assert that each tempo field is at least 44pt tall.

All of these fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- `SessionEditorPolishUITests`, `PrescriptionEditorUITests`, `RoutineBuilderBRUUITests` and `MilestoneOneJourneyUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of an open exercise editor with its REMOVE control, at default text and AX3, are in `screens/`.

## Hints

- The name is near `RoutineExerciseCard.swift:166`, and the long-press menu's Remove is in its `contextMenu`.
- `PrescriptionEditorUITests` and `MilestoneOneJourneyUITests` find the name through `app.staticTexts` with the identifier `routine.exercise.name.<n>`.
- The tempo fields are built by `tempoField(index:placeholder:width:)` in `PrescriptionEditorRow.swift`.
- T29's notes and screenshots are in `docs/conway-specs/evidence/T29/`.
- T110 left a duplicated phrase in `PrescriptionEditorRow.swift`'s header comment, "the tempo fields / and the tempo fields drop their fixed widths"; fix it while you edit that file (finding F-ext-8 from the review of T110-ext).
