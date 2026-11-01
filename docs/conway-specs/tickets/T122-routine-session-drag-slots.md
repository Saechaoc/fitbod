---
id: T122
title: A session dragged on the routine screen lands on the slot under the finger
phase: 3
items: []
depends_on: [T105]
size: S
sim: small
owns: [fitbod/Periodization/SplitDetailView.swift, new:fitbodUITests/RoutineSessionDragUITests.swift]
---

# T122: A session dragged on the routine screen lands on the slot under the finger

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F259, which T105's worker raised and the coordinator narrowed.

- The routine screen reorders its sessions by a drag that steps a fixed 64pt per slot (`slotPitch`), and its siblings part by the same 64pt.
- Its rows are taller than that at accessibility sizes, so a drag at AX3 likely lands short of the slot under the finger, as New Block's phase cards did before T105.
- Unlike New Block's old drag, this one reads the finger in the global space through a UIKit long-press recognizer, so the row already follows the finger 1:1; only the step is fixed.

## Target

- The session reorder in `fitbod/Periodization/SplitDetailView.swift`.

## Change

1. First drag the first of three sessions down by two rows' height at AX3, and by one row's height at default text, on the small phone.
   If both land on the slot under the finger three times each, record "not reproduced" in `notes.md` and change no code.
2. Otherwise, step the drag and part the siblings by the rows' measured heights, as T105's `NewBlockReorderSlots` does for New Block, so a drag lands on the slot nearest the row's center at any text size.

## Constraints

- Keep the reorder's long press, haptics, lifted look and drop animation as they are.
- Keep T26's session rows and T108's AX3 layout as they are.

## Ownership

You may edit the files in `owns`, plus routine screen tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, in `RoutineSessionDragUITests`, with T26's `-fitbod-seed-powerbuilding` seed or another seed with a routine of three sessions:

- At AX3, drag the first session down by two rows' height, and assert that it lands third.
- At default text, drag the first session down by one row's height, and assert that it lands second.

## Observable acceptance

- The repro tests pass on the small phone.
- `BlockAndRoutineTextFitUITests` and `SwipeBackUITests` pass on the small phone.
- `fitbodTests` passes.
- Screenshots after each drag, on the small phone, are in `screens/`.

## Hints

- `slotPitch` is near `SplitDetailView.swift:123`, the slot math near line 678, and the recognizer near line 726.
- `NewBlockReorderSlots` in `BlockBuilderView.swift` turns measured heights into slot offsets and a fractional slot position.
- T105's notes in `docs/conway-specs/evidence/T105/notes.md` describe how its drag tests place the handle with long margin drags.
