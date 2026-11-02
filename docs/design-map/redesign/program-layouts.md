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
│ MON  Legs A                     52 MIN  ✓   ›│  a day group: one row per counted workout; the row opens the workout
│ TUE  Arms                       35 MIN  ✓   ›│  logged off-plan; listed on the day it happened
│ WED  Rest                                    │  muted
│ THU  Push A                         TODAY ▸  │  ink text action; shows exactly while Today's state is T-TODAY
│ FRI  Rest                                    │
│ SAT  Pull A                                  │  planned
│ SUN  Rest                                    │
│                                              │
│ PLANNED                                      │  only when ready or draft blocks exist
│ ┌──────────────────────────────────────────┐ │
│ │ READY  SUMMER BLOCK                     ›│ │  BRUChip outlined ink
│ │ 8 weeks · 4 phases · Upper Lower         │ │
│ │ Created Oct 3                            │ │  muted; `startDate` is the creation date until the block starts (O-14)
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
| This week | New ThisWeekSection, Phase 2 | Seven day groups. A group holds one row per counted workout logged that day (session name, duration, ✓; the row opens the workout), off-plan workouts included, then the open workout as "IN PROGRESS" on the day it started, then the planned session from `trainingDays` and the slot order while no counted workout today holds its slot, or "Rest" when the group is otherwise empty. Today's planned row carries "TODAY ▸" in ink text exactly while Today's state is T-TODAY; it starts that session with the same slot Today's hero would, through `StartSlot` (round 3). A planned session with no exercises reads "Push A · NO EXERCISES ›" and opens its detail (Today is T-FIX then). |
| Planned cards | BlockStatusCard | Chip in outlined ink for READY and DRAFT. Sublines: weeks · phases · routine, then "Created Oct 3" (muted) for ready blocks or the missing piece for drafts. No copy says "saved", "starts" or "planned": `startDate` is stamped when the draft is created, kept when the block is edited, and overwritten at start (O-14, round 3). Tap → Block overview. |
| Routine rows | RoutineSplitRow | Subline "3 sessions · used by Spring Block". With two users: "used by Spring Block, Summer Block". "1 session" singular. |
| Archived routines | Existing row, muted | Unchanged target. Shown whenever any archived routine exists, in every state. |
| Past blocks | Button(.bruRow) | Count of completed blocks. Pushes the list below. Replaces the inline DONE cards and ALL HISTORY ▸. |

Above the fold: header, Now slab, the This week head and four rows.
Eight elements, none of them orange: the only forward action is the ink "TODAY ▸".

A day with two workouts, and a day with an open workout, read like this (round 3):

```
│ MON  Legs A                     52 MIN  ✓   ›│  the day's first counted workout
│      Arms                       20 MIN  ✓   ›│  its second, in the same group, oldest first
│ THU  Push A                    IN PROGRESS   │  the open workout, by its `templateName`; no chevron, the banner resumes it
```

Every counted workout of the week appears exactly once, in its day group.
The open workout row has no action: Program's banner is the one route to it, so there is one signal.
When the open workout holds today's slot, the planned row is left out; otherwise the planned session stays as a plain row under it, with no "TODAY ▸", because Today is T-RESUME.
After a counted workout today Today is T-DONE, so "TODAY ▸" is hidden then too, and the planned session shows as a plain row only while its slot is not the one done.

## P-ACTIVE, rotation block

The This week section becomes a rotation strip, because a rotation has no weekdays.

```
│ ROTATION                                     │  the Now slab already names the routine
│ 01  Push A                   LOGGED MAY 19  ›│
│ 02  Pull A                   LOGGED MAY 21  ›│
│ 03  Legs A                          NEXT ▸   │  ink text action; shows exactly while Today's state is T-TODAY
│ ALSO THIS WEEK   Arms · May 20              ›│  every other counted workout this week, muted
```

Each row shows the date of that slot's latest counted workout in this block, or nothing, and opens that workout.
"NEXT ▸" marks NEXT, the resolver's next slot, the value [hierarchy.md](hierarchy.md) defines, and starts it with its slot through `StartSlot`; it is hidden while a workout is open (the row reads "IN PROGRESS" under the open workout's own name when that name is a slot's session, else the open workout lists under "Also this week" as "In progress") and after a counted workout today (round 3).
"Also this week" lists every counted workout of this week that is not a slot row's latest workout, with its date, so each workout appears exactly once: off-routine workouts, and a slot's earlier workout when it was logged twice this week.
A NEXT session with no exercises reads "Push A · NO EXERCISES ›" and opens its detail.

