---
id: T24
title: Phase rows in VoiceOver, and the block name field
phase: 2
items: [45, 47]
depends_on: [T01]
size: M
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockPhaseEditorRow.swift, fitbod/Periodization/BlockNameField.swift, new:fitbodUITests/PhaseRowsVoiceOverUITests.swift, new:fitbodUITests/BlockNameTypingUITests.swift]
---

# T24: Phase rows in VoiceOver, and the block name field

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In New Block, VoiceOver reads "Phase 1: Accumulation" 12 times.
The phase card's label sits on a container, so every child inherits it.

A UI test once typed "Cancel Probe" into the block name and got "ancel Probe", even with the keyboard up and a one-second wait.
Routine names and note text typed correctly in the same run.
The name field draws its own placeholder over a text field and adds its own tap gesture.
Nobody has reproduced this with real key taps, so it may be a test artifact.

## Target

- The phase card and the phase rows in New Block: `fitbod/Periodization/BlockBuilderView.swift` and `fitbod/Periodization/BlockPhaseEditorRow.swift`.
- The block name field, `fitbod/Periodization/BlockNameField.swift`.

## Change

1. VoiceOver reads each phase's label once, such as "Phase 1: Accumulation".
2. Each phase row has an accessibility value that reads its settings, such as its number of weeks.
3. Every control in a phase row stays reachable and usable with VoiceOver, either as its own element or through adjustable or custom actions on the row.
4. Reproduce item 47 with real key taps before you change the name field.
5. If the first character is lost, replace the drawn placeholder and the extra tap gesture with the text field's own prompt.
6. If it is not lost, leave the name field as it is, and say so in `notes.md`.

## Constraints

- Phase editing must work exactly as it does today.
- Run all six New Block guardrail suites.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open New Block with one phase, and assert that exactly one accessibility element has the label "Phase 1: Accumulation".
  There are 12 today.
- Tap the block name field, type "Cancel Probe" by tapping one software keyboard key at a time, and assert that the field reads "Cancel Probe".
- Do the same with one `typeText` call, and record both results in `notes.md`.
- If the software keyboard does not appear, ask the coordinator; do not change simulator settings yourself.

## Observable acceptance

- The VoiceOver repro passes on the small phone.
- A UI test proves that each control in a phase row is still reachable through accessibility.
- The key-tap test passes, and if the bug reproduced, the `typeText` test passes too.
- The six guardrail suites and `NewBlockModalUITests` pass.
- `notes.md` says whether item 47 reproduced.

## Hints

- The phase card's label is near `BlockBuilderView.swift:1372`, and the row's label is near `BlockPhaseEditorRow.swift:61`.
  Neither container sets how it combines its children.
- The drawn placeholder and the tap gesture are near `BlockNameField.swift:55-74`.
- XCUI can tap one key with the keyboard's key element, which is the closest a test gets to a person typing.
