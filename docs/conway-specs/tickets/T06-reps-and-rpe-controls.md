---
id: T06
title: Reps and RPE controls in the session editor
phase: 1
items: [5, 6]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/RoutineDraft.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, new:fitbodUITests/PrescriptionControlsUITests.swift, new:fitbodTests/PrescriptionRangeTests.swift]
---

# T06: Reps and RPE controls in the session editor

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In the session editor's prescription details, a tap on the high reps field puts the caret before the number, so typing 1 into "6" makes "16".
In the full walkthrough, 4 became 64 and 6 became 106, and the set rows then read "×64 @8".
The fields' tap area is only 48 by 19 points, the number pad has no Done key, and nothing stops a low value above the high value.
Target RPE shows "8 – 8" as two fields, but both are bound to one value, and typing 0 silently clears the target.

## Target

The prescription details in `fitbod/Routines/PrescriptionEditorRow.swift`, and the draft it edits, `fitbod/Routines/RoutineDraft.swift`.

## Change

1. Replace the low and high reps text fields with two `BRUStepper` controls (see "Reps entry" in [../tradeoffs.md](../tradeoffs.md)).
2. The reps range is 1 to 30, unless the model already defines one.
3. The low stepper can never go above the current high value, and the high stepper can never go below the current low value.
4. Replace the two RPE fields with one BRU toggle, "Target RPE", and one `BRUStepper` from 6.0 to 10.0 in steps of 0.5 (see "RPE entry").
5. With the toggle off, the exercise has no RPE target.
   Turning it on starts at 8.0.
6. Every control has a 44pt target and reads its value in VoiceOver, such as "8 reps" or "RPE 8.5".
7. The values save, and they come back when the editor is reopened.
8. Update the prescription step of `MilestoneOneJourneyUITests` so it uses the new controls the way a user would.

## Constraints

- Reuse `BRUStepper` from `fitbod/Design/BRUStepper.swift`; do not build a new stepper.
- No schema change: the model already has low reps, high reps and one optional target RPE.
- Do not restyle the rest of the editor; T29 handles its large-text layout.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, open the session editor's prescription details:

- Tap the high reps field that shows 6, type 8, and assert that it reads 8.
  It reads 86 or 68 today.
- Assert that exactly one RPE control exists.
  Two exist today.

## Observable acceptance

- The repro tests pass on both phones, rewritten for the new controls.
- A UI test changes reps from 8 to 10 and RPE from 8.0 to 8.5, saves, reopens, and sees the new values.
- A UI test turns Target RPE off, saves, reopens, and sees no RPE target.
- A unit test proves the low-to-high rule.
- The journey test passes its prescription step.
  If it fails at a later step, `notes.md` says where and why.
- `fitbodTests` passes.

## Hints

- Cause of item 5: `PrescriptionEditorRow.swift` near lines 150-192 uses number text fields 48pt wide, with the 44pt frame outside the field.
- Cause of item 6: both RPE fields near lines 205-232 read and write the same `targetRPE`.
- `RoutineDraft` defaults are low 8, high 12 and RPE 8.0.
- `BRUStepper` is generic over the value type, with a step of that type's stride, so it works for whole reps and half-step RPE.
