---
id: T73
title: Orange text on Program and New Block reads clearly in light mode
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Periodization/ProgramView.swift, fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockPhaseColors.swift, docs/design-system/color.md, fitbodUITests/ProgramDarkModeUITests.swift]
---

# T73: Orange text on Program and New Block reads clearly in light mode

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F61 and F63, which the T16 worker measured.
In light mode, small orange text on paper on Program and New Block uses `bruSignal`, which reaches 2.95:1.
That covers SAVE DRAFT, SWAP ▸, + ATTACH ▸, UNDO, the "+" of + ADD PHASE, ALL HISTORY ▸ and + NEW ROUTINE.
`docs/design-system/color.md` asks for `bruSignalText` for signal-colored text and thin strokes on paper.
The New Block chart's phase labels also read 2.42:1 (INTENS.) and 4.43:1 (ACCUM.) on their light bands.
T16 added five phase colorsets, and `color.md` does not list them.

## Target

- Signal-colored text in `fitbod/Periodization/ProgramView.swift` and `fitbod/Periodization/BlockBuilderView.swift`.
- `phaseLabelInk` in `fitbod/Periodization/BlockPhaseColors.swift`.
- "Other colorsets" in `docs/design-system/color.md`.

## Change

1. Signal-colored text and thin strokes on paper-role surfaces on Program and New Block use `bruSignalText`, as `color.md` says.
   Signal fills keep `bruSignal`.
2. In light mode, the chart's phase labels reach at least 4.5:1 against their bands.
3. In dark mode, every check in `ProgramDarkModeUITests` still passes.
4. `color.md` lists the five phase colorsets T16 added, with their light and dark values and where they are used.

## Constraints

- Do not change colors on any other screen.
- Keep T16's dark variants unless a label fails a check.

## Ownership

You may edit the files in `owns`, plus the five phase colorsets T16 added in the asset catalog if a label's light value must change.
When you change `BlockBuilderView.swift`, run all six New Block guardrail suites.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ProgramDarkModeUITests.swift`, in light mode on the small phone, with T16's contrast reader:

- Assert that "+ NEW ROUTINE" on Program and SAVE DRAFT on a named New Block reach at least 4.5:1 against paper.
- Assert that the chart's INTENS. and ACCUM. labels reach at least 4.5:1 against their bands.

All of these fail today.

## Observable acceptance

- The repro tests pass, and every other test in `ProgramDarkModeUITests` passes, on the small phone in light and dark mode.
- `AdaptiveColorSourceTests`, `ProgramViewFidelityTests` and the six guardrail suites pass with `fitbodTests`.
- `python3 docs/design-system/tokens_check.py` passes.
- Light and dark screenshots of Program and New Block on the small phone are in `screens/`.

## Hints

- `ProgramView.swift` colors ALL HISTORY ▸ near line 387 and + NEW ROUTINE near line 423.
- New Block's `NewBlockScreenTokens.signal` is near line 380 of `BlockBuilderView.swift`, and SAVE DRAFT uses it near line 543.
- `Color.bruTextOnPaper` in `fitbod/Design/Color+BRU.swift` maps `bruSignal` to `bruSignalText`.
- `phaseLabelInk(for:)` returns `bruSignal` for intensification and the `phaseAccumulationLabel` colorset for accumulation.
