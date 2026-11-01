---
id: T127
title: The PR list writes volume with thousands separators, as the chart does
phase: 3
items: []
depends_on: [T85, T106]
size: S
sim: small
owns: [fitbod/Progress/ExercisePRsView.swift, fitbodTests/PRRowTextTests.swift]
---

# T127: The PR list writes volume with thousands separators, as the chart does

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F295, which T85's worker found.

- The PR list writes a volume PR as "1250 lb", while the exercise's chart writes volume as "2,140".
- `PRRowText.formatWeight` in `fitbod/Progress/ExercisePRsView.swift` prints whole numbers with `String(Int(value))`, so it never groups digits.

## Target

- `PRRowText` in `fitbod/Progress/ExercisePRsView.swift`.

## Change

1. Every number the PR list shows of 1,000 or more uses the same grouping the chart uses, such as "1,250 lb".
2. Smaller numbers, decimals such as "102.5" and T85's no-break spaces stay as they are.
3. VoiceOver reads the grouped number as a number.

## Constraints

- Units relabel the stored numbers and never convert them, as `CLAUDE.md` says.
- Keep T85's row text and its stacking from xxxLarge.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

In `PRRowTextTests`:

- Assert that a volume PR of 1,250 lb reads "1,250 lb", with the locale the chart formats with.
  It reads "1250 lb" today.

## Observable acceptance

- The repro test passes with `fitbodTests` on the large phone.
- `PRListAndSeriesUITests` passes on the small phone.
- A screenshot of a volume PR of 1,000 lb or more on the small phone is in `screens/`.

## Hints

- Find how the chart formats its volume, such as with `.formatted()`, and use the same rule so the two agree.
- `PRRowTextTests` already builds row text without the UI.
