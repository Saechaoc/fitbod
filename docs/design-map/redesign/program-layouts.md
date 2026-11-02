# Program layouts

One wireframe per state in [hierarchy.md](hierarchy.md), at 390pt with 16pt gutters.
The active-block slab follows the user's own mock-up, `bru-screens/Fitbod-Session/screens/phase-2--program.png`, which was never built, with the week cells left on Block overview (O-13 in [open-decisions.md](open-decisions.md)).
The example week is the one Today's wireframes use: Thursday May 22, Push A scheduled, Pull A next on Saturday.

Legend: `════` 2pt ink rule, `────` 1pt hair rule, `█` ink slab, `[ TEXT ▸ ]` BRUButton, `›` chevron on a tappable row.

## P-ACTIVE, weekday block

```
┌──────────────────────────────────────────────┐
│                 FITBOD / PROGRAM       + NEW │  BRUHeaderBar; + NEW in ink opens the popover
╞══════════════════════════════════════════════╡
│ ████████████████████████████████████████████ │
│ █ ● ACTIVE BLOCK                    OPEN › █ │  label row; the whole slab is a Button → Block overview
│ █ SPRING BLOCK                             █ │  BRUDisplay .large
│ █ WEEK 2 OF 6 · ACCUMULATION               █ │  BlockPosition.label, the same text as Today's plan line
│ █ PUSH PULL LEGS                           █ │  routine name; rotation blocks append "· ROTATION"
│ ████████████████████████████████████████████ │
│                                              │
│ THIS WEEK                       MAY 19 - 25  │  BRUSectionHead
│ MON  Legs A                     52 MIN  ✓   ›│  logged; the row opens the workout
│ TUE  Arms                       35 MIN  ✓   ›│  logged off-plan; listed on the day it happened
│ WED  Rest                                    │  muted
│ THU  Push A                         TODAY ▸  │  ink text action; starts the scheduled session with its slot
│ FRI  Rest                                    │
│ SAT  Pull A                                  │  planned
│ SUN  Rest                                    │
│                                              │
│ PLANNED                                      │  only when ready or draft blocks exist
│ ┌──────────────────────────────────────────┐ │
│ │ READY  SUMMER BLOCK                     ›│ │  BRUChip outlined ink
│ │ 8 weeks · 4 phases · Upper Lower         │ │
│ │ Saved Oct 3                              │ │  muted; `startDate` is the save date, not a plan (O-14)
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ DRAFT  UNTITLED BLOCK                   ›│ │
│ │ No routine yet                           │ │  the missing piece, from `derivedStatus`
│ └──────────────────────────────────────────┘ │
│                                              │
│ ROUTINES                                     │
│ Push Pull Legs                              ›│  RoutineSplitRow
│ 3 sessions · used by Spring Block            │  muted subline replaces the chips
│ Upper Lower                                 ›│
│ 2 sessions · used by Summer Block            │
│ Archived routines · 1                       ›│  muted row
│                                              │
│ PAST BLOCKS · 3                             ›│  row → past blocks list
└──────────────────────────────────────────────┘
```

| Element | Component | Notes |
| --- | --- | --- |
| Header | BRUHeaderBar(left: nil, center: "Fitbod / Program", right: HeaderAction("+ New")) | Replaces ProgramChromeHeader. The `HeaderAction` form draws in ink; the `HeaderSlot.action` form would draw it orange. The header keeps the `onGeometryChange` height measurement the popover is positioned by, and the 44pt target of the old chrome. |
| + New popover | BRUActionPopover | Items unchanged: + New block → NewBlockStartChoiceSheet, + New routine → NewRoutineRoute.name. The only creation entry in non-empty states. |
| Now slab | New ActiveBlockSlab, ink | Four lines: label row with OPEN ›, name, position, routine. No week cells, no days left, no training days: the week is said once, the cells are on Block overview one tap away, and the days are the rows below. |
| This week | New ThisWeekSection, Phase 2 | Seven rows. A day with a logged workout shows its session name, duration and ✓, and opens the workout; off-plan workouts list on the day they happened. A day without a workout shows the planned session from `trainingDays` and the slot order, or "Rest". The current day shows "TODAY ▸" in ink text when a session is scheduled and not yet done; it starts that session with its slot, exactly as Today's hero does. |
| Planned cards | BlockStatusCard | Chip in outlined ink for READY and DRAFT. Sublines: weeks · phases · routine, then "Saved Oct 3" (muted) for ready blocks or the missing piece for drafts. No copy says "starts" or "planned": `startDate` is stamped at save and overwritten at start (O-14). Tap → Block overview. |
| Routine rows | RoutineSplitRow | Subline "3 sessions · used by Spring Block". With two users: "used by Spring Block, Summer Block". "1 session" singular. |
| Archived routines | Existing row, muted | Unchanged target. Shown whenever any archived routine exists, in every state. |
| Past blocks | Button(.bruRow) | Count of completed blocks. Pushes the list below. Replaces the inline DONE cards and ALL HISTORY ▸. |

