---
id: T99
title: The block review counts its PRs and keeps its stats whole at AX3
phase: 2
items: []
depends_on: [T86]
size: S
sim: both
owns: [fitbod/Periodization/BlockReviewView.swift, new:fitbodTests/BlockReviewPRCountTests.swift]
---

# T99: The block review counts its PRs and keeps its stats whole at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F141, which the T86 worker found, and F142, which the coordinator saw in T86's screenshots.

- At AX3 on the small phone, the block review's hero stat row splits "SESSIONS" mid-word and crowds its three stats.
- The PRS stat always shows a dash over "COMING IN PHASE 6", a placeholder that names a development phase.

## Target

- The hero's three-column stat row in `fitbod/Periodization/BlockReviewView.swift`.

## Change

1. PRS counts the working sets logged during the block that set a PR, by the same check as the in-workout PR banner.
   Replay the lifter's finished history oldest first through `PRDetector.check(set:against:)` from an empty table, and count the sets from the block's workouts that return any PR kind.
   Its label underneath reads "THIS BLOCK".
2. At accessibility sizes, the stat row stacks its three stats, so no label breaks mid-word.
3. Everything else stays as it is, including SESSIONS, TONNAGE and the hero's look at default text.

## Constraints

- Keep `PRDetector` as it is; read it, do not change it.
- No schema change.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/BlockReviewPRCountTests.swift`, build a block with two finished workouts of one exercise, 100 lb × 5 then 105 lb × 5, after an earlier 100 lb × 5 outside the block, and assert that the PR count is 1.
  Move the count into a function the test can call.
  It fails today, because the stat is a placeholder.
- At AX3 on the small phone, open the review of an ended block and assert that each stat label is whole on one line, read with the shared `readText`.

## Observable acceptance

- The repro tests pass.
- `BlockReviewMathTests`, `BlockReviewTriggerTests` and `BlockReviewAfterEndUITests` pass, the unit tests with `fitbodTests` on the large phone and the UI tests on the small phone.
- Screenshots of the review's hero at default text and AX3 on the small phone are in `screens/`.

## Hints

- The stat row is near `BlockReviewView.swift:106-128`.
- `PRDetector.buildTable(from:)` and `check(set:against:)` are in `fitbod/Progress/PRDetector.swift`; T96 counts history PRs the same way.
- `BlockReviewAfterEndUITests` opens the review of an ended block.
