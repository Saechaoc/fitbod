# Today layouts

One wireframe per state in [hierarchy.md](hierarchy.md), drawn at 390pt with 16pt gutters (358pt of content).
Every element names the BRU component that draws it.
Copy is final unless marked "draft".

Legend: `════` 2pt ink rule, `────` 1pt hair rule, `█` ink slab, `[ TEXT ▸ ]` BRUButton, `›` chevron on a tappable row.

## T-TODAY, weekday block, session scheduled

```
┌──────────────────────────────────────────────┐
│ SETTINGS        FITBOD / TODAY   THU · MAY 22│  BRUHeaderBar
╞══════════════════════════════════════════════╡
│ SPRING BLOCK                                 │  plan line, line 1 (ink)
│ WEEK 2 OF 6 · ACCUMULATION                  ›│  plan line, line 2 (muted)
├──────────────────────────────────────────────┤
│ ████████████████████████████████████████████ │
│ █ TODAY                                    █ │  label
│ █                                          █ │
│ █ PUSH A                                   █ │  BRUDisplay .large
│ █ 5 EXERCISES · 15 SETS · ~47 MIN          █ │  mono caption
│ █                                          █ │
│ █ [ START WORKOUT ▸                      ] █ │  BRUButton .signal .lg
│ ████████████████████████████████████████████ │
│                                              │
│ EXERCISES · 5                         VIEW › │  BRUSectionHead
│ 01  Bench Press                       3 × 5-8│  LiftListRow: working sets × rep range
│ 02  Incline DB Press                 3 × 8-12│
│ 03  Overhead Press                    3 × 5-8│
│ 04  Lateral Raise                   3 × 12-15│
│ 05  Triceps Pushdown                3 × 10-12│
├──────────────────────────────────────────────┤
│ Choose another session                      ›│  ghost row
├──────────────────────────────────────────────┤
│ THIS WEEK            2 workouts · 20 sets   ›│  this-week row
└──────────────────────────────────────────────┘
```

| Element | Component | Notes |
| --- | --- | --- |
| Header | BRUHeaderBar(left: Settings, center: "Fitbod / Today", right: date) | Unchanged. The date already reads "THU · MAY 22". |
| Plan line | Button(.bruRow), two Texts stacked | Line 1: the block name, labelSmall uppercase ink, `lineLimit(1)` with tail truncation. Line 2: `BlockPosition.label`, labelSmall muted, never truncates. Chevron centred on the right. 56pt tall. Opens Block overview (BlockOverviewRoute.summary). Replaces TodayStatStrip, BlockContextBand and WeekTickerCells. |
| Hero | BlackSlabCTA | Label "TODAY" replaces "NEXT" and "DAY 04 / 28". Name, summary line and button unchanged. The set count sums each exercise's working sets from `workingSetCount(targetSets:phase:)`, the helper `SessionFactory` calls too (step 1.2). |
| Exercises head | BRUSectionHead("Exercises · 5", right: "View ›") | "View ›" opens the session's detail (SessionTemplateDetailView), the screen the picker row opens today. |
| Exercise rows | LiftListRow without the chip | Subline "3 × 5-8": working sets from the same helper, then the rep range, the format the row already uses for exercises without a ramp. The fixed "2 warm-up" goes: the factory never reads `generateWarmups` and ramps only the first qualifying compound, so that count was wrong on most rows; the logger shows the real ramp. Rows stay non-interactive, as now. |
| Choose another session | Button(.bruRow), ghost text, chevron | Opens the session sheet below. |
| This week | Button(.bruRow) with BRUReadout-style label | "THIS WEEK" label, then "2 workouts · 20 sets", chevron. Both are raw counts: finished workouts with logged sets this week (`countedWorkouts`), and their working sets through `FatigueModel.completedWorkingSets`, filtered to those workouts so an open workout's sets never count. Computed in a `.task(id:)` keyed on the finished workout IDs and the week start (`mondayAtMidnightForToday` with the environment calendar), not in `body`, so it rolls over on Monday. Opens Volume, pushed on Today's stack. |

