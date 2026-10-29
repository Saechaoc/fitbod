---
id: T28
title: Warm-up ramp and stat strips at AX3
phase: 2
items: [10, 11, 25]
depends_on: [T04]
size: M
sim: both
owns: [fitbod/Sessions/WarmupRampRows.swift, fitbod/Design/PlateStackViz.swift, fitbod/Sessions/SessionHistoryStatStrip.swift, fitbod/Sessions/SessionDetailView.swift, new:fitbodUITests/RampAndStripsAX3UITests.swift]
---

# T28: Warm-up ramp and stat strips at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

At AX3, the warm-up ramp in the workout logger breaks apart.
Set labels wrap as "W" over "1", and weights break as "9" over "0".
On the large phone, W3 and W4 show as "•••", and the plate text breaks as "10+10+2" over ".5".

The History stat strip and the workout summary strip always use three columns.
At AX3 they break words and numbers: "SESSI" over "ONS", "TONNA" over "GE", "4,23" over "0", "DURAT" over "ION" and "VOLUM" over "E".

The ramp also reads poorly in VoiceOver.
A bar-only row reads "Plates: ." and shows no plate text, and other rows read "2 10" and "1 reps".

## Target

- The ramp rows in `fitbod/Sessions/WarmupRampRows.swift`, and the plate text from `fitbod/Design/PlateStackViz.swift`.
- `fitbod/Sessions/SessionHistoryStatStrip.swift` and the summary strip in `fitbod/Sessions/SessionDetailView.swift`.

## Change

1. At accessibility sizes, each ramp row stacks: the set label and weight on the first line, then reps, RPE and plates on the next.
2. The set label sizes to fit, and the plate text gets its own line and never breaks inside a number.
3. A bar-only row shows "BAR" as its plate text.
4. VoiceOver reads each ramp row once: its set name, the weight with its unit, the reps with the plural helper, and the plates or "bar only".
5. At accessibility sizes, the History and summary strips stack their columns, as `TodayStatStrip` does.
   No number or word breaks inside itself.
6. At default text, the ramp and the strips look as they do today.

## Constraints

- Keep T04's skip and undo behavior in the ramp exactly as it is.
- Units relabel numbers and never convert them.
- You may extract one shared stat strip if it removes the duplication cleanly, but `TodayStatStrip` must look the same.

## Ownership

You may edit the files in `owns`, plus logger and History tests your change breaks.
Ask before you edit anything else.

## Repro first

With the demo seed, at AX3:

- On both phones, assert that the W1 label's frame is wider than it is tall.
- On both phones, assert that each strip value is one line tall, in History and in a workout summary.
- On the small phone, assert that the bar-only ramp row's accessibility label has no "Plates: ." and says "bar only".
- Assert that no ramp row's accessibility label contains "1 reps".

## Observable acceptance

- Every repro test passes on both phones.
- `SkipWarmupsUITests`, `SessionLoggerBRUUITests` and `SessionHistoryBRUUITests` pass on both phones.
- Screenshots of the ramp and both strips, at default text and AX3, on both phones, are in `screens/`.

## Hints

- The ramp label has a fixed 36pt width near `WarmupRampRows.swift:163-166`.
  Near lines 171-173, a fixed 22pt weight font sits next to a `PlateStackViz` that takes all remaining width.
- `TodayStatStrip.swift:196-201` has the accessibility branch to copy.
- The History strip is near `SessionHistoryStatStrip.swift:44-72`, and the summary strip is near `SessionDetailView.swift:119-134`.
