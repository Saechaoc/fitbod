---
id: T120
title: New Block's undo toast stays small, and its duration steppers say what they change
phase: 3
items: []
depends_on: [T105]
size: M
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbodUITests/BlockTemplateCatalogUITests.swift, new:fitbodUITests/NewBlockToastAndDurationUITests.swift]
---

# T120: New Block's undo toast stays small, and its duration steppers say what they change

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F258, F260 and F261, which T105's worker found in New Block.

- After a phase is deleted, the undo toast, "Phase deleted | UNDO", fills the height between the top and bottom bars as a translucent panel with a hairline down its middle, over the whole screen for as long as it shows.
  Its divider is a `Rectangle` with a width and no height, so the toast takes all the height the screen offers.
- The Edit Block Duration sheet's steppers read only "−" and "+" to VoiceOver, while T105 named the phase editor's, such as "Increase weeks".
- At AX3, a slow 41pt scroll drag that started in the leading margin, 12pt left of a phase card, opened that card's phase editor in one of T105's runs.

## Target

- `NewBlockUndoToast` and the duration sheet in `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. The undo toast is one line tall: its text and UNDO with their padding, and its divider as tall as that line, wherever it shows.
2. Each duration sheet stepper reads its phase, its stat and its direction, such as "Increase Accumulation weeks", with the value, as the phase editor's do.
3. A scroll that starts beside a phase card never opens the card's editor, and a tap on the card still does.
   First try to make it happen three times at AX3; if it never does, record "not reproduced" for this item in `notes.md` and change nothing for it.

## Constraints

- Keep T105's revealed Delete, VoiceOver names, chart summary and drag as they are.
- Keep the toast's text, UNDO, timing and place.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
`BlockTemplateCatalogUITests` finds the duration steppers by their "−" and "+" labels, so move it to their new names.
Ask before you edit anything else.

## Repro first

On the small phone, in `NewBlockToastAndDurationUITests`:

- Delete a phase, and assert that the undo toast is less than 80pt tall.
  It fills the screen's height today.
- Open Edit Block Duration, and assert that a stepper's label names its phase and stat.
  It reads "+" today.
- At AX3, drag slowly from the leading margin beside a phase card to scroll, and assert that no phase editor opens; save what happened in `notes.md` either way.

## Observable acceptance

- The repro tests pass on the small phone.
- `NewBlockModalUITests`, `NewBlockLayoutUITests`, `PhaseRowsVoiceOverUITests` and `BlockTemplateCatalogUITests` pass on the small phone.
- `fitbodTests` passes, including the six New Block guardrail suites.
- Screenshots of the toast after a delete, and of the duration sheet, on the small phone, are in `screens/`.

## Hints

- `NewBlockUndoToast` is near `BlockBuilderView.swift:2830`, and its divider is the `Rectangle` with `.frame(width: NewBlockScreenTokens.rule)`.
- The duration sheet builds one `NewBlockSheetStepperRow` per phase; T105 gave that row a `stat:` parameter.
- T105's notes in `docs/conway-specs/evidence/T105/notes.md` describe the scroll drag that opened an editor, and `screens/T105-delete-tapped-small-default-light.png` shows the toast.
- The comment above `BlockTemplateCatalogUITests.openDurationSheet` says `UITestNavigation.topSheet(in:)` misses half-height sheets; since T101 it finds them, so the test can use it (finding F268).
