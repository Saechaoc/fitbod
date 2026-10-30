---
id: T61
title: A zero suggestion reads as no suggestion
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Sessions/WhyThisWeightSheet.swift, fitbod/Sessions/PrescriptionWeightCell.swift, new:fitbodTests/ZeroSuggestionTests.swift]
---

# T61: A zero suggestion reads as no suggestion

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F33, which the T09 worker found in the workout logger.
T09 made a prescribed weight of 0 show the weight field's empty placeholder, which VoiceOver reads as "none".
Two places still show a 0 as a real value.
For an exercise with no history, WHY opens a sheet whose button reads "Use 0 ▸", and Use then leaves the field empty.
A bodyweight exercise in calibration with no added load shows the read-only range "0 - 0 lb".

## Target

- The Use button in `fitbod/Sessions/WhyThisWeightSheet.swift`.
- The read-only calibrating range in `fitbod/Sessions/PrescriptionWeightCell.swift`.

## Change

1. When the suggested weight is 0, the WHY sheet does not offer Use; its explanation and Override stay.
2. A calibrating range whose ends are both 0 shows the same empty placeholder as a weight of 0, and VoiceOver reads it as "none".
3. Suggestions and ranges above 0 look and work as today.

## Constraints

- Do not change how prescriptions or ranges are computed.

## Ownership

You may edit the files in `owns`, plus logger tests your change breaks.
Ask before you edit anything else.

## Repro first

Write unit tests first, in `fitbodTests/ZeroSuggestionTests.swift`, pulling out small pure functions if you need to:
- The WHY sheet offers Use for a suggestion above 0, and not for 0.
- A range of 0 to 0 shows the placeholder, and a range above 0 shows its numbers.

Both fail today.

## Observable acceptance

- The repro tests pass.
- `WhyThisWeightControlUITests` and `PrescriptionWeightCellBRUUITests` pass on the small phone.
- `fitbodTests` passes.
- A screenshot of the WHY sheet for an exercise with no history is in `screens/`.

## Hints

- The sheet's "Use … ▸" button is near line 461 of `WhyThisWeightSheet.swift`.
- The read-only range is near line 87 of `PrescriptionWeightCell.swift`, and `weightDescription` there already reads "none" for an empty weight.
