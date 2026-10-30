---
id: T65
title: Saving an edit keeps the active block active
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockDraft.swift, new:fitbodTests/EditActiveBlockTests.swift]
---

# T65: Saving an edit keeps the active block active

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F43, which the T11 worker read from the code and the coordinator confirmed.
The active block can be opened in EDIT BLOCK: the block card's menu offers "Edit Block" beside "End Block", and Today and the block overview open it too.
Every save in the block builder goes through `save()`, which sets `draft.isActive = false` so that saving never activates a block.
`BlockDraft.save(into:)` then copies that flag to the block.
So SAVE CHANGES on the active block deactivates it: the lifter's program silently stops being active, while its end date stays empty.

## Target

- `save()` in `fitbod/Periodization/BlockBuilderView.swift`.
- `BlockDraft.save(into:)` in `fitbod/Periodization/BlockDraft.swift`.

## Change

1. Saving an edit keeps the block's active state: an active block stays active, and an inactive one stays inactive.
2. Saving a new block still never activates it; only `BlockLifecycleService.start` starts a block.
3. Editing a block never deactivates another active block.

## Constraints

- No schema change.
- `BlockLifecycleService` stays the only way to start or end a block, and at most one block is active.

## Ownership

You may edit the files in `owns`, plus block tests your change breaks.
Ask before you edit anything else.

## Repro first

Write unit tests first, in `fitbodTests/EditActiveBlockTests.swift`, pulling the save path out of the view if you need to:
- Start a ready block with `BlockLifecycleService.start`, open it as an edit draft (`BlockDraft(block:)`), change its name, and save it the way SAVE CHANGES does.
  Assert that the block is still active, its end date is still empty, and no other block changed.
- Save a new block the way SAVE AS READY does, and assert that it is not active.

The first test fails today.

## Observable acceptance

- The repro tests pass.
- `BlockReadinessTests`, `BlockLifecycleServiceTests` and the six New Block guardrail suites pass with `fitbodTests` on the large phone.

## Hints

- `save()` is near line 251 of `BlockBuilderView.swift`, after T11 (`4178ce9`).
- `BlockDraft(block:)` copies `isActive` near line 76, and `save(into:)` writes it near line 158.
