---
id: T132
title: The planned block hero and session summaries keep their parts whole at AX3
phase: 3
items: []
depends_on: [T108]
size: S
sim: small
owns: [fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Routines/SessionTemplateSummary.swift, fitbodUITests/BlockOverviewAndRoutineAX3UITests.swift, fitbodUITests/StripeAndBleedUITests.swift]
---

# T132: The planned block hero and session summaries keep their parts whole at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F306 to F308, which T108's worker found at AX3 on the small phone.

- A draft or ready block's hero wraps its plan line, "5 WEEKS · ACCUM 3 · INTNS 1 · DELOAD 1".
  Line 2 starts with "·", and "1" sits alone on line 3 under DELOAD.
  The line is `phasePlan` in `plannedHeroBand`, near `BlockOverviewScreen.swift:689`; T108 fixed the same break in the active hero.
- A session row's summary, "1 EXERCISE · 3 SETS · ~11 MIN", puts "~11" and "MIN" on different lines.
  The text is `SessionTemplateSummary.line` (`SessionTemplateSummary.swift:59`), which the routine screen, the session detail and Today's session picker show.
- Two test comments, near `BlockOverviewAndRoutineAX3UITests.swift:267` and `StripeAndBleedUITests.swift:63`, say their trailing-margin drags stay clear of the session rows' reorder press.
  The drags work only because their 0.05 s press is shorter than the reorder's 0.25 s.

## Target

- `plannedHeroBand` in `fitbod/Periodization/BlockOverviewScreen.swift`.
- The summary text in `fitbod/Routines/SessionTemplateSummary.swift`.
- The two comments named in Problem.

## Change

1. At accessibility sizes the planned hero's plan line puts each part on its own line, without the dots, as T108 did for the active hero.
2. A session summary never breaks inside a part: "~11 MIN", "3 SETS" and "1 EXERCISE" each stay whole, and no line starts with "·", on every screen that shows it.
3. The two comments say why the drags do not start a reorder.

## Constraints

- At default text, both phones look as they do today.
- VoiceOver reads the same words as before.
- Keep T108's active hero and its banner placement as they are.

## Ownership

You may edit the files in `owns`, plus block overview, routine and session summary tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone at AX3, with T26's `-fitbod-seed-powerbuilding` seed, in `BlockOverviewAndRoutineAX3UITests`:

- Open the draft Powerbuilding block, and assert that each plan part reads on one line and that no line starts with "·".
- Open the Upper Lower routine, and assert that the first session row keeps "~11 MIN" on one line.

Both fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- `BlockOverviewAndRoutineAX3UITests`, `BlockAndRoutineTextFitUITests`, `BlockOverviewStatesUITests` and `StripeAndBleedUITests` pass on the small phone.
- Default-text screenshots of the draft block and the routine on both phones match their T108 screenshots.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T108's notes in the main checkout's `docs/conway-specs/evidence/T108/notes.md`, under Findings, describe both breaks; see `screens/T108-draft-attach-small-ax3-light.png` and `screens/T108-routine-small-ax3-light.png` there.
- `UITestNavigation.textLines` reads text line by line; `readText` joins the lines with spaces.
- No-break spaces kept T85's and T108's labels whole.
