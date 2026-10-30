---
id: T79
title: Why this weight with no history shows no zero weight
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Sessions/WhyThisWeightSheet.swift, fitbodTests/ZeroSuggestionTests.swift, fitbodUITests/WhyThisWeightControlUITests.swift]
---

# T79: Why this weight with no history shows no zero weight

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F76 and F77, which the T61 worker found on Why this weight for an exercise with no history.
T61 (`737958b`) stopped the sheet offering "Use 0 ▸", but the rest of the sheet still treats the suggestion of 0 as a real weight.

- The hero shows a 128pt "0 LB" as the RECOMMENDED weight, and VoiceOver reads "Recommended weight 0 lb".
- Step 03 reads "ROUNDED TO PLATE ? LB" over a body of "0".
  `incrementText()` finds no plate size in the no-history `roundedLine`, so it returns "?".
- Step 02 says the sheet is "starting at prescribed weight", although there is no prescribed weight.

"Empty prescribed weight" in [../tradeoffs.md](../tradeoffs.md) says a weight of 0 is no prescription.

## Target

- The hero, step 02 and step 03 of `fitbod/Sessions/WhyThisWeightSheet.swift`, for a suggestion of 0.

## Change

1. For a suggestion of 0, the hero shows the empty weight field's dash in place of the number and unit, and its VoiceOver label starts "Recommended weight: none".
2. For a suggestion of 0, step 02 reads `"No prior data \u{2014} choose a starting weight."`, in the style of the other step 02 lines.
3. For a suggestion of 0, the sheet leaves out step 03, since there is nothing to round.
4. Step 03 never shows "?": when it cannot read a plate size, its label leaves the size out.
5. A suggestion above 0 reads exactly as it does today.

## Constraints

- Do not change prescription math or the strategies' explanation text in `fitbod/Prescription/`.
- Keep T61's rule that a suggestion of 0 offers no Use.

## Ownership

You may edit the files in `owns`, plus Why-this-weight tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/ZeroSuggestionTests.swift`, for T61's no-history explanation, assert that the hero shows the dash, its VoiceOver label starts "Recommended weight: none", step 02 reads the new sentence, and the sheet has no step 03.
  Add a case whose `roundedLine` has no plate size, and assert that step 03's label has no "?".
  These fail today.
- In `fitbodUITests/WhyThisWeightControlUITests.swift`, extend `testNoHistoryWhyOffersNoUse` to assert that the sheet shows no "0" hero.

## Observable acceptance

- The repro tests pass, the UI test on the small phone.
- `WhyThisWeightControlUITests` and `WhyThisWeightSheetBRUUITests` pass on the small phone.
- `fitbodTests` passes on the large phone.
- Screenshots of the no-history sheet on the small phone at default text, before and after the fix, showing the hero and scrolled to show steps 02 and 03, are in `screens/`.

## Hints

- `heroSlab` is near line 131 and `heroAccessibilityLabel` near line 224 of `WhyThisWeightSheet.swift`.
- Step 02's body is near line 298, step 03's label near line 342, and `incrementText()` near line 526.
- T61's `useTitle`, near line 481, already holds the zero rule.
- The sheet's content scrolls inside its medium detent.
