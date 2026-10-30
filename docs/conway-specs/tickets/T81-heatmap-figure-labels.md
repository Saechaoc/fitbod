---
id: T81
title: VoiceOver names each heatmap figure once
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Fatigue/FatigueSurfaceView.swift, fitbodUITests/HeatmapHitAreaUITests.swift]
---

# T81: VoiceOver names each heatmap figure once

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F80, which the T62 worker found on Today's muscle heatmap.
T62 (`0bdd0b1`) made each figure's muscles one VoiceOver group, named "Front" or "Back".
VoiceOver still reads the visible FRONT and BACK labels above the figures first, as two elements: "FRONT", "BACK", then "Front, Shoulders, …".
So it says each figure's name twice, and "BACK" comes before the front muscles.

## Target

- The FRONT and BACK labels in `heatmapSection` of `fitbod/Fatigue/FatigueSurfaceView.swift`.

## Change

1. VoiceOver skips the FRONT and BACK labels; each figure's group still names it.
2. The labels look exactly as they do today.

## Constraints

- Keep T62's figure groups and their "Front" and "Back" names as they are; do not change `BodySilhouetteView`.

## Ownership

You may edit the files in `owns`, plus heatmap tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/HeatmapHitAreaUITests.swift`, read the elements in VoiceOver order, as `testVoiceOverReadsFrontBeforeBack` does, and assert that no "FRONT" or "BACK" text comes before the figures.
It fails today.

## Observable acceptance

- The repro test passes on the small phone.
- `HeatmapHitAreaUITests`, `BodySilhouetteUITests` and `PerMuscleDetailUITests` pass on the small phone.
- Before and after screenshots of the heatmap on the small phone at default text are in `screens/`, and they match pixel for pixel.

## Hints

- The labels are near lines 295 and 310 of `FatigueSurfaceView.swift`.
- SwiftUI exposes hidden children inside an `.accessibilityElement(children: .contain)` group, so hide the labels themselves rather than grouping them with their figures.
