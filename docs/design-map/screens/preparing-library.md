---
id: preparing-library
kind: screen
title: Preparing library
view: fitbod/App/RootView.swift:151
tab: none
presents_from: [x-launch]
closes_with: none
mock: none
seed: none
captured: none
img: []
tree: none
---

The lifter waits on first launch while the exercise library is seeded.

No screenshot exists: on a reset launch the white launch screen stays up about 0.7 s and then Today appears; a screen recording of 128 frames never shows this splash.

## Entry points

| From | Tap | Kind |
|---|---|---|
| App launch | first launch or store reset | launch |

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| none; it is replaced when seeding finishes | [today](today.md) | replace | none |

## States

| State | How to reach it | Screenshot |
|---|---|---|
| Loading | not captured: the splash is replaced before it reaches the screen | none |

The splash is a centred spinner with the text "Preparing library…" and no tab bar.
If seeding fails, the app still leaves the splash and shows the tabs.

## Compared with the mock-up

No mock-up was drawn for the splash.

## VoiceOver order

No accessibility tree exists because the splash was not captured.
From the code, VoiceOver would read one element, "Preparing library…", as a progress indicator.

## Findings

<!-- findings are linked after the audit -->
