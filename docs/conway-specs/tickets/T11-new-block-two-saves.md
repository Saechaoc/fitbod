---
id: T11
title: New Block's two saves
phase: 1
items: [36]
depends_on: [T10]
size: M
sim: both
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockDraft.swift, fitbod/Models/Block.swift, new:fitbodTests/BlockReadinessTests.swift, new:fitbodUITests/NewBlockSavesUITests.swift]
---

# T11: New Block's two saves

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

New Block has a SAVE at the top and SAVE TEMPLATE at the bottom.
Their labels do not say which saves a draft and which saves a ready block.
The review says the top SAVE worked without a name, but today both buttons call the same save, which requires a name.
Reproduce first, because the code and the review disagree (see [../assumptions.md](../assumptions.md)).

## Target

The top bar and the bottom action bar of New Block in `fitbod/Periodization/BlockBuilderView.swift`, and the draft's validity rules in `fitbod/Periodization/BlockDraft.swift`.

## Change

1. The top action reads "SAVE DRAFT".
   It is enabled when the block has a name, and it saves the block as it is (decision 3).
2. The bottom action reads "SAVE AS READY".
   It is enabled only when the block would be ready once saved (see "Two saves" in [../tradeoffs.md](../tradeoffs.md)).
3. Ready means the derived-status rule: a name, at least one phase, and a routine with at least one session.
   Under fixed weekly scheduling, the training days must also match the routine's sessions in number.
4. While the bottom action is disabled, its label names the first missing piece, in this order:
   - no name: "NAME FIRST ↑"
   - no phase: "ADD A PHASE"
   - no routine: "PICK A ROUTINE"
   - a routine with no sessions: "ROUTINE IS EMPTY"
   - wrong number of training days: "PICK N DAYS", where N is the routine's session count
5. Status stays derived.
   A block saved with SAVE DRAFT that already has every piece shows as ready, and that is expected.
6. Neither save activates a block.
7. In edit mode, only the bottom action shows, and it reads "SAVE CHANGES" with today's rule.

## Constraints

- Keep one readiness rule.
  You may move it from `Block.derivedStatus` into a shared pure function that both the model and the draft call.
  That is not a schema change, and this ticket allows that edit in `Block.swift`.
- Do not add or change any stored property.
- Update the six New Block guardrail suites and `NewBlockModalUITests` where they pin the old labels.

## Ownership

You may edit the files in `owns`, plus the guardrail suites and New Block UI tests whose pinned copy you change on purpose.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open New Block, leave the name empty, tap the top SAVE, and record in `notes.md` whether a block was created.
- Type a name, and assert that a control labeled "SAVE DRAFT" exists.
  It does not exist today.
- With a name and a phase but no routine, assert that the bottom action is disabled and reads "PICK A ROUTINE".
  It reads "SAVE TEMPLATE" and is enabled today.

## Observable acceptance

- A UI test saves a block with only a name through SAVE DRAFT, and Program shows it as a draft.
- A UI test fills every piece, saves through SAVE AS READY, and Program shows it as ready.
- A UI test walks the bottom label through each missing piece in order.
- A UI test opens an existing block and sees only "SAVE CHANGES".
- Unit tests cover the readiness rule for each missing piece, under both scheduling modes.
- The six guardrail suites, `NewBlockModalUITests` and `BlockDraftSaveTests` pass.

## Hints

- `NewBlockTopBar` is near lines 432-470 of `BlockBuilderView.swift`, and `NewBlockBottomActionBar` sits below the content.
- Both bars call `saveIfValid()`, which checks `BlockDraft.isValid` near line 86 of `BlockDraft.swift`.
- `Block.derivedStatus` in `fitbod/Models/Block.swift` is the rule that Program and the block overview display.
- The labels must still fit at AX3 on the small phone; T25 fixes the layout, so keep them short.
