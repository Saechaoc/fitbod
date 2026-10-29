---
id: T25
title: New Block layout on the small phone and at AX3
phase: 2
items: [37, 46]
depends_on: [T11]
size: M
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, new:fitbodUITests/NewBlockLayoutUITests.swift]
---

# T25: New Block layout on the small phone and at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On the small phone at default text, New Block breaks words in the middle.
The legend shows "INTEN" over "SITY", and the section head shows "PROGRESSION" over "OVERVIEW".
At AX3 on the small phone, it gets worse:

- The top bar truncates to "< PRO…" and "NEW B…".
- The bottom button truncates; it read "SAVE TE…" before T11 renamed it.
- The legend's letters stack one per line.
- The chart's phase labels overlap each other, because they sit at fixed positions.

## Target

New Block's top bar, section heads, legend, progression chart labels and bottom action bar, in `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. Nothing in New Block breaks inside a word on the small phone, at default text or at AX3.
2. No control label or section head in New Block is truncated at AX3 on the small phone.
3. At accessibility sizes, the top bar puts its title on its own line, under the back and save actions.
   This matches the milestone rule that headers separate titles and actions at accessibility sizes.
4. The bottom action's labels from T11 fit on one line, or wrap between words.
5. The chart's phase labels never overlap.
   When full names do not fit, the chart uses the short phase labels that Program's rows use, such as "ACCUM".
   When even those overlap, the chart hides its labels and relies on the legend.
6. The legend wraps between items, never between letters.
7. On the large phone at default text, New Block looks as it does today.

## Constraints

- Use the `dynamicTypeSize.isAccessibilitySize` branch, as the worker rules say.
- Run all six New Block guardrail suites.
  `NewBlockProgressionChartTests` pins the chart's structure, so update it only where you change that structure on purpose.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- At default text, assert with frame checks that "INTENSITY" and "PROGRESSION OVERVIEW" are each one line tall.
- At AX3, assert that the frames of the top bar's back action, title and save action do not intersect.
- At AX3, assert that no two chart phase label frames intersect.
- Save a screenshot of each state, look at it, and write one line per label in `notes.md`.

## Observable acceptance

- Every repro test passes on the small phone.
- The six guardrail suites and `NewBlockModalUITests` pass.
- Screenshots of the top bar, the legend, the chart and the bottom bar are in `screens/`: at default text and AX3 on the small phone, and at default text on the large phone.

## Hints

- `NewBlockTopBar` is near lines 432-470.
- "PROGRESSION OVERVIEW" is near line 902, and the legend is near 909-953, with "INTENSITY" near 944.
- The chart's labels use fixed positions near lines 1098-1110, 1123, 1129 and 1167.
