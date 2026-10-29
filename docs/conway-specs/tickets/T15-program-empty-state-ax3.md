---
id: T15
title: Program empty state and Resume pill at AX3
phase: 1
items: [8]
depends_on: [T10]
size: M
sim: small
owns: [fitbod/Periodization/ProgramView.swift, fitbod/Sessions/ResumeWorkoutBanner.swift, new:fitbodUITests/ProgramEmptyStateAX3UITests.swift]
---

# T15: Program empty state and Resume pill at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

At AX3, the empty Program screen draws text on top of itself.
The heading is cut to "NO PROGR…".
The description runs under the "+ DEFINE BLOCK ▶" button.
The WEEKS, PHASES, DELOAD OPTIONAL and CUSTOM chips print over each other.
The template rows overlap their own subtitle lines.
The active-workout banner on the same screen wraps its pill as "RESU" over "ME ▸".
The cause is fixed font sizes and fixed frames tuned to the mockup, because SwiftUI does not clip text that overflows a fixed frame.

## Target

- Program's empty state in `fitbod/Periodization/ProgramView.swift`: the hero, the feature chips and the template rows.
- The Resume pill in `fitbod/Sessions/ResumeWorkoutBanner.swift`.

## Change

1. At AX3 on the small phone, no text on the empty Program screen overlaps other text or a control.
2. The heading "NO PROGRAM" shows in full.
3. The description sits above "+ DEFINE BLOCK ▶", never under it.
4. The feature chips wrap or stack, and never overlap.
5. At accessibility sizes, the template rows from T10 stack their parts vertically.
6. Fixed heights become minimum heights or go away.
   Custom sizes scale with `@ScaledMetric` or use `BRUFont` roles.
7. At accessibility sizes, the banner's pill moves under the banner text, so "RESUME" never breaks mid-word.
8. At default text, the layout stays as it is after T10.

## Constraints

- Use the `dynamicTypeSize.isAccessibilitySize` branch from `TodayStatStrip.swift`, as the worker rules say.
- Keep the BRU fonts and tokens.
- Update `ProgramViewFidelityTests` only where you change pinned structure on purpose.

## Ownership

You may edit the files in `owns`, plus Program tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, at AX3 through the T01 launch option, from a fresh store so Program is empty:

- Assert that the frames of the heading, the description and "+ DEFINE BLOCK ▶" do not intersect.
- Assert that no two feature chip frames intersect.
- Assert that no two text frames inside a template row intersect.
- Leave a workout unfinished, open Program, and assert that the pill's top edge is at or below the bottom edge of the banner text.
  The pill sits beside the text today.
- Save a screenshot of each state, and write in `notes.md` whether the heading shows in full.

## Observable acceptance

- Every repro test passes at AX3 on the small phone.
- `ProgramViewFidelityTests` passes with `fitbodTests`.
- Screenshots of the empty Program screen at default text and AX3, and of the banner at AX3, are in `screens/`.
- The default-text screenshot shows no change from the layout after T10.

## Hints

- In `ProgramView.swift`, fixed font sizes are near lines 821-872, and fixed frames are near 986, 997, 1019-1020, 1043 and 1077.
  The template row view has more fixed frames near 1245-1285.
- The hero starts near line 971, with "NO PROGRAM" near 1015, "+ DEFINE BLOCK ▶︎" near 1038 and the chips near 1056-1057.
- The banner's row is near lines 65-93 of `ResumeWorkoutBanner.swift`.
- Program shows the banner for an unfinished workout near lines 108-126 of `ProgramView.swift`.
