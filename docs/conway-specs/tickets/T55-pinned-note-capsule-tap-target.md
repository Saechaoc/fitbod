---
id: T55
title: Pinned note capsule takes taps across 44 points
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Sessions/PinnedNoteCapsule.swift, new:fitbodUITests/PinnedNoteCapsuleTapTargetUITests.swift]
---

# T55: Pinned note capsule takes taps across 44 points

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F18, which the T04 worker found while checking the buttons in the logger's exercise header row.
An exercise with a pinned note shows the note as a capsule in that row, and a tap on the capsule opens the Pinned Note sheet.
The capsule is a plain button with 8pt of padding above and below one line of text, and it has no 44pt frame.
So it takes taps only on its drawn box, about 33pt tall, which is under the 44pt minimum for a tap target.

## Target

- The `Button` in `PinnedNoteCapsule.body` in `fitbod/Sessions/PinnedNoteCapsule.swift`.

## Change

1. The capsule takes a tap anywhere in a band at least 44pt tall around its drawn box.
2. The drawn capsule looks exactly as it does today; the header row may grow only by what the 44pt band needs.
3. A tap still opens the Pinned Note sheet, and the accessibility label and hint stay the same.

## Constraints

- Keep the BRU source rules that `SessionWidgetsBRUCopyTests` and `Phase3BRUGrepAuditTests` check in this file.
- Do not change `SessionExerciseCard.swift`; ask first if the fix seems to need it.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

On the small phone, launch with the demo seed and open the workout logger.
Give the first exercise a pinned note through its "Edit Pinned Note" menu entry, and save it.
Then, in `fitbodUITests/PinnedNoteCapsuleTapTargetUITests.swift`:
- Check the capsule with `UITestNavigation.assertTapTarget(_:minimum:)` at 44pt.
- Tap inside the 44pt band but outside the drawn box, and assert that the Pinned Note sheet opens.

Both fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- A crop of the drawn capsule is pixel-identical before and after the change, and screenshots of the header row before and after are in `screens/`.
- `SessionLoggerBRUUITests` and `SkipWarmupsUITests` pass on the small phone.
- `fitbodTests` passes.

## Hints

- T04 fixed the same problem on the STALLED row's suggested-action chip: `git show 4476234 -- fitbod/Fatigue/SuggestedActionChip.swift`.
  That chip already had a 44pt frame outside its button, so its row kept its height; the capsule has none, so its row may grow.
- `SessionExerciseCard.swift` near line 155 places the capsule in the header's second row.
- The capsule's padding is near line 78 and its button style near line 85.
