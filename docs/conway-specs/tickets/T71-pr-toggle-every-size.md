---
id: T71
title: The PR list's intent toggle fits every text size and says which is selected
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Progress/ExercisePRsView.swift, fitbodUITests/PRListAndSeriesUITests.swift]
---

# T71: The PR list's intent toggle fits every text size and says which is selected

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F54, F55 and F56, which the T57 worker found on the PR list's STRENGTH / HYPERTROPHY / ALL toggle.
T57 stacks the toggle at accessibility sizes.
At xxxLarge, the largest size below those, the small phone still breaks HYPERTROPHY mid-word ("HYPERTROP" / "HY"), and ALL's ink fill covers only the middle of its taller segment.
At default text, each segment is about 35pt tall, under the 44pt tap-target rule.
The segments do not carry the selected trait, so VoiceOver does not say which intent is selected.

## Target

- `intentToggle` in `fitbod/Progress/ExercisePRsView.swift`.

## Change

1. At every text size, each toggle label stays whole on one line, and the selected segment's fill covers its whole segment.
2. Each segment is at least 44pt tall at every text size.
3. VoiceOver reads the selected segment as selected.

## Constraints

- Keep the toggle's labels, order, colors and filtering.
- At default text, the toggle stays one row of three equal segments.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/PRListAndSeriesUITests.swift`, with the progress history seed, open Personal Records on the small phone and assert all three of these:

- At xxxLarge, no segment is taller than ALL's one-line segment, as T57's `testIntentToggleLabelsStayWholeAtAX3` checks at AX3.
- At default text, every segment is a 44pt tap target.
- The selected segment reports `isSelected`, and the others do not.

All three fail today.

## Observable acceptance

- The repro tests and `testIntentToggleLabelsStayWholeAtAX3` pass on the small phone.
- `PRListAndSeriesUITests` passes on the small phone, and `PRsAndComparisonCopyTests` passes with `fitbodTests`.
- Screenshots of the toggle at default text, xxxLarge and AX3 on the small phone are in `screens/`.

## Hints

- `intentToggle` is near line 127; T57 switches its layout on `dynamicTypeSize.isAccessibilitySize`.
- The selected fill is a `.background` on the label near line 151, so in a row it is only as tall as its own label.
- `UITestNavigation.TextSize` has only `.default` and `.ax3`, and `UITestNavigation.swift` belongs to T39.
  For xxxLarge, add `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryXXXL` to the launch arguments yourself.
- `BRUSegmentedControl` sets the selected trait (near line 68 of `fitbod/Design/BRUSegmentedControl.swift`), but it sizes segments to their text and overflows at AX3, so T57 did not reuse it.
