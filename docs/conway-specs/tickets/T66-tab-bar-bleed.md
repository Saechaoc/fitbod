---
id: T66
title: The tab bar's fill stays out of the home indicator area at large text
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Design/BRUTabBar.swift, new:fitbodUITests/TabBarBleedUITests.swift]
---

# T66: The tab bar's fill stays out of the home indicator area at large text

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F45, which the T17 worker found and checked with a pixel probe.
At accessibility text sizes the tab bar shows its tabs in two rows.
Each tab cell paints its background with `.background(isActive ? Color.bruInk : Color.bruBg)`, and a color background ignores the safe area by default.
So when PROGRESS or LIBRARY is selected, its ink fill runs down into the home indicator area.
T17 fixed the same problem in `BRUButtonStyle`.

## Target

- The tab cells near line 146 of `fitbod/Design/BRUTabBar.swift`.

## Change

1. At accessibility text sizes, no tab cell's fill reaches the home indicator area.
2. At default text, the tab bar looks exactly as it does now.
3. The selected tab still shows its ink fill inside its own cell.

## Constraints

- Keep the tab bar's layout, labels and accessibility as they are.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/TabBarBleedUITests.swift`, on the small phone at AX3, select LIBRARY.
Take a screenshot and sample pixels in the home indicator area below the LIBRARY cell, and assert that they match the bar's background, as `StripeAndBleedUITests` does under SAVE.
Today they are ink (#0A0A0A).

## Observable acceptance

- The repro test passes on the small phone.
- `StripeAndBleedUITests` passes on the small phone.
- `fitbodTests` passes.
- Screenshots of the tab bar at default text and at AX3 are in `screens/`.

## Hints

- T17 (`0c898d9`) fixed `BRUButtonStyle` with `.background(fillColor(pressed:), ignoresSafeAreaEdges: [])`.
- T01's pixel helpers are `color(at:in:)` and `assertColor(at:in:is:tolerance:)` in `UITestNavigation`.
