---
id: T97
title: Why this weight explains RPE autoregulation's calibrating suggestions
phase: 2
items: []
depends_on: [T89]
size: S
sim: both
owns: [fitbod/Prescription/RPEAutoregStrategy.swift, fitbod/Sessions/WhyThisWeightSheet.swift, new:fitbodTests/CalibratingStepCopyTests.swift]
---

# T97: Why this weight explains RPE autoregulation's calibrating suggestions

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F137 and F138, which the T89 worker found.

- While RPE autoregulation calibrates from the last session, it leaves step 02's computed line empty.
  Step 02 then falls back to double progression's "Weight holds.", even when the suggestion differs from the last session's weight.
- When the last session's top set has no RPE, RPE autoregulation suggests nothing, by design.
  Step 01 shows that last session, but step 02 still reads "Weight holds." and step 03 reads "No prior data - log a set to begin calibrating."

## Target

- The two calibrating paths in `fitbod/Prescription/RPEAutoregStrategy.swift`.
- `step02Body` in `fitbod/Sessions/WhyThisWeightSheet.swift`.

## Change

1. When RPE autoregulation calibrates from the last session, step 02 shows how it got the weight, in the same shape as the calibrated path's line: the e1RM from the last session, the percentage for the target reps and RPE, and the raw target.
2. When the last session has no RPE, step 02 reads "Last session has no RPE to calibrate from. Log one on this set.", and step 03 reads "Choose a starting weight."
   The suggestion stays empty, as it is today.
3. "Weight holds." stays only for double progression when the weight holds.
4. Everything else stays as it is, including every suggested weight and range.

## Constraints

- Keep `PrescriptionExplanation`'s fields; fill `computedLine` and `roundedLine` instead of adding new ones.
- Do not change any suggested weight.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/CalibratingStepCopyTests.swift`, build RPE autoregulation explanations for a set calibrating from 110 lb × 8 @ RPE 8 and for one whose last set has no RPE, and assert the step 02 and step 03 text the sheet shows for each.
  Both fail today.
- With T80's calibrating seed on the small phone, open Why this weight and save a screenshot of its steps.

## Observable acceptance

- The repro tests pass.
- `WhySheetInputsTests`, `WhyThisWeightControlUITests` and `WhyThisWeightSheetBRUUITests` pass, the unit tests with `fitbodTests` on the large phone and the UI tests on the small phone.
- The steps screenshot is in `screens/`.

## Hints

- The calibrating paths are near `RPEAutoregStrategy.swift:108-170`; the calibrated path's computed line is near line 89.
- `step02Body` is near `WhyThisWeightSheet.swift:355`.
- T80's seed is `UITestNavigation.calibratingSet`; use the T01 launch helpers.
