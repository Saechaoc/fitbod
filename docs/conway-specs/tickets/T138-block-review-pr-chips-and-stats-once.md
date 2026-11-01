---
id: T138
title: The block review's PR chips read to VoiceOver, and its stats load once
phase: 3
items: []
depends_on: [T113]
size: S
sim: small
owns: [fitbod/Periodization/BlockReviewView.swift, fitbodTests/BlockReviewPRCountTests.swift]
---

# T138: The block review's PR chips read to VoiceOver, and its stats load once

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F324 to F327, which T113's worker found in `fitbod/Periodization/BlockReviewView.swift`.

- An e1RM row's PR chip is hidden from VoiceOver, so a VoiceOver user cannot tell which lifts set a PR.
- T113 counts the PRs once, when the review opens, but the review's other stats still fetch the block's sets again on every render.
- The file's "DO NOT MODIFY" mark is stale: tickets have changed the view since it was written.
- `BlockReviewStatistics.prCount` now only wraps `prs(context:start:end:)` for `BlockReviewPRCountTests`.

## Target

- The e1RM rows' PR chip, the stats' fetches, the stale mark and `prCount` in `BlockReviewView.swift`, and `fitbodTests/BlockReviewPRCountTests.swift`.

## Change

1. VoiceOver reads an e1RM row that set a PR with "PR" in its label.
2. The review reads its stats once when it opens, as T113 does for its PRs.
3. The stale "DO NOT MODIFY" mark goes.
4. `prCount` goes, and `BlockReviewPRCountTests` tests `prs(context:start:end:)` instead.

## Constraints

- Every number the review shows stays the same, with T99's PR rule and replay order.
- Keep T113's TONNAGE layout and its hosted tests passing.

## Ownership

You may edit the files in `owns`, plus block review tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with `-fitbod-seed-ended-block-recap`:

- Assert that the e1RM row of a lift that set a PR has "PR" in its accessibility label.
  It does not today.

## Observable acceptance

- The repro test passes on the small phone.
- `BlockReviewAfterEndUITests` passes on the small phone, and `BlockReviewPRCountTests`, `BlockReviewPRMarkTests` and `BlockReviewHeroLayoutTests` pass with `fitbodTests`.
- `notes.md` names each stat's fetch before and after, by the code path that runs it.
- The app and the widget build.

## Hints

- T113's notes in `docs/conway-specs/evidence/T113/notes.md` list these findings.
- T113's `.onAppear` that fills `prs` shows the pattern for change 2.
