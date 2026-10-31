---
id: T113
title: The block review's PR marks agree, and its stats read cheaply and whole
phase: 3
items: []
depends_on: [T99]
size: S
sim: small
owns: [fitbod/Periodization/BlockReviewView.swift, fitbodUITests/BlockReviewAfterEndUITests.swift, new:fitbodTests/BlockReviewPRMarkTests.swift]
---

# T113: The block review's PR marks agree, and its stats read cheaply and whole

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F234, F235 and F237, which T99's worker found in its own review.

- The block review counts its PRs inside the view's body, so every render replays the lifter's whole history: about 0.39 s on a history of 6,000 sets.
- An e1RM row shows "★ PR" whenever its e1RM rose during the block, a placeholder rule, so a row can say PR while PRS counts none for that lift, or the other way round.
- At AX3 on the small phone, a TONNAGE of 1,000,000 or more wraps inside the number.

## Target

- The PR count, the e1RM rows' PR chip and the TONNAGE value in `fitbod/Periodization/BlockReviewView.swift`.

## Change

1. The review computes its PR count once when it opens, not on every render.
2. An e1RM row shows "★ PR" only when that lift has a PR in the block by the rule PRS counts, so the chips and the count always agree.
3. TONNAGE stays whole on one line at every text size on the small phone, even at 1,000,000 or more.

## Constraints

- Keep T99's PR rule, its replay order and its AX3 layout.
- Keep the other stats and the copy as they are.

## Ownership

You may edit the files in `owns`, plus block review tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `BlockReviewPRMarkTests`, build a block where one lift's e1RM rises without any set beating that lift's earlier sets, and assert that its row is not marked as a PR.
  It fails today.
- On the small phone at AX3, with a block whose tonnage is over 1,000,000, assert with the shared `readText` that TONNAGE reads on one line.
  You may add a DEBUG-only launch flag to a seed for this, as the worker rules allow.
- Record in `notes.md` how many times the PR count runs while the review opens and scrolls, before and after.

## Observable acceptance

- The repro checks pass, the UI check on the small phone.
- `BlockReviewAfterEndUITests`, `BlockReviewMathTests`, `BlockReviewPRCountTests` and `BlockReviewTriggerTests` pass, the unit tests with `fitbodTests` on the large phone.
- Screenshots of the review at default text and AX3 on the small phone are in `screens/`.

## Hints

- The count is read near `BlockReviewView.swift:89`, and the e1RM rows' chip near line 236.
- `BlockReviewStatistics.prCount(context:start:end:)` holds T99's replay.
- T99's notes and its review are in the main checkout's `docs/conway-specs/evidence/T99/`.
