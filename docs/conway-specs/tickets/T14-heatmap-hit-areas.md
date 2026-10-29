---
id: T14
title: Heatmap hit areas and VoiceOver
phase: 1
items: [7]
depends_on: [T01]
size: M
sim: small
owns: [fitbod/Fatigue/BodySilhouetteView.swift, fitbodUITests/BodySilhouetteUITests.swift, fitbodTests/Fatigue/BodySilhouetteViewBRUTests.swift, new:fitbodUITests/HeatmapHitAreaUITests.swift]
---

# T14: Heatmap hit areas and VoiceOver

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On Today, the MUSCLE HEATMAP blocks sit off the grid and overlap each other.
DELT hides under BICEP, NECK hides under the chest blocks, and TRI covers LAT, so it reads "TRILAT".
GLUTE covers LOWER BACK, and UPPER BACK is cut to "PPER BACK".
The right TRI block sticks out past the BACK frame, and the frame cuts the bottom CALF row.
Tapping NECK opens the CHEST detail screen.

VoiceOver has two more problems.
It announces the decorative NECK as a button with the hint "Tap to see details.", and NECK does nothing.
Left and right halves are separate elements, so VoiceOver reads "Chest" twice, "Biceps" twice, and so on.

## Target

The heatmap grid in `fitbod/Fatigue/BodySilhouetteView.swift`, shown on Today under MUSCLE HEATMAP.

## Change

1. Each block draws at its exact grid rectangle, inside its FRONT or BACK box.
2. Each block's tap area is exactly its drawn rectangle, with no padding (see "Exact hit areas" in [../tradeoffs.md](../tradeoffs.md)).
   This is a named exception to the 44pt rule in the worker rules.
3. Tapping a block opens the detail screen for that muscle, and for no other muscle.
4. NECK is decorative.
   It is not a button, has no hint, does nothing when tapped, and VoiceOver skips it.
5. VoiceOver reads each muscle once (see "Heatmap VoiceOver").
   The left half carries the label and the value, and the right half is hidden from VoiceOver.
6. Each muscle element keeps the button trait and opens the detail screen when activated.

## Constraints

- Do not change the volume math, the zone colors, the labels or the grid layout.
  Only placement, tap areas and VoiceOver change.
- The volume list on the same screen stays as it is; it is the large-target path.

## Ownership

You may edit the files in `owns`, plus heatmap and muscle detail tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with the demo seed, scroll Today to MUSCLE HEATMAP:

- Read every heatmap button frame, and assert that no two frames intersect.
- Assert that each frame lies inside its FRONT or BACK box.
- Tap NECK, and assert that no detail screen opens.
  CHEST opens today.
- Assert that exactly one accessibility element is labeled "Chest".
  There are two today.
- Save a screenshot of the heatmap.

## Observable acceptance

- Every repro test passes on the small phone.
- A UI test taps one block per muscle and checks that the right detail screen opens.
- `BodySilhouetteUITests` and `PerMuscleDetailUITests` pass on the small phone.
- `BodySilhouetteViewBRUTests` passes with `fitbodTests`, updated only where it pinned the old padding on purpose.
- Screenshots of the heatmap at default text and at AX3 are in `screens/`.

## Hints

- The padding comes from `needsHitPadding`, near lines 142-146 and 192 of `BodySilhouetteView.swift`.
  The offset places the padded box, not the block, which is why blocks drift right and down.
- The review verified that placing each block by the center of its rectangle, with no padding, fixes both placement and taps.
- The NECK hint and button trait are near lines 151-154 and 179-182.
