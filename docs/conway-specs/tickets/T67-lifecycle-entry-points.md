---
id: T67
title: Ending a block and swapping its routine go through the lifecycle service
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Periodization/BlockCard.swift, fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockDraft.swift, fitbodTests/BlockBuilderViewActivationTests.swift, new:fitbodTests/BlockLifecycleEntryPointsTests.swift, new:fitbodUITests/EndBlockFromCardUITests.swift]
---

# T67: Ending a block and swapping its routine go through the lifecycle service

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F48 and F49, which the T65 worker read from the code and the coordinator confirmed.
`BlockLifecycleService` is meant to be the only way to start, end or swap a block's routine; it gives an ended block its end date and archived config, and it lets only draft and ready blocks take a new routine.
The block card's "End Block" sets `isActive = false` directly instead, so the block gets no end date or archive and silently drops back to ready.
In EDIT BLOCK, SWAP sets `draft.split`, and saving writes that routine straight onto the block, so an active block can change its routine, which `swapSplit` refuses.
`BlockBuilderViewActivationTests` also still says it mirrors `saveIfValid`, which T65 changed.

## Target

- The End Block confirmation in `fitbod/Periodization/BlockCard.swift`.
- SWAP and saving a changed routine in `fitbod/Periodization/BlockBuilderView.swift` and `BlockDraft.swift`.

## Change

1. The block card's End Block ends the block through `BlockLifecycleService.end`, so it gets its end date and archived config, and shows as completed.
2. An active block's routine never changes through EDIT BLOCK: SWAP is not offered for it, and saving never writes a new routine onto it.
3. For a draft or ready block, SWAP keeps working, through the lifecycle service's rule.
4. The comments in `BlockBuilderViewActivationTests` describe the save path as it is after T65.

## Constraints

- No schema change.
- Keep End Block's confirmation before it ends the block.
- `BlockLifecycleService` stays the only way to start or end a block or swap its routine; do not add a second one.

## Ownership

You may edit the files in `owns`, plus block tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/BlockLifecycleEntryPointsTests.swift`, end an active block the way the card's End Block does, and assert that it has an end date and an archived config; it has neither today.
- In the same file, save an EDIT BLOCK draft of an active block with a different routine, and assert that the block keeps its routine; it changes today.
- In `fitbodUITests/EndBlockFromCardUITests.swift`, on the small phone with T17's seed `-fitbod-seed-active-block`, end the block from its card and assert that Program shows it as completed and Today has no active block.

## Observable acceptance

- The repro tests pass, the UI test on the small phone.
- `BlockLifecycleServiceTests`, `EditActiveBlockTests`, `BlockReadinessTests` and the six New Block guardrail suites pass with `fitbodTests`.
- A screenshot of the ended block on Program is in `screens/`.

## Hints

- The card's confirmation sets `target.isActive = false` near line 48 of `BlockCard.swift`.
- `BlockLifecycleService.end` is near line 122, `attachSplit` near 148 and `swapSplit` near 165.
- The builder's routine picker sets `draft.split` near line 157 of `BlockBuilderView.swift`, and its "SWAP ▸" label is near line 2004.