Above the fold: header, Now slab, the This week head and four rows.
Eight elements, none of them orange: the only forward action is the ink "TODAY ▸".

## P-ACTIVE, rotation block

The This week section becomes a rotation strip, because a rotation has no weekdays.

```
│ ROTATION                                     │  the Now slab already names the routine
│ 01  Push A                   LOGGED MAY 19  ›│
│ 02  Pull A                   LOGGED MAY 21  ›│
│ 03  Legs A                          NEXT ▸   │  ink text action; starts this slot
│ ALSO THIS WEEK   Arms · May 20              ›│  workouts outside the routine, muted
```

Each row shows the date of that slot's latest logged workout in this block, or nothing.
"NEXT ▸" marks the slot the resolver returns and starts it with its slot.
Workouts from sessions outside the routine cannot sit in the strip, so they list under it with their dates.

## P-PLANNED, ready block and nothing active

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│ ████████████████████████████████████████████ │
│ █ READY                                    █ │
│ █ SUMMER BLOCK                             █ │
│ █ 8 WEEKS · 4 PHASES · UPPER LOWER         █ │
│ █ [ START BLOCK ▸                        ] █ │  BRUButton .signal .lg
│ █                                   OPEN › █ │
│ ████████████████████████████████████████████ │
│                                              │
│ PLANNED                                      │  the other ready and draft blocks
│ ┌ DRAFT  UNTITLED BLOCK · No routine yet  › ┐│
│                                              │
│ ROUTINES                                     │
│ ...                                          │
│ PAST BLOCKS · 3                             ›│
```

The oldest saved ready block takes the slab and the one signal; ties go by name (O-6).
Other ready blocks list as cards and start from their overview.
START BLOCK ▸ starts the block today, as the overview's Start does; `BlockLifecycleService.start` stamps `startDate` then, which until that moment is only the save date (O-14).
It shows a "Couldn't start block" alert if the call throws, with "Try again" and "Open block".
Today shows the same block as T-READY, so both tabs lead with START BLOCK ▸; on a day with a finished workout Today shows T-DONE instead and this slab keeps the one-tap start.

## P-ROUTINE, routines and no block

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│ BLOCKS                                       │
│ No block yet.                    + NEW BLOCK │  empty-section line; signal text link
│                                              │
│ ROUTINES                                     │
│ Push Pull Legs                              ›│
│ 3 sessions                                   │
│ Archived routines · 1                       ›│  hidden when zero
```

+ NEW BLOCK here opens the same NewBlockStartChoiceSheet as the popover.
With completed blocks and nothing live (P-PAST), the line reads "No block planned." and PAST BLOCKS · 3 › follows the routines.

