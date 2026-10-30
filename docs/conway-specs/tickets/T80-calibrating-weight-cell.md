---
id: T80
title: A calibrating set's weight can be typed, and shows once chosen
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Sessions/PrescriptionWeightCell.swift, fitbod/App/RootView.swift, new:fitbod/App/CalibratingSetSeed.swift, new:fitbodUITests/CalibratingWeightUITests.swift, new:fitbodTests/CalibratingWeightCellTests.swift]
---

# T80: A calibrating set's weight can be typed, and shows once chosen

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F78 and F79, which the T61 worker found, plus what the coordinator found while checking them.
With RPE autoregulation, an exercise with some history, but fewer sets than calibration needs, gets a calibrating range such as "95 – 105 lb".
`PrescriptionWeightCell` then draws the range as read-only text, with no weight field.

- Override in Why this weight closes the sheet and focuses nothing, because the cell has no field.
  Decision 8 says Override focuses the weight field.
- So the lifter cannot type a calibrating set's weight.
  The set holds last session's weight, which `SessionFactory` seeds, and the cell never shows it.
- A completed calibrating set still shows the range, not the weight it logged.
- No seed or UI test reaches a calibrating range.
  The range text may not fit `SetRow`'s 60pt weight column at default text (unverified).

## Target

- The calibrating-range branch of `fitbod/Sessions/PrescriptionWeightCell.swift`.
- A new DEBUG seed that reaches a calibrating range, registered in `fitbod/App/RootView.swift` like the other seeds.

## Change

1. On an open calibrating set, Override closes the sheet, turns the cell into the weight field holding the set's weight, and focuses it, as decision 8 says.
2. An open calibrating set shows its weight in place of the range once it has a manual override or its weight equals the suggestion, so a typed weight or Use keeps showing for the rest of the workout.
3. A completed calibrating set shows the weight it logged, never the range.
4. Otherwise an open calibrating set still shows its range, and a 0-to-0 range still shows T61's dash.
5. The range shows whole inside the weight column on the small phone, at default text and at AX3.
6. Sets without a range behave exactly as they do today.

See "Calibrating weight cell" in [../tradeoffs.md](../tradeoffs.md).

## Constraints

- Make no schema change; use what `SetEntry` already stores, such as `weight` and `wasManualOverride`.
- Do not change prescription math, the range, or how `SessionFactory` seeds sets.
- The seed is DEBUG-only, does nothing without its launch argument, and follows the other seeds in `fitbod/App/`.

## Ownership

You may edit the files in `owns`, plus weight-cell and Why-this-weight tests your change breaks.
Ask before you edit anything else.

## Repro first

- Write `fitbod/App/CalibratingSetSeed.swift` with its own launch argument.
  It seeds a session whose only exercise uses RPE autoregulation and has one earlier workout, so starting the session shows a calibrating range.
  The earlier weight differs from the suggestion, so an untouched set shows the range.
- In `fitbodUITests/CalibratingWeightUITests.swift`, on the small phone with that seed:
  - Open WHY on the first open set, tap Override, and assert that a weight field has focus.
  - Type a weight, and assert that the cell shows it.
  - Complete a set, and assert that its cell shows the weight it logged.
  - At default text and at AX3, assert that the range text lies inside the weight column and is not cut off.

  The first three fail today.
- In `fitbodTests/CalibratingWeightCellTests.swift`, cover changes 2 to 4 for a cell with a range.

## Observable acceptance

- The repro tests pass, the UI tests on the small phone.
- `WhyThisWeightControlUITests`, `PrescriptionWeightCellBRUUITests` and `WhyThisWeightSheetBRUUITests` pass on the small phone.
- `fitbodTests` passes on the large phone.
- Screenshots of a calibrating set before Override, after a typed weight and completed, at default text and AX3 on the small phone, are in `screens/`.

## Hints

- The read-only range branch is near line 90 of `PrescriptionWeightCell.swift`.
  Override sets `focusAfterSheet` near line 161, which focuses the field near line 278.
- `RPEAutoregStrategy` builds the range near line 139, until an exercise has `minCalibrationSets` sets.
- `SessionFactory` seeds a set's weight from the previous set near line 297.
- The seeds are registered near line 274 of `RootView.swift`.
