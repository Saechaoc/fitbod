---
id: T125
title: The logger shows a set's plates while its weight is being entered
phase: 3
items: []
depends_on: [T107]
size: M
sim: both
owns: [fitbod/Sessions/SetRow.swift, fitbod/Sessions/PrescriptionWeightCell.swift, fitbod/Sessions/PlateStackDisclosure.swift, new:fitbodUITests/LoggerPlateStackUITests.swift]
---

# T125: The logger shows a set's plates while its weight is being entered

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F286, which T107's worker found.

- In the logger, a set's plate stack (`PlateStackDisclosure`) never opens.
  `SetRow` toggles it from an `onTapGesture` on the weight cell, near `SetRow.swift:155`, but `PrescriptionWeightCell`'s own `onTapGesture`, near its line 166, and its `TextField`, near its line 133, take every tap first.
- So the logger, the one place a lifter loads a bar, never shows which plates make a set's weight; only the warm-up rows show plates.

## Target

- The weight cell and the plate disclosure in `fitbod/Sessions/SetRow.swift`, `PrescriptionWeightCell.swift` and `PlateStackDisclosure.swift`.

## Change

1. While a set's weight field has focus, its plate stack shows under the set, for the weight in the field, and it follows the value as the lifter types.
2. When the field loses focus, the plate stack hides.
3. A tap on the weight field still focuses it for entry, as it does today.
4. Remove the tap toggle that never fires, so one rule decides when the plates show.
5. VoiceOver reads the plates when they show, as the warm-up rows' plates read.

This follows "Plates in the logger" in [../tradeoffs.md](../tradeoffs.md): showing the plates during entry keeps "tap the weight, see the plates" without a hidden gesture or a new control.

## Constraints

- Keep the weight field's entry, its focus, its explanation sheet and its manual-override flag as they are.
- Keep `PlateStackViz`, its 0.6 logger scale and T107's labels as they are.
- With no weight, or a weight the plates cannot make, show what `PlateStackDisclosure` shows for that today.

## Ownership

You may edit the files in `owns`, plus logger UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, in `LoggerPlateStackUITests`:

- Tap a work set's weight field, and assert that its plate stack shows under the set.
  Nothing shows today.

## Observable acceptance

- The repro test passes on both phones, and also shows the stack follow a typed weight and hide when the field loses focus.
- `SessionLoggerBRUUITests`, `WorkoutLoggerJourneyUITests` and `PlateScreensFitUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of a set's plates while its weight is being entered, at default text and AX3 on the small phone, are in `screens/`.

## Hints

- T107's notes in the main checkout's `docs/conway-specs/evidence/T107/notes.md` record the taps its probe tried.
- `PlateStackLayoutTests` already renders the logger's 0.6-scale stack at default, XXXL and AX3.
- T39, in phase 4, changes the same weight field so that focus selects its whole value; keep the focus handling simple enough for that.
