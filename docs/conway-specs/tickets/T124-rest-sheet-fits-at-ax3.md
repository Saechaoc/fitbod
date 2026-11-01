---
id: T124
title: The rest sheet's countdown and ±15s buttons fit at AX3
phase: 3
items: []
depends_on: [T36]
size: S
sim: both
owns: [fitbod/Sessions/RestTimer/RestTimerOverlay.swift, fitbod/Sessions/RestTimer/RestTimerProgressArc.swift, fitbodUITests/RestSheetAndRPEChipsUITests.swift]
---

# T124: The rest sheet's countdown and ±15s buttons fit at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F272 and F273, which T36's worker found; both show in the milestone closeout's AX3 capture too.

- At AX3 the expanded rest sheet's countdown, such as "2:54", runs into its 200pt ring on both phones.
  `docs/design-system/accessibility.md` says numeric countdowns fit within the progress arc.
- At AX3 the sheet's -15s and +15s labels come within about 3pt of their 80pt-wide outlines.
- VoiceOver reads the remaining rest time as "1 minutes 30 seconds" and "1 seconds" (`RestTimerOverlay.remainingAccessibility`; finding F276, from T34's worker).

## Target

- The expanded sheet's ring, countdown and ±15s buttons in `fitbod/Sessions/RestTimer/RestTimerOverlay.swift` and `RestTimerProgressArc.swift`.

## Change

1. At every text size the countdown sits inside the ring, clear of its stroke: the ring grows with the text, or the countdown scales down to fit, whichever keeps it easier to read.
2. At accessibility sizes the -15s and +15s labels keep at least 8pt from their borders, as the RPE chips do since T36, and the buttons keep their 52pt height.
3. VoiceOver reads the remaining time through `BRUCountLabel`, such as "1 minute 30 seconds" and "1 second", with a unit test of `remainingAccessibility`.

## Constraints

- Keep the rest timer's behavior and T36's sheet that opens at its content's height.
- At default text the sheet looks as it does today.

## Ownership

You may edit the files in `owns`, plus rest timer tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone at AX3, with a rest running, in `RestSheetAndRPEChipsUITests`:

- Read the expanded sheet's screenshot, and assert that the countdown's digits sit inside the ring's inner edge.
- Assert that the -15s and +15s labels keep 8pt from their borders.

Both fail today.

## Observable acceptance

- The repro tests pass on both phones.
- `RestSheetAndRPEChipsUITests` and `SessionLoggerBRUUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of the expanded sheet at AX3 on both phones, and at default text on the small phone, are in `screens/`.

## Hints

- T36's screenshots in `docs/conway-specs/evidence/T36/screens/`, such as `T36-rest-sheet-small-ax3-light.png`, show both, and so does `docs/verification/closeout/iphone-17e-ax3-expanded-rest.png`.
- T36's chip test reads digit pixels against a border with `UITestNavigation.pixels(in:of:)`; the same approach fits the ring.
