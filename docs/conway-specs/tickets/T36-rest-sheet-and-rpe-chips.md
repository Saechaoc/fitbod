---
id: T36
title: Rest sheet and RPE chips
phase: 3
items: [23, 24]
depends_on: [T01]
size: M
sim: both
owns: [fitbod/Sessions/RestTimer/RestTimerOverlay.swift, fitbod/Sessions/InlineRPEChipRow.swift, new:fitbodUITests/RestSheetAndRPEChipsUITests.swift]
---

# T36: Rest sheet and RPE chips

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In the workout logger, log a set, then tap the rest bar to expand it.
The sheet opens at half height, where -15s and +15s show but SKIP is cut off below the visible part.
The lifter has to drag the sheet up to skip the rest.

At AX3, the "10" in the RPE chip row touches its border, because the chips have a minimum size and no padding.

## Target

- The expanded rest sheet's detents in `fitbod/Sessions/RestTimer/RestTimerOverlay.swift`.
- The chips in `fitbod/Sessions/InlineRPEChipRow.swift`.

## Change

1. The expanded rest sheet first opens at a height measured from its content, so every control, including SKIP, is visible without dragging.
   It can still be dragged to full height.
2. At accessibility sizes, the sheet keeps opening at full height, as it does today.
3. Keep the 52pt control height.
4. Each RPE chip has padding inside its border, so no digit touches the border at any text size.
5. The chips keep their 44pt minimum, and at AX3 they wrap to a second line instead of being clipped.

## Constraints

- Keep the rest timer's behavior: the countdown, -15s, +15s and SKIP do what they do today.
- Keep the chips' selected and unselected colors, and the long press that opens the decimal RPE picker.

## Ownership

You may edit the files in `owns`, plus logger tests your change breaks.
Ask before you edit anything else.

## Repro first

With the demo seed:

- On both phones at default text, log a set, expand the rest bar, and assert that SKIP is hittable and that its frame lies above the bottom of the screen, without any drag.
- At AX3 on the small phone, save a screenshot of the RPE chips.
  Sample a column of pixels 3pt inside the left and right borders of the "10" chip, and assert they are all the chip's fill color.

Both fail today.

## Observable acceptance

- Every repro test passes on the phones it names.
- A UI test taps SKIP right after expanding the sheet, and the rest ends.
- `SessionLoggerBRUUITests` and `WorkoutLoggerJourneyUITests` pass on both phones.
- Screenshots of the expanded rest sheet on both phones, and of the RPE chips at AX3, are in `screens/`.

## Hints

- The detents are near `RestTimerOverlay.swift:60-62`, and the 52pt control height is near line 202.
- SwiftUI can measure the content's height with `onGeometryChange`, and `.presentationDetents` accepts a height detent.
- The chip frame is near `InlineRPEChipRow.swift:41-50`, inside a `BRUFlowLayout`.
