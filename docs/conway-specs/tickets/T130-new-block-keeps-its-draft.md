---
id: T130
title: New Block keeps the lifter's draft when the screen behind it redraws
phase: 3
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, new:fitbodUITests/BlockDraftKeepsUITests.swift]
---

# T130: New Block keeps the lifter's draft when the screen behind it redraws

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F300, which T38's worker found.
It loses the lifter's work, so treat it as a P1 defect.

- New Block opened from a preset (Use Preset, then a template) loses the preset the moment its name field takes focus.
  The name empties, SAVE DRAFT turns off, and the phases fall back to the blank block's, so Generic Strength Meso's TOTAL WEEKS goes from 8 to 5.
  It happens at default text and at AX3.
- `ProgramView` builds the draft inside its `fullScreenCover` closure (`BlockBuilderView(draft: BlockDraft.newBlock(), initialPreset: ...)`, near `ProgramView.swift:236`), and `BlockBuilderView` holds it as `@Bindable`.
  When `ProgramView` redraws, as it does when the keyboard comes up, the closure hands New Block a fresh blank draft.
  The preset was applied once, in `.task`, and is not applied again.
- The other presenters build their drafts the same way: the template row and EDIT BLOCK in `ProgramView`, and the builders in `RoutinesListView`, `BlockReviewView`, `BlockCard`, `BlockPickerMenu` and `TodayView`.
  A redraw behind any of them can replace the draft, and edits made before it are lost.

## Target

- How `BlockBuilderView` holds its draft, in `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. New Block and Edit Block keep the draft they opened with until they close.
   Focusing the name field, the keyboard, a text size change or any redraw of the screen behind them never replaces it.
2. This holds for every presenter named in Problem.
3. A preset's name, phases and total weeks stay after the name field takes focus, and edits made before a redraw stay after it.

## Constraints

- Fix it once, where the draft is held, and leave the presenters as they are.
  Ask first if the fix needs a presenter changed.
- Keep T38's and T105's New Block behavior, and SAVE DRAFT, CANCEL and the discard dialog as they are.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open Program, then Use Preset and Generic Strength Meso, tap the name field, and assert that the name still reads the preset's name and TOTAL WEEKS still reads 8.
  Both fail today.
- Open EDIT BLOCK on a draft block from Program, change a phase's weeks, tap the name field, and assert that the change stays.
  Record in `notes.md` whether it fails today.

## Observable acceptance

- The repro tests pass on the small phone.
- `NewBlockModalUITests`, `EditorSwipeDismissUITests` and `SmallFixesUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- `RoutineBuilderView` avoids the same trap by keeping its first draft in `@State` (`RoutineBuilderView.swift:114`); its comment says the host may build a fresh draft on every redraw.
- T38's notes in the main checkout's `docs/conway-specs/evidence/T38/notes.md`, under Findings, describe the probe.
