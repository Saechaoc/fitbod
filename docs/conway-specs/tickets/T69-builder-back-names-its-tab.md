---
id: T69
title: The block builder's back control names the tab it opened from
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbod/Views/TodayView.swift, fitbod/Periodization/BlockReviewView.swift, new:fitbodUITests/BlockBuilderBackLabelUITests.swift]
---

# T69: The block builder's back control names the tab it opened from

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F52, which the T67 worker found.
The block builder's top bar always labels its back control "< PROGRAM".
Today opens the builder too, for EDIT BLOCK on its block overview and for a block template, and the block review's "Start next ▸" opens it as well.
From those, the back control names Program, a tab the lifter is not in.

## Target

- `NewBlockTopBar` in `fitbod/Periodization/BlockBuilderView.swift`.
- The builder's call sites in `fitbod/Views/TodayView.swift` and `fitbod/Periodization/BlockReviewView.swift`.

## Change

1. Opened from Today, including from the block review, the back control reads "< TODAY".
2. Opened from Program, it still reads "< PROGRAM", as `bru-screens/New-block/new-block-named.html` shows.
3. The back control still asks before it throws unsaved edits away.

## Constraints

- Do not change how the builder saves or discards.
- Keep the copy that `NewBlockBuilderFidelityTests` pins for Program, unless you change it on purpose.

## Ownership

You may edit the files in `owns`, plus block builder tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/BlockBuilderBackLabelUITests.swift`, on the small phone with T17's seed `-fitbod-seed-active-block`:

- On Today, open the block's overview from its band, tap EDIT BLOCK, and assert that the back control reads "< TODAY".
  It reads "< PROGRAM" today.
- On Program, open New Block and assert that the back control still reads "< PROGRAM".

## Observable acceptance

- The repro tests pass on the small phone.
- `EditorSwipeDismissUITests` and `NewBlockSavesUITests` pass on the small phone.
- `NewBlockBuilderFidelityTests` passes with `fitbodTests`.
- A screenshot of EDIT BLOCK opened from Today is in `screens/`.

## Hints

- `NewBlockTopBar` is near line 511 of `BlockBuilderView.swift` and draws `Text("< PROGRAM")` near line 521.
- Today presents the builder in a sheet near line 277 of `TodayView.swift`, and the review opens it near line 65 of `BlockReviewView.swift`.
- Program's call sites are near line 211 of `ProgramView.swift`; they need no change if Program stays the default.
- `BlockLifecycleEntryPointsUITests` (T67) opens EDIT BLOCK from Today's block overview with the same seed.
