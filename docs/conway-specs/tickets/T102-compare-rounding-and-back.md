---
id: T102
title: Compare rounds its e1RM changes and goes back with ‹ BACK
phase: 2
items: []
depends_on: [T22]
size: S
sim: small
owns: [fitbod/Progress/SessionComparisonView.swift, fitbodTests/Phase6/PRsAndComparisonCopyTests.swift]
---

# T102: Compare rounds its e1RM changes and goes back with ‹ BACK

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F153, which T22's worker found, and F155, which the coordinator saw in T22's screenshots.

- Compare's Δ column shows e1RM changes such as "+3.16667 e1RM lb" and "+2.8125 e1RM lb", because `formatWeight` prints every digit with "%g".
- Compare's header goes back with a bare "‹", while worker-rules says pushed screens go back with "‹ BACK".

## Target

- The e1RM change text and the header in `fitbod/Progress/SessionComparisonView.swift`.

## Change

1. Each e1RM change is rounded to one decimal, such as "+2.8 e1RM lb" and "+3.2 e1RM lb".
2. A whole e1RM change shows no decimal, such as "+5 e1RM lb".
3. Set weights and weight changes print as they do today, so "102.5 × 5" and "+2.5 lb" stay.
4. Compare's header goes back with "‹ BACK".

## Constraints

- Units relabel the stored numbers and never convert them, as `CLAUDE.md` says.
- Keep the Δ colors and the three-column layout as they are.

## Ownership

You may edit the files in `owns`, plus Compare tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `PRsAndComparisonCopyTests`, assert that e1RM changes of 3.16667, 2.8125 and 5 read "3.2", "2.8" and "5", and that a weight of 102.25 still reads "102.25".
  Move the formatting into a function the test can call.
  It fails today, because "%g" prints every digit.
- On the small phone, open Compare with the `-fitbod-seed-empty-between` seed, and assert that its header shows "‹ BACK" and that no e1RM change has more than one decimal.

## Observable acceptance

- The repro tests pass.
- `PRsAndComparisonCopyTests` and `SessionComparatorTests` pass with `fitbodTests`.
- `EmptyWorkoutCountsUITests` and `ProgressHomeBRUUITests` pass on the small phone.
- A screenshot of Compare on the small phone is in `screens/`.

## Hints

- `formatWeight` is near `SessionComparisonView.swift:251`, and `deltaView` uses it for the weight and e1RM changes near line 198.
- The header is built near `SessionComparisonView.swift:57`.
- `EmptyWorkoutCountsUITests` already opens Compare with `-fitbod-seed-empty-between`.