## P-PLANNED, ready block and nothing active

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│ ████████████████████████████████████████████ │
│ █ READY                                    █ │
│ █ SPRING BLOCK                             █ │
│ █ 6 WEEKS · 3 PHASES · PUSH PULL LEGS      █ │
│ █ CREATED OCT 3 · 1 OF 2 READY             █ │  muted; "· 1 OF 2 READY" only with more than one ready block
│ █ [ START BLOCK ▸                        ] █ │  BRUButton .signal .lg
│ █                                   OPEN › █ │
│ ████████████████████████████████████████████ │
│                                              │
│ PLANNED                                      │  the other ready and draft blocks
│ ┌ READY  SUMMER BLOCK · Created Oct 10    › ┐│  starts from its overview
│ ┌ DRAFT  UNTITLED BLOCK · No routine yet  › ┐│
│                                              │
│ ROUTINES                                     │
│ ...                                          │
│ PAST BLOCKS · 3                             ›│
```

The fixture is the block Today's T-READY shows, so both tabs name the same block.
The oldest created ready block takes the slab and the one signal (`startDate`, then name, then id; O-6, round 3).
Other ready blocks list as cards and start from their overview.
START BLOCK ▸ starts the block today, as the overview's Start does; `BlockLifecycleService.start` stamps `startDate` then, which until that moment is the creation date (O-14).
It shows a "Couldn't start block" alert if the call throws, with "Try again" and "Open block".
Today shows the same block as T-READY, so both tabs lead with START BLOCK ▸; on a day with a finished workout Today shows T-DONE instead and this slab keeps the one-tap start, two taps from Today.

## P-PLANNED, drafts only

With draft blocks and no ready one, nothing can be started, so the page has no signal element (round 3).
The newest created draft leads as a paper slab, so the page still has a primary task: finish the block.

```
│                 FITBOD / PROGRAM       + NEW │
╞══════════════════════════════════════════════╡
│ ┌──────────────────────────────────────────┐ │
│ │ DRAFT                                    │ │  paper slab, 2pt ink border
│ │ UNTITLED BLOCK                           │ │
│ │ NO ROUTINE YET                           │ │  the missing piece, from `derivedStatus`
│ │ [ CONTINUE BLOCK ▸                     ] │ │  ink primary → Block overview, whose Edit opens the builder
│ └──────────────────────────────────────────┘ │
│                                              │
│ PLANNED                                      │  the other drafts, as cards; absent with one draft
│ ┌ DRAFT  BLOCK 2 · No phases yet          › ┐│
│                                              │
│ ROUTINES                                     │
│ ...                                          │
```

Newest created first here (`startDate`, then name, then id), the reverse of the ready rule, because drafts have no "next to start" order and the draft made last is the one the lifter moved on to; `startDate` is the creation date and survives edits (`BlockDraft.swift:19`, `:80`), so "touched last" would need an edit timestamp the schema does not have (round 3, V4-F5).
Today shows T-PICK, T-FIX or T-FIRST meanwhile: a draft is not Today's business.

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

Discard becomes a visible ghost button with the same rule as Today's slab, replacing the long-press menu (D-56, D-57): it asks "Discard workout?" only when sets are logged and discards at once when none are, which step 1.6 records as the exception to the confirmation rule in `docs/design-system/interaction.md` (round 3).
The banner is the only element the open workout adds; the rest of the page is whichever state lies under it, P-ACTIVE, P-PLANNED, P-ROUTINE, P-PAST or P-EMPTY (an open workout from a since-archived routine).
The banner holds the page's one signal, so every other signal control draws in ink while it shows: START BLOCK ▸ on the ready slab, + NEW ROUTINE on the empty page, and the + NEW BLOCK text links (round 3).
In This week, "TODAY ▸" and "NEXT ▸" are hidden, and the open workout shows as "IN PROGRESS" under its own `templateName` in the group of the day it started, whichever session it is; a planned session is never marked in progress on the strength of a different workout being open (round 3).

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
│ 4 weeks · Nov 4 - Dec 1, 2025 · 10 workouts  │  the year shows when the block ended in an earlier year than today
```

Date ranges tell same-name blocks apart (D-127); a block that ended in an earlier year than today carries its year, so two Winter Blocks a year apart read differently (round 3).
Rows open Block overview, which gains a "Review ›" entry for completed blocks (D-40), two taps from this list.
The review opens as a sheet, because BlockReviewView wraps its own NavigationStack, and it takes Block overview's `origin` so its "Start next ▸" builder names the tab the lifter came from on its back control.
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
| "Review ›" on a completed block opens BlockReviewView as a sheet with the origin passed in, through the presenter Today uses, so a failed acknowledgement shows "Couldn't save the review. Open it again to retry." under the row (round 3, F-F1) | Reopens a review after the notice is gone (D-40). |
| Block overview takes an `origin` from the stack that pushed it: `.today` from Today's plan line and T-READY's Open ›, `.program` from Program | The review sheet's "Start next ▸" builder names the right tab on its back control from either stack; plan.md's step 2.1 no longer hard-codes `.program` (round 3). |

## Accessibility sizes

The Now slab's label row stacks "ACTIVE BLOCK" over "OPEN ›".
This week rows put the status under the name; a day group keeps its weekday on its first row only.
Planned cards and routine rows keep their chevrons on the first line.
Every row is sized by its text with a 44pt minimum; nothing truncates.

## Dark mode

Same tokens as Today: `bruInk` slabs on `bruBg`, paper cards on `bruBg2`.
