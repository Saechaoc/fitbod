---
id: T105
title: New Block's revealed Delete deletes, and VoiceOver reads its controls by name
phase: 2
items: []
depends_on: [T24]
size: M
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbodUITests/PhaseRowsVoiceOverUITests.swift]
---

# T105: New Block's revealed Delete deletes, and VoiceOver reads its controls by name

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F166 to F169, F172 and F173, which T24's worker found.

- Tapping the revealed Delete on a New Block phase card closes the card instead of deleting the phase.
  The card's `.contentShape` and `.onTapGesture` come after its `.offset`, so its tap area stays at its resting frame and covers the revealed button.
  A full swipe still deletes, and so does VoiceOver's Delete Phase action.
- VoiceOver reads the decorative pencil beside the block name as "Compose, Image".
- VoiceOver reads the progression chart's internals, such as "0.5 to 1.5, 109.3 to 110".
- The phase editor sheet's steppers read only "−" and "+", with no stat name.
- VoiceOver lists Move Up on the first phase card and Move Down on the last, where they do nothing.
- A run killed during `PhaseRowsVoiceOverUITests` can leave VoiceOver on, because each test turns it off only in its teardown.

## Target

- The phase card, the name band, the progression chart and the phase editor sheet in `fitbod/Periodization/BlockBuilderView.swift`.
- `fitbodUITests/PhaseRowsVoiceOverUITests.swift`.

## Change

1. Tapping a revealed Delete deletes its phase, through the same undo toast as a full swipe.
2. A tap on the rest of a revealed card still closes it.
3. VoiceOver skips the decorative pencil.
4. The progression chart reads as one element that sums it up, such as its first and last weekly values, instead of its internals.
5. Each phase editor stepper reads its stat and direction, such as "Increase weeks", with the stat's value.
6. A phase card lists Move Up and Move Down only where the move is possible.
7. Each VoiceOver test also turns VoiceOver off at its start, so one killed run cannot leave the next with VoiceOver on.

## Constraints

- Keep T24's one-element phase cards and their label and value.
- Keep the card's look, its swipe and its reorder as they are.
- `BlockBuilderView.swift` changes need all six New Block guardrail suites.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Swipe a phase card partway to reveal Delete, tap Delete, and assert that the phase count drops by one.
  It stays the same today.
- With VoiceOver on, assert that the name band reads no "Compose", that the chart reads one element, and that a phase editor stepper's label names its stat.
- Assert that the first phase card lists no Move Up and the last lists no Move Down.

## Observable acceptance

- The repro tests pass on the small phone.
- `PhaseRowsVoiceOverUITests`, `NewBlockModalUITests` and `AddPhaseSheetUITests` pass on the small phone.
- `fitbodTests` passes, including the six New Block guardrail suites.
- A screenshot of a revealed Delete before and after the tap is in `screens/`.

## Hints

- The card's modifiers are in `NewBlockPhaseEditorRow.body`, near `BlockBuilderView.swift:1515`, and `commitDelete()` routes a delete through the undo toast.
- The pencil is the `square.and.pencil` image near `BlockBuilderView.swift:612`.
- The steppers use `NewBlockRoundStepper(label: "−")` and `"+"`, as near `BlockBuilderView.swift:764`, and the phase editor sheet starts near line 1811.
- T24's notes in the main checkout's `docs/conway-specs/evidence/T24/notes.md` say how its tests drive VoiceOver with `XCUIVoiceOverService`, and that taps do not activate through VoiceOver.
