---
id: T35
title: Today polish
phase: 3
items: [22, 24, 25]
depends_on: [T10, T27]
size: L
sim: both
owns: [fitbod/Fatigue/MuscleVolumeBar.swift, fitbod/Fatigue/FatigueSurfaceView.swift, fitbod/Views/TodayStatStrip.swift, fitbod/Views/TodayView.swift, fitbod/Periodization/StartBlockCTA.swift, fitbod/Design/BRUHeaderBar.swift, new:fitbodUITests/TodayPolishUITests.swift]
---

# T35: Today polish

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On Today:

- In VOLUME THIS WEEK, the MEV, MAV and MRV tick labels sit right against the muscle name, and the MRV label lands under "SETS".
- On the small phone in light mode, the divider under the CHEST row is stepped: its left part sits a few pixels higher than the rest.
- At AX3, the legend (UNDER MEV, MEV → MAV, MRV) wraps awkwardly.
- At AX3, the header's left and right items ran together as "SETTINGS MON · OCT 5" in the review snapshot.
- At AX3 on the small phone, the header cuts the date to "FRI · OCT…" (findings F9 and F81).
- At xxLarge and xxxLarge on the small phone, the stat strip breaks "SESSIONS" mid-word, and the header cuts the date (finding F134, from T90).
- With an active block, the third stat shows a dash under "W1 / 5".
- With no active block, the "No active block." card is inset 32pt instead of 16pt, its sentence-case heading clashes with the card above it, and its "Start a block" link is hard to read.

## Target

- The volume rows in `fitbod/Fatigue/MuscleVolumeBar.swift`, and the legend in `fitbod/Fatigue/FatigueSurfaceView.swift`.
- The third stat in `fitbod/Views/TodayStatStrip.swift`, fed from `fitbod/Views/TodayView.swift`.
- `fitbod/Periodization/StartBlockCTA.swift`.
- `fitbod/Design/BRUHeaderBar.swift`, only if step 4 reproduces.

## Change

1. The tick labels get their own row above the bar, with clear space below the muscle name, and every label stays inside the bar's width.
2. Find the cause of the stepped divider and fix it, so the divider is one straight line.
3. At accessibility sizes, the legend stacks its three items, and each label stays on one line.
4. At AX3, and at xxLarge and xxxLarge on the small phone, the header's left and right items never touch, and the date shows whole.
   `BRUHeaderBar` already has an accessibility branch, so reproduce this before you change it.
   At accessibility sizes, the actions' touch areas also stay clear of the title stacked under them (finding F176, from T21's worker).
5. When the week trend is flat, the third stat shows the current phase's short label instead of the dash (see "Today's third stat" in [../tradeoffs.md](../tradeoffs.md)).
   Use the same short labels that Program's template rows use since T10, such as "ACCUM".
6. The "No active block." card:
   - its content lines up with the 16pt edges of the cards around it
   - its heading uses the same uppercase display style as the card above it, applied as a text case so VoiceOver reads words
   - its link uses `bruSignalText` instead of `bruSignal`
7. At xxLarge and xxxLarge on the small phone, every stat strip label shows whole, with no word broken across lines.

## Constraints

- `BRUHeaderBar` is on every screen.
  Change it only if the repro fails, and keep it exactly as it is at default text.
- Keep the volume zones, colors and set counts exactly as they are.
- At default text, everything else on Today looks as it does today.

## Ownership

You may edit the files in `owns`, plus Today and volume tests your change breaks.
Ask before you edit anything else.

## Repro first

With the demo seed, write `TodayPolishUITests`:

- On both phones, assert with frame checks that no tick label intersects the muscle name, and that the MRV label lies inside the bar.
- On the small phone in light mode, save a screenshot, sample the divider under the first volume row at several points across its width, and assert they share one y position.
- At AX3 on the small phone, assert that the legend items do not intersect and that each is one line tall.
- At AX3 on the small phone, assert that the header's left item ends at least 8pt before its right item starts, and that the date is not cut off.
  Record in `notes.md` whether each check fails.
- At AX3 on the small phone, open the New routine name step and assert that no header action's touch area overlaps the stacked title.
- At xxLarge and xxxLarge on the small phone, run the same header check, and read the stat strip's labels with the shared `readText`, asserting that each label is whole on one line.
- With an active block in week 1 and no workouts, assert that the third stat's value is the phase's short label.
- With no active block, assert that the card's heading starts at the same x as the card above it.

## Observable acceptance

- Every repro test passes on the phones it names.
- `VolumeBarsUITests` and `HistoryAndTodayUITests` pass on both phones.
- Screenshots of the volume rows, the legend, the header, the stat strip and the empty card, at default text and AX3, in light and dark mode, are in `screens/`.

## Hints

- `MuscleVolumeBar.swift`'s file comment describes the tick labels and the set count layout.
- The legend is `legendStrip` in `FatigueSurfaceView.swift`, near line 197.
- The header's accessibility branch is near `BRUHeaderBar.swift:190`.
- The third stat is near `TodayStatStrip.swift:160-176`, and the dash comes from `trendValue` near line 88.
- `StartBlockCTA.swift` applies `.padding(16)` and then `.padding(.horizontal, 16)`, near lines 43-45.
