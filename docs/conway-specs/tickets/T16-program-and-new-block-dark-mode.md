---
id: T16
title: Program and New Block in dark mode
phase: 1
items: [9]
depends_on: [T01]
size: M
sim: both
owns: [fitbod/Periodization/ProgramView.swift, fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockNameField.swift, fitbod/Periodization/BlockPhaseColors.swift, new:fitbodTests/AdaptiveColorSourceTests.swift, new:fitbodUITests/ProgramDarkModeUITests.swift]
---

# T16: Program and New Block in dark mode

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In dark mode, every tab turns dark except Program, which keeps its light paper background.
Program's rows show white text on cream.
The CHOOSE ROUTINE sheet shows black text on black.
New Block stays light.
The cause is fixed RGB colors mixed with adaptive ones.

## Target

- `ProgramScreenTokens` and `ctaColor` in `fitbod/Periodization/ProgramView.swift`.
- `NewBlockScreenTokens`, the CHOOSE ROUTINE sheet and one more literal color in `fitbod/Periodization/BlockBuilderView.swift`.
- The colors in `fitbod/Periodization/BlockNameField.swift`.

## Change

1. Program, New Block, the CHOOSE ROUTINE sheet and the block name field use only the adaptive tokens from `Color+BRU.swift`: `bruPaper`, `bruInk`, `bruMuted`, `bruHair`, `bruFaint` and `bruSignal`.
2. In dark mode, all text on these screens has a contrast ratio of at least 4.5:1 against its background, or 3:1 for large display text.
3. In light mode, these screens look as they do today.
   Write any visible light-mode difference in `notes.md`.
4. The phase hues in `BlockPhaseColors.swift` may stay fixed if screenshots show they read well on both backgrounds.
   If one does not, give it an adaptive dark variant.
5. Add a source test that fails when `Color(red:` appears in `ProgramView.swift`, `BlockBuilderView.swift` or `BlockNameField.swift`.

## Constraints

- Do not change colors on any other screen.
- When you change `BlockBuilderView.swift` or `BlockNameField.swift`, run all six New Block guardrail suites.

## Ownership

You may edit the files in `owns`, plus the color assets in the app's asset catalog if a phase hue needs a dark variant.
Ask before you edit anything else.

## Repro first

In dark mode, on the large phone first:

- Open Program with one block and the template rows.
  Use the T01 pixel sampler to measure a template row title against its background, and assert a contrast ratio of at least 4.5:1.
- Open New Block, and assert that its background pixel matches the dark `bruPaper` value.
- Open CHOOSE ROUTINE in New Block, and assert that a routine name has at least 4.5:1 contrast against its row.
- Run the new source test and watch it fail.

All of these fail today.

## Observable acceptance

- Every repro test passes on both phones in dark mode.
- The source test passes with `fitbodTests`.
- The six guardrail suites and `ProgramViewFidelityTests` pass.
- `python3 docs/design-system/tokens_check.py` passes.
- Screenshots of Program, New Block and CHOOSE ROUTINE, in light and dark mode on the small phone, are in `screens/`.

## Hints

- `ProgramScreenTokens` is near lines 813-817 of `ProgramView.swift`, and `ctaColor` is near 844.
- `NewBlockScreenTokens` is near lines 296-305 of `BlockBuilderView.swift`, a literal color is near 2357, and the CHOOSE ROUTINE sheet is near 2055-2099.
- `rg "Color\(red:" fitbod` lists every literal color.
  Today only these four files have one.
