---
id: T62
title: VoiceOver reads the heatmap one figure at a time
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Fatigue/BodySilhouetteView.swift, fitbodTests/Fatigue/BodySilhouetteViewBRUTests.swift, fitbodUITests/HeatmapHitAreaUITests.swift]
---

# T62: VoiceOver reads the heatmap one figure at a time

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F36, which the T14 worker found after T14 gave each muscle one VoiceOver element.
On Today, the MUSCLE HEATMAP shows a FRONT figure and a BACK figure side by side.
VoiceOver reads the heatmap row by row across both figures, so it jumps between FRONT and BACK muscles.
`BodySilhouetteViewBRUTests` also still describes the tap guard that T14 replaced.

## Target

- The grid in `fitbod/Fatigue/BodySilhouetteView.swift`, which draws one figure.

## Change

1. VoiceOver reads every FRONT muscle before any BACK muscle, and each figure is named as VoiceOver enters it.
2. Each muscle still has one element, with the same label, value, hint and button trait as T14 made them.
3. Nothing changes on screen, and taps work as before.
4. The comments in `BodySilhouetteViewBRUTests` describe the current tap guard and labels.

## Constraints

- Do not change `FatigueSurfaceView.swift`; ask first if the fix seems to need it.
- Keep T14's answers in tradeoffs.md "Heatmap VoiceOver" and "Exact hit areas".

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/HeatmapHitAreaUITests.swift`, on the small phone with the demo seed, read the heatmap's accessibility elements in order, and assert that every FRONT muscle comes before every BACK muscle.
It fails today.

## Observable acceptance

- The repro test passes on the small phone.
- `HeatmapHitAreaUITests`, `BodySilhouetteUITests` and `PerMuscleDetailUITests` pass on the small phone.
- `fitbodTests` passes.

## Hints

- T14 is `14af36d`; `speaksForMuscle` picks the one VoiceOver element per muscle.
- `FatigueSurfaceView.swift` near line 293 places the two figures side by side.
