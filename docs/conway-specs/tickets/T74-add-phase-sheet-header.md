---
id: T74
title: The Add Phase sheet has a BRU header and a CANCEL
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, new:fitbodUITests/AddPhaseSheetUITests.swift]
---

# T74: The Add Phase sheet has a BRU header and a CANCEL

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F62, which the T16 worker found.
New Block's Add Phase sheet shows a stock iOS navigation title, "Add Phase" in the system font, unlike the app's other sheets.
It also has no visible way to close it without choosing a phase; only a swipe down closes it.

## Target

- `NewBlockAddPhaseTypeSheet` in `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. The sheet's title sits in a BRU header in the app's header style, with no stock navigation title.
2. The header has a visible "CANCEL" that closes the sheet without adding a phase, as "Sheet close labels" in [../tradeoffs.md](../tradeoffs.md) says.
3. Choosing a phase type still adds that phase and closes the sheet.

## Constraints

- Keep the phase rows, their colors, the hint line and the medium detent.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
When you change `BlockBuilderView.swift`, run all six New Block guardrail suites.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/AddPhaseSheetUITests.swift`, on the small phone, open New Block and tap + ADD PHASE:

- Assert that there is no navigation bar titled "Add Phase".
- Tap "CANCEL", and assert that the sheet closes and New Block still shows the same number of phases.

Both fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- The six New Block guardrail suites pass with `fitbodTests`.
- Screenshots of the sheet in light and dark mode on the small phone are in `screens/`.

## Hints

- `NewBlockAddPhaseTypeSheet` is near line 1906 of `BlockBuilderView.swift`, and `.navigationTitle("Add Phase")` is near line 1966.
- `BRUHeaderBar` in `fitbod/Design/BRUHeaderBar.swift` takes a left action and a center title.
- T38 later gives the CHOOSE ROUTINE sheet a "CANCEL" in a BRU header too, so the two sheets should match.
