---
id: T85
title: PR rows keep "@ RPE" and the kind label whole
phase: 3
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Progress/ExercisePRsView.swift, new:fitbodTests/PRRowTextTests.swift]
---

# T85: PR rows keep "@ RPE" and the kind label whole

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F91, which the T71 worker found on an exercise's personal records list.

- On the 390pt phone at default text, a weight PR's value wraps after its "@", so a line ends "160 lb × 3 @" over "RPE 9".
- From xxxLarge up to the accessibility sizes, the fixed 110pt kind column wraps "WEIGHT PR" to two lines.

Neither breaks a word, but both split a phrase the lifter reads as one.

## Target

- `prRow` and `rowText` in `fitbod/Progress/ExercisePRsView.swift`.

## Change

1. A PR's value never ends a line with "@"; "@ RPE 9" stays together, on the first line or the next.
2. From xxxLarge up to the accessibility sizes, the kind label shows "WEIGHT PR" and the other kinds on one line each.
3. At default text, nothing else in the row moves, and at accessibility sizes the row stacks as it does today.

## Constraints

- Keep T57's ranking and T71's intent toggle as they are.
- Do not change the PR copy, only where it may break.

## Ownership

You may edit the files in `owns`, plus PR list tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/PRRowTextTests.swift`, assert that a weight PR's value for 160 lb × 3 at RPE 9 cannot break between "@" and "RPE 9", and that the kind label cannot break inside "WEIGHT PR".
  Both fail today.
- Save screenshots of the PR list on the small phone at default text and at xxxLarge, with the progress history seed, before the fix.

## Observable acceptance

- The repro tests pass.
- `PRListAndSeriesUITests` passes on the small phone.
- Screenshots of the PR list on the small phone at default text and at xxxLarge, before and after the fix, are in `screens/`.

## Hints

- `prRow` is near line 328 of `ExercisePRsView.swift`, and `rowText` builds the value near line 403.
- A no-break space keeps two words on one line.