## P-EMPTY, fresh store

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│                                              │
│ START WITH A ROUTINE                         │  condensedHeading, not 68pt
│ A routine is your split, like Push / Pull /  │
│ Legs. Each session in it lists exercises     │
│ with target sets and reps. Blocks schedule   │
│ a routine across weeks, and come after.      │
│                                              │
│ [ + NEW ROUTINE                            ] │  BRUButton .signal .lg
│                                              │
│ Archived routines · 2                       ›│  only when archived routines exist
└──────────────────────────────────────────────┘
```

Gone: NO PROGRAM, the em-dash paragraph, + DEFINE BLOCK ▶, the four chips, and OR START FROM A TEMPLATE.
Presets stay one tap away inside + New block › Use Preset.
The popover's + New block stays enabled; the block builder's routine picker gains "No routines yet. + New routine" for the case where it is tapped first (D-162).
"Split" is the gym word for a training split, not the code name the glossary bans.

## P-RESUME

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│ ┌──────────────────────────────────────────┐ │
│ │ WORKOUT IN PROGRESS · PUSH A · 4 SETS    │ │  ResumeWorkoutBanner as a paper row, 2pt ink border
│ │ [ RESUME ▸ ]                  DISCARD    │ │  the page's only signal; visible ghost Discard
│ └──────────────────────────────────────────┘ │
│ ████████████████████████████████████████████ │
│ █ ● ACTIVE BLOCK                    OPEN › █ │  the Now slab stays ink; nothing else restyles
│ █ ...                                      █ │
```

Discard becomes a visible ghost button with the same confirmation as Today's slab, replacing the long-press menu (D-56, D-57).
The banner is the only element the open workout adds; the rest of the page is P-ACTIVE or P-PLANNED as it was.
In This week, the current day's "TODAY ▸" is hidden while a workout is open and the row reads "IN PROGRESS".
A START BLOCK ▸ on the page becomes an ink primary button while the banner shows.

## Past blocks list

Pushed from PAST BLOCKS ›.

```
│ ‹            PAST BLOCKS                     │
╞══════════════════════════════════════════════╡
│ Summer Block                                ›│
│ 6 weeks · Mar 3 - Apr 14 · 18 workouts       │
│ Winter Block                                ›│
│ 8 weeks · Jan 6 - Mar 1 · 22 workouts        │
│ Winter Block                                ›│
│ 4 weeks · Nov 4 - Dec 1 · 10 workouts        │
```

Date ranges tell same-name blocks apart (D-127).
Rows open Block overview, which gains a "Review ›" entry for completed blocks (D-40).
The review opens as a sheet, because BlockReviewView wraps its own NavigationStack, and it takes the presenting tab as its origin so its "Start next ▸" builder names Program on its back control.
Reopening a review that was already acknowledged leaves `reviewedAt` alone: `acknowledge` guards on nil (step 2.1).

## + New popover

```
│                               ┌────────────┐ │
│                               │ + New block│ │
│                               │ + New      │ │
│                               │   routine  │ │
│                               └────────────┘ │
```

Unchanged BRUActionPopover.
The NewBlockStartChoiceSheet (Blank block / Use preset) and NewBlockPresetPickerSheet keep their copy and stay in ProgramView.swift, where two guardrail suites pin "CREATE BLOCK" and the full-screen builder.
The sheet's title "CREATE BLOCK" under a popover item "+ New block" is accepted: the rename would turn two suites red for one word.

## Block overview, what the redesign asks of it

Both tabs lead here, so a few lines change with them.

| Change | Why |
| --- | --- |
| The week strip header uses `BlockPosition.label`, the same "Week 2 of 6 · Accumulation" as Today and Program | One form of the fact everywhere (R-6). |
| "n / m SESSIONS DONE" becomes "n / m WORKOUTS DONE" | The shared vocabulary; `BlockWeekCountsUITests` changes with it. |
| The End block dialog reads "Ends Spring Block and saves its plan to history. New workouts will not count toward it." | The confirmation rule (P-9) wants the consequence; "from the Program tab" goes. |
| "Review ›" on a completed block opens BlockReviewView as a sheet with the origin passed in | Reopens a review after the notice is gone (D-40). |

## Accessibility sizes

The Now slab's label row stacks "ACTIVE BLOCK" over "OPEN ›".
This week rows put the status under the name.
Planned cards and routine rows keep their chevrons on the first line.

## Dark mode

Same tokens as Today: `bruInk` slabs on `bruBg`, paper cards on `bruBg2`.
