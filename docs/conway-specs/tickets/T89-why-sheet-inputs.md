---
id: T89
title: Why this weight shows the set's targets, its last session and full-width steps
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Sessions/PrescriptionWeightCell.swift, fitbod/Sessions/SetRow.swift, fitbod/Sessions/WhyThisWeightSheet.swift, fitbod/Prescription/DoubleProgressionStrategy.swift, fitbod/Prescription/RPEAutoregStrategy.swift, fitbodUITests/WhyThisWeightControlUITests.swift, new:fitbodTests/WhySheetInputsTests.swift]
---

# T89: Why this weight shows the set's targets, its last session and full-width steps

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F103, F104 and F105, which the T79 worker found on Why this weight.

- The logger opens the sheet from `PrescriptionWeightCell` without the set's reps, RPE or set type.
  So the hero always shows dashes for REPS and RPE and reads "TOP SET", step 01's reps-in-reserve line never shows, and step 02 never reads "Target @ RPE n".
  The demo seed's Push A sheet shows it, though its set has a previous 100 × 5 at RPE 8.
- Steps 01 and 02 say "No prior data" for a lift with history when its last top working set was logged without an RPE.
  The double-progression and RPE autoregulation strategies build no last-session line without an RPE.
- The steps block takes its width from its content, so short step text centers the steps and insets their closing 2pt rule.

## Target

- The sheet's call site in `fitbod/Sessions/PrescriptionWeightCell.swift`, and `SetRow`, which builds the cell.
- `lastSessionLine` in `fitbod/Prescription/DoubleProgressionStrategy.swift` and `fitbod/Prescription/RPEAutoregStrategy.swift`.
- `stepsBlock` in `fitbod/Sessions/WhyThisWeightSheet.swift`.

## Change

1. The logger passes the set's rep range, target RPE and set type into Why this weight, so the hero shows them, for example "×8–12" for an 8 to 12 range, and steps 01 and 02 use them.
2. A last top set logged without an RPE still shows as the last session in step 01, with its weight, reps and date and no RPE, and step 02 no longer says "No prior data" for it.
3. The steps block fills the sheet's width: its numerals line up with the section head, and its closing rule spans the sheet, whatever the text's length.
4. Suggestions, prescription math, and T61's and T79's rules for a suggestion of 0 stay as they are.

## Constraints

- Change only how a last session is described, not what the strategies prescribe.
- `WhyThisWeightSheet`'s `reps` may change from one number to the set's rep range; keep its other parameters as they are.

## Ownership

You may edit the files in `owns`, plus Why-this-weight and logger tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/WhySheetInputsTests.swift`, build a double-progression explanation from a last top set logged without an RPE, and assert that its last-session line names that set's weight, reps and date.
  It fails today.
- In `fitbodUITests/WhyThisWeightControlUITests.swift`, with the demo seed on the small phone, open Push A's Why this weight and assert that the hero shows the set's rep range and target RPE, not dashes.
  It fails today.

## Observable acceptance

- The repro tests pass, the UI test on the small phone.
- `WhyThisWeightControlUITests`, `WhyThisWeightSheetBRUUITests` and `PrescriptionWeightCellBRUUITests` pass on the small phone.
- `fitbodTests` passes on the large phone.
- Screenshots of Push A's sheet on the small phone, hero and steps, before and after the fix, are in `screens/`.

## Hints

- The cell opens the sheet near line 158 of `PrescriptionWeightCell.swift`; `SetRow` builds the cell near line 136 and has the set and its exercise.
- `WhyThisWeightSheet.init` takes `reps`, `rpe` and `setTypeLabel` near line 86.
- `SessionExercise` holds the range as `targetRepsLow` and `targetRepsHigh`, and the target RPE as `targetRPE`.
- `lastSessionLine` is near line 116 of `DoubleProgressionStrategy.swift` and near line 188 of `RPEAutoregStrategy.swift`.
- `stepsBlock` is near line 253 of `WhyThisWeightSheet.swift`.