Above the fold at 844pt: header, plan line, hero and the exercise head.

## T-TODAY, rotation block, deload week

Only the lines that differ from the weekday wireframe.

```
│ SPRING BLOCK                                 │
│ WEEK 5 OF 5 · DELOAD                        ›│
│ █ NEXT UP · 2 OF 3                         █ │  label: rotation has no weekday; position in the cycle
│ █ PUSH A                                   █ │
│ █ 5 EXERCISES · 5 SETS · ~17 MIN           █ │  the working sets the logger will generate; 5 × 3 + 2 minutes
│ █ DELOAD WEEK · LIGHTER SETS               █ │  second caption, muted
│ ...                                          │
│ 01  Bench Press                       1 × 5-8│  working sets after the multiplier
```

No DELOAD WEEK banner, no DELOAD chip, no DL badge.
The hero's set count and the exercise sublines show the working sets the logger will generate.
`SessionFactory` already cuts working sets to floor(`targetSets` × the phase's volume multiplier), at least one, in a deload phase; Today reads the raw `targetSets` instead.
Step 1.2 moves that rule into `workingSetCount(targetSets:phase:)`, which the hero, the sublines and the factory all call.
Warm-ups stay the logger's: `WarmupRamp` needs the top weight, the bar and the session's first compound, so Today says nothing about them (round 2).
The "Consider a deload" notice is hidden while the current phase is a deload.

## T-TODAY with the advisory notice

The notice row sits between the plan line and the hero.
It is one 44pt row with a hair rule under it.

```
│ SPRING BLOCK                                 │
│ WEEK 6 OF 6 · PEAK                          ›│
├──────────────────────────────────────────────┤
│ CONSIDER A DELOAD · 3 SIGNALS ›      DISMISS │  DeloadAdvisoryBanner, one line
├──────────────────────────────────────────────┤
│ ████████████████████████████████████████████ │  hero as above
```

| Notice | Component | Action |
| --- | --- | --- |
| Consider a deload | DeloadAdvisoryBanner reduced to one line | Row opens DeloadSignalDetailSheet; DISMISS, a text button with `.bruHitArea()`, hides it for the week as the "✕" does now (the glyph table has no close mark, and "×" means times). Shown only when the deload alert setting is on and the phase is not a deload. |

With the notice, two elements sit before the button: the plan line and the notice.

## T-TODAY, plan complete

```
│ SPRING BLOCK                                 │
│ PLAN COMPLETE                               ›│  plan line, line 2
├──────────────────────────────────────────────┤
│ ████████████████████████████████████████████ │  hero as above
```

The block stays active and Today keeps scheduling, so the lifter can finish a late week.
Ending the block stays on Block overview, one tap away through the plan line: plan line › END BLOCK › End Block.
The dialog's body changes to "Ends Spring Block and saves its plan to history. New workouts will not count toward it."

## T-RESUME

```
│ SPRING BLOCK                                 │
│ WEEK 2 OF 6 · ACCUMULATION                  ›│  plan line (absent without a block)
├──────────────────────────────────────────────┤
│ ████████████████████████████████████████████ │
│ █ RESUME                                   █ │
│ █ PUSH A                                   █ │
│ █ STARTED 12:05 · 4 SETS LOGGED            █ │
│ █ [ RESUME ▸                             ] █ │  BRUButton .signal .lg
│ █   DISCARD                                █ │  ghost; confirms when sets exist
│ ████████████████████████████████████████████ │
├──────────────────────────────────────────────┤
│ THIS WEEK            2 workouts · 20 sets   ›│
```

ResumeWorkoutSlab unchanged except the plan line above it.
No exercise list: the open workout is one tap away and lists them itself.
No notice row: the deload advisory and a pending review wait until the workout is finished.

## T-DONE

```
│ SPRING BLOCK                                 │
│ WEEK 2 OF 6 · ACCUMULATION                  ›│
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ DONE                                     │ │  paper slab, 2pt ink border
│ │ PUSH A                                  ›│ │  BRUDisplay .large; slab opens the workout
│ │ 47 MIN · 15 SETS · 2 PRS                 │ │  mono caption
│ │ NEXT: PULL A · SATURDAY                  │ │  weekday mode; rotation reads "NEXT UP: PULL A"
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ Start another workout                       ›│  ghost row → session sheet
├──────────────────────────────────────────────┤
│ THIS WEEK            3 workouts · 35 sets   ›│
```

No signal element on the page.
The slab is a Button(.bruRow) that opens the finished workout's history detail (SessionHistoryRoute).
"2 PRS" shows only when the workout set a PR; the caption otherwise ends at the set count.
The next line is left out when nothing can be named: an emptied routine, or no routine with a session.
Without a block the slab has no plan line above it and the next line reads "NEXT UP: PULL A · PUSH PULL LEGS".
Without a block and with a review pending, the review notice sits above the slab (see "The review notice").
T-DONE outranks T-READY: on a day with a finished workout the ready block waits on Program's slab and takes Today's hero again the next day (round 2).

## T-REST

```
│ SPRING BLOCK                                 │
│ WEEK 2 OF 6 · ACCUMULATION                  ›│
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ REST DAY                                 │ │
│ │ NEXT: PULL A · SATURDAY                  │ │  Phase 2; Phase 1 shows only "REST DAY"
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ Start a workout anyway                      ›│  ghost row → session sheet
├──────────────────────────────────────────────┤
│ THIS WEEK            2 workouts · 20 sets   ›│
```

Only weekday blocks have rest days.
"NEXT" names the next training day from `Block.trainingDays` and the slot the resolver will pick that day.

## T-READY

```
├──────────────────────────────────────────────┤
│ SUMMER BLOCK FINISHED                REVIEW ›│  notice row, only while the review is pending
├──────────────────────────────────────────────┤
│ ████████████████████████████████████████████ │
│ █ READY                                    █ │
│ █ SPRING BLOCK                             █ │
│ █ 6 WEEKS · 3 PHASES · PUSH PULL LEGS      █ │
│ █ [ START BLOCK ▸                        ] █ │  BRUButton .signal .lg
│ █   OPEN ›                                 █ │  ghost → Block overview
│ ████████████████████████████████████████████ │
├──────────────────────────────────────────────┤
│ Start a workout instead                     ›│  ghost row → session sheet
├──────────────────────────────────────────────┤
│ THIS WEEK            0 workouts · 0 sets    ›│
```

START BLOCK ▸ calls the same service the overview's Start uses (`BlockLifecycleService.start`), with no confirmation because nothing is active.
The call can still throw, because a block's status is live; the error shows a "Couldn't start block" alert with "Try again" and "Open block".
The next appear re-resolves and Today becomes T-TODAY, T-REST or T-FIX.
With more than one ready block the oldest saved takes the hero (`startDate`, which the builder stamps at save and `start` overwrites), then by name; the others stay on Program (O-6).
A draft block never shows on Today; Program's Planned section names what it is missing.
On a day with a finished workout T-DONE shows instead; START BLOCK ▸ stays on Program's P-PLANNED slab, and Today offers the block again tomorrow (round 2).
Tapping START BLOCK ▸ under a pending review starts the block and the notice goes with it, because `pendingReviewBlocks` returns nothing while a block is active; the review waits in Program › Past blocks (O-5).

## The review notice

```
│ SUMMER BLOCK FINISHED                REVIEW ›│  notice row above the hero on every state without an active block except T-RESUME
```

It shows on T-READY, T-DONE (no block), T-PICK and T-FIRST, and never while a workout is open.
This replaces the review sheet that opens by itself on Today's first appear.
The row is two Texts: "Summer Block finished" with `lineLimit(1)` and tail truncation, and "REVIEW ›", which never truncates, so a long name loses its tail and not the action.
REVIEW › opens BlockReviewView as a sheet.
Closing the sheet by any route (Back, swipe, "Plan custom" or "Start next ▸") writes `reviewedAt`, so the row clears and the hero below it stays what it was.
That is a change to BlockReviewView: today only "Start next ▸" acknowledges, which the design map records as D-06.
"Start next ▸" still acknowledges and opens the block builder from the review's own sheet (`pendingNextBlockBuilder` in BlockReviewView), the one block creation reachable from Today (O-12).
The review stays reachable afterwards from Program › Past blocks (see [program-layouts.md](program-layouts.md)).

## T-PICK, no block, routines exist

```
│ ████████████████████████████████████████████ │
│ █ NEXT UP · PUSH PULL LEGS                 █ │  label names the routine
│ █ PULL A                                   █ │
│ █ 5 EXERCISES · 15 SETS · ~47 MIN          █ │
│ █ [ START WORKOUT ▸                      ] █ │
│ ████████████████████████████████████████████ │
│                                              │
│ EXERCISES · 5                         VIEW › │
│ 01  Lat Pulldown                       3 work│
│ ...                                          │
├──────────────────────────────────────────────┤
│ Choose another session                      ›│
├──────────────────────────────────────────────┤
│ THIS WEEK            1 workout · 15 sets    ›│
```

The suggested session is the slot after the newest finished workout whose slot belongs to a routine that is not archived, in that routine.
With no such workout it is the first session with exercises in the routine that holds the most recently updated session (`SessionTemplate.updatedAt`).
START WORKOUT ▸ passes the suggested slot to `WorkoutStarter`, so the next workout moves the suggestion on.
Such a workout has a slot and no block, and `TodayResolver` ignores it for any later block because its anchor filter is by block.
Sessions with no exercises are skipped.
This replaces the picker's four orange START ▸ buttons with one.
No block offer here: planning a block is Program's job (O-12).

## T-FIRST, fresh store

```
│ SETTINGS        FITBOD / TODAY   THU · MAY 22│
╞══════════════════════════════════════════════╡
│                                              │
│ BUILD YOUR FIRST ROUTINE                     │  condensedHeading
│ A routine is your split, like Push / Pull /  │  paragraph, as now
│ Legs. Each session in it lists exercises     │
│ with target sets and reps.                   │
│                                              │
│ [ + NEW ROUTINE                            ] │  BRUButton .signal .lg → NewRoutineRoute.name
│                                              │
│ Start a workout                             ›│  ghost row, only when a session with exercises sits in no live routine
└──────────────────────────────────────────────┘
```

Nothing else: no stat cells, no block offer, no volume slab, no this-week row.
The ghost row is the one exception: when a session with exercises exists outside every live routine, it opens the session sheet, whose "Other sessions" group lists that session, so D-24 closes for a lifter who never built a routine (round 2).
"Split" here is the gym word, not the code name the glossary bans.
A block cannot be made from Today, which closes D-162 and D-24's blank-picker path.

## T-FIX and T-ATTACH

```
│ SPRING BLOCK                                 │
│ WEEK 1 OF 6 · ACCUMULATION                  ›│
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ ROUTINE HAS NO SESSIONS                  │ │  condensedHeading
│ │ Add a session to Push Pull Legs to train │ │
│ │ from this block.                         │ │
│ │ [ GO TO ROUTINE ▸                      ] │ │  BRUButton .primary .lg (ink) → SplitDetailRoute
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ THIS WEEK            0 workouts · 0 sets    ›│
```

The empty-session variant, when the scheduled slot's session has no exercises:

```
│ ┌──────────────────────────────────────────┐ │
│ │ PUSH B HAS NO EXERCISES                  │ │
│ │ Add exercises to Push B to train it.     │ │
│ │ [ ADD EXERCISES ▸                      ] │ │  ink → SessionTemplateDetailView
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ Choose another session                      ›│  ghost row → session sheet
```

T-ATTACH is the same slab with "BLOCK HAS NO ROUTINE", "End Spring Block to plan a new one." and [ OPEN BLOCK ▸ ] → Block overview.
Block overview already shows "+ ATTACH ROUTINE ▸" only on draft and ready blocks (`BlockOverviewScreen.swift:299-302`), so END BLOCK is the one action there and the overview needs no change for this state (round 2).
The UI cannot produce an active block without a routine (a split in use cannot be deleted, and a block cannot start without one); the state exists for restored data.
All three use the ink primary button: the fix is required, but it is not the lifter's training action.

## Session sheet

Opened by "Choose another session", "Start another workout", "Start a workout anyway" and "Start a workout instead".

```
┌──────────────────────────────────────────────┐
│ CANCEL          START A WORKOUT              │  BRUHeaderBar, Cancel in the left slot (P-8)
╞══════════════════════════════════════════════╡
│ PUSH PULL LEGS                               │  routine name, labelSmall muted
│ Push A                                       │  Button(.bruRow): tapping starts the workout
│ 5 exercises · 15 sets · skips Pull A, Legs A │  rotation blocks only: what a swap leaves out this cycle
│ Pull A                                  NEXT │  the slot the resolver returns, muted
│ 5 exercises · 15 sets                        │
│ Legs A                                       │
│ No exercises yet                             │  disabled row
│ UPPER LOWER                                  │
│ Upper A                                      │
│ ...                                          │
│ OTHER SESSIONS                               │  sessions in no routine (D-24)
│ Arms                                         │
└──────────────────────────────────────────────┘
```

TodaySessionPicker's grouping and empty handling carry over, with each session listed once in the order of its first slot, plus an "Other sessions" group for session templates that sit in no live routine.
Rows start the workout on tap, with no separate START ▸ button and no signal colour.
A row of the active block's routine passes a slot: the resolver's next slot when it holds this session, else the first slot after it that holds this session, wrapping round, so a session slotted twice (PPL ×2) never moves the rotation backwards (O-2, round 2).
With no block, a row passes a slot under the same rule, anchored at the T-PICK suggestion when the row's routine is the suggestion's routine and at the routine's first slot otherwise, so the suggestion moves after a sheet start too.
A session in no live routine, or in a routine other than the active block's, starts unslotted.
In a rotation block, a row of the active routine that is not NEXT ends its subline with "skips Pull A, Legs A": the sessions in the slots between NEXT and the slot it passes, which the anchor moves past for this cycle (O-2).
A session with no exercises shows "No exercises yet" and does not start.
A mis-tap costs two taps: the logger's ‹ leaves the empty workout open, Today shows RESUME, and its DISCARD asks nothing when no sets are logged.
Session detail for sessions other than the hero (preview, edit, last workout) moves to Program › routine › session; the hero's detail stays behind the Exercises head's "View ›".

## Progress › Volume

The whole of FatigueSurfaceView moves here inside a new VolumeScreen: BRUHeaderBar with Back, a ScrollView, the WORKING SETS slab, the legend, the muscle bars that open MuscleSlugRoute.detail, and the FRONT/BACK heatmap.
The screen evaluates `DeloadAdvisor` on appear, so the advisory ring on the bars survives the move.
A `VolumeRoute` is registered on Today's and Progress's stacks, with `MuscleSlugRoute` registered on Progress too.
Today's this-week row and a new "Volume" entry on Progress both push it.
Phase 2 collapses muscles with no sets this week into one row, "9 muscles not trained yet ›", which expands in place.
The heatmap's "W44 / 53" label becomes the week's dates, "May 19 - 25".

## Accessibility sizes

At accessibility text sizes the plan line's name wraps to two lines and the position line follows it; the chevron stays centred.
The hero stacks as now.
The this-week row puts its label above its numbers.
The notice row puts its action under its text.
Every tappable row is at least 44pt tall at every size.

## Dark mode

Ink slabs draw with `bruInk` on `bruBg`; paper slabs use `bruBg2` with a `bruInk` border.
No new colours.
