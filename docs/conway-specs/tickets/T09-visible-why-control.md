---
id: T09
title: Visible WHY control, Use and Override
phase: 1
items: [4, 18]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Sessions/PrescriptionWeightCell.swift, fitbod/Sessions/SetRow.swift, fitbod/Sessions/WhyThisWeightSheet.swift, fitbodUITests/WhyThisWeightSheetBRUUITests.swift, fitbodUITests/PrescriptionWeightCellBRUUITests.swift]
---

# T09: Visible WHY control, Use and Override

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The Why-this-weight sheet opens only on a long press of the prescribed weight, and nobody can discover a long press.
When the sheet opens, the weight field keeps focus, so the keyboard stays up.
On the large phone the keyboard covers the "WHY THIS WEIGHT" section head, so `testWhyThisWeightSectionHeadVisible` fails.
Use does nothing, because no caller passes the Use callback.
Override only closes the sheet.
After a weight change, a small "M" badge lands against the reps value, so the row reads "185 M5".
An exercise with no history shows a weight of "0", which reads like a real target.

## Target

- The weight cell of each work set in the workout logger: `PrescriptionWeightCell`, inside `SetRow`.
- The sheet's Use and Override actions in `WhyThisWeightSheet`.

## Change

1. Each incomplete work set that has an explanation shows a small "WHY" text control in its weight cell (see "Visible WHY control" in [../tradeoffs.md](../tradeoffs.md)).
2. WHY has a 44pt target and fits the 390pt phone at default text and at AX3.
3. The weight cell has the VoiceOver action "Why this weight".
4. Tapping WHY dismisses the keyboard and opens the sheet (decision 8).
5. Use writes the suggested weight into the set, clears the set's manual-override flag and closes the sheet.
6. Override closes the sheet and focuses the weight field, with the keyboard up.
7. Remove the long press.
8. The "M" badge sits inside the weight cell's own width and never touches the reps column.
   Its VoiceOver label is "changed from prescription".
9. A prescribed weight of 0 means no prescription, so the field shows its empty placeholder (see "Empty prescribed weight").
10. Point the existing WhyThisWeight UI tests at WHY.
    Rename the long-press test so its name says WHY.

## Constraints

- Do not change what the sheet explains or how the suggested weight is computed.
- No schema change: `SetEntry` already has `wasManualOverride`.
- A parent tap gesture must not swallow WHY (see "Known traps" in the worker rules).

## Ownership

You may edit the files in `owns`, plus logger UI tests your change breaks.
Ask before you edit anything else.

## Repro first

With the demo seed, open the workout:

- On the small phone, assert that a WHY control exists on the first incomplete work set.
  It does not exist today.
- On the large phone, run the existing `testWhyThisWeightSectionHeadVisible` and watch it fail.
- Open the sheet the old way, tap Use, and assert that the weight field shows the suggested weight.
  It does not change today.
- Change a weight by hand, and assert that the badge frame is inside the weight cell frame and does not intersect the reps value.
- Add an exercise with no history to the workout, and assert that its weight field shows the placeholder, not "0".

## Observable acceptance

- Every repro test passes on both phones, rewritten to open the sheet through WHY.
- A UI test proves Override leaves the weight field focused with the keyboard up.
- `WhyThisWeightSheetBRUUITests`, `PrescriptionWeightCellBRUUITests`, `SessionLoggerBRUUITests` and `WorkoutLoggerJourneyUITests` pass on both phones.
- `ManualOverrideTests` passes with `fitbodTests`.
- Screenshots of a set row with WHY, at default text and AX3 on the small phone, are in `screens/`.

## Hints

- The long press is in `PrescriptionWeightCell.swift` near line 117, and `SetRow.swift` near line 129 adds a tap gesture on the same cell.
- `WhyThisWeightSheet.swift` calls its Use callback near lines 453-455.
  Only the preview near line 647 passes one, as a placeholder.
- `SetRow.swift` near line 127 fixes the weight cell to 60pt.
  `PrescriptionWeightCell.swift` gives the field a 60pt minimum width near line 83 and adds the badge after it near lines 105-112.
- The "0" comes from the cell's appear handler near lines 139-150, which copies a prescribed weight of 0 into the field.
