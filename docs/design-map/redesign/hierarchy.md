# Hierarchy

Each screen gets one purpose, one primary question and one obvious next action.
The rule that drives both screens: **one signal element per screen, and a workout in progress always takes it.**

## Today

Purpose: do today's training.
Primary question: what do I do right now?
Next action: one signal button whose label changes with the state (Start workout ▸, Resume ▸, Start block ▸, + New routine).
When the day is done, there is no signal button at all.

### Zones, top to bottom

| Zone | What it holds | Why it is here |
| --- | --- | --- |
| Header | BRUHeaderBar: Settings, "Fitbod / Today", the date with its weekday | Same chrome as the other tabs. The date says which day's plan this is. |
| Plan line | One tappable two-line row: the block name, then "Week 2 of 6 · Accumulation" or "Plan complete" › | The only block context on Today. It replaces the stat strip, the block band and the week cells. It opens Block overview, where Edit, End and the week strip live. Absent without an active block. |
| Notice row | At most one: "Summer Block finished · Review ›" while a review is pending (no block is active then), else "Consider a deload · 3 signals ›" when an advisory is due, with or without a block; none while a workout is open | Advice or an overdue action, one line, with its own action. The review comes first because it is overdue and the advice can wait. |
| Hero | One state slab: label, name, one meta line, the signal button, an optional ghost | The answer to "what now". Ink slab when there is something to start, paper slab when there is not. |
| Exercises | Section head "Exercises · 5" with "View ›", numbered rows "Bench Press · 3 × 5-8" | What the workout holds. Only with a scheduled or suggested session. No chips, no warm-up counts. |
| Secondary action | One ghost row: "Choose another session ›" | The escape hatch D-163 asks for, without a second signal. |
| Volume row | One row: "Volume this week · 2 workouts · 20 sets ›" | The link to the analytics, not the analytics. Its label names the destination (round 3). Opens Volume. |

Nothing else.
The volume bars, the heatmap, the day streak, the all-time workout count and the week cells leave Today; functionality-map.md says where each goes.
Today never creates a block, except through the review sheet's own "Start next ▸" (O-12 in [open-decisions.md](open-decisions.md)): planning lives on Program.

### Workout actions and weekly analytics

Today's job is "what now".
The muscle volume list and heatmap answer "am I doing enough this week", which the lifter asks on a rest day or at the week's end, not while deciding whether to start.
So Today keeps one line of this week's facts with a link, and the full surface (summary slab, legend, 17 bars, heatmap, per-muscle detail) moves to Progress as a Volume screen that both tabs can push.
This also closes D-131: Progress gains the entry it lacks.
The deload advisory stays on Today as a notice row, because it changes what the lifter should do today.

### State table

Precedence runs top to bottom; the first row that matches wins the hero.
The notice row is independent of the hero, except that T-RESUME shows none.

| State | When | Hero | Signal | Ghost | Also on the page |
| --- | --- | --- | --- | --- | --- |
| T-RESUME | A workout has no `completedAt` | Ink: RESUME · Push A · started 12:05 · 4 sets logged | Resume ▸ | Discard (asks first when sets exist) | Plan line with a block, volume row |
| T-DONE | A workout with logged sets that started today has finished, with or without a block | Paper: DONE · Push A · 47 min · 15 sets, one name row per finished workout, newest first; "Next: Pull A · Sat", "Next up: Pull A", or no next line | none | Start another workout › | Plan line with a block, review notice if pending (no block), volume row |
| T-READY | No active block, a ready block exists (the oldest created, then name, then id) | Ink: READY · Spring Block · 6 weeks · 3 phases · Push Pull Legs · Created Oct 3 | Start block ▸ | Open › (Block overview) | "Start a workout instead ›" row, review notice if pending, volume row |
| T-FIX | Active block with `.emptySplit` or a scheduled session without exercises; or no block, a live routine, and no session with exercises anywhere | Paper: "Push Pull Legs has no sessions" or "Push Pull Legs has no exercises yet" with Go to routine ▸ (ink), or "Push B has no exercises" with Add exercises ▸ (ink) | none | "Choose another session ›" under a block, when a session with exercises exists anywhere (round 3) | Plan line and volume row with a block; without one, only the review notice if pending (round 3, V4-F6) |
| T-ATTACH | Active block whose routine is nil (defensive: the UI cannot produce it, restored data can) | Paper: "Spring Block has no routine. End it to plan a new one." with Open block ▸ (ink) | none | "Choose another session ›" when a session with exercises exists anywhere (round 3) | Plan line, volume row |
| T-REST | Active block, `.restDay` | Paper: REST DAY · Next: Pull A · Sat | none | Start a workout anyway › | Plan line, volume row |
| T-TODAY | Active block, `.session(slot)` with exercises | Ink: TODAY (weekday mode) or NEXT UP · 2 OF 3 (rotation) · Push A · 5 exercises · 15 sets · ~47 min | Start workout ▸ | Choose another session › | Plan line, exercises, volume row |
| T-PICK | No block, a session with exercises in a live routine or in none | Ink: NEXT UP · PUSH PULL LEGS · Pull A · 5 exercises · 15 sets · ~47 min; a session in no routine reads NEXT UP · Arms | Start workout ▸ (with the session's slot; none for a session in no routine) | Choose another session › | Review notice if pending, exercises, volume row |
| T-FIRST | No block, no live routine, no session with exercises | Paper: BUILD YOUR FIRST ROUTINE + one sentence | + New routine | none | Review notice if pending. No volume row. |

"Today" for T-DONE is the day of `startedAt` in the calendar from the environment, so a workout that ran past midnight stays with the day it began.
T-DONE's next line, T-REST's next line, the session sheet's NEXT mark and Program's start controls all name one value, NEXT (round 3).
In a rotation block NEXT is the resolver's next slot.
In a weekday block NEXT is today's slot while today is a training day and no counted workout started today, else the slot the resolver returns for the next training day, the first day after today whose weekday is in `trainingDays` (`StartSlot.nextTrainingDate`, which Block overview keeps for its NEXT cell; round 3, V5-F3).
With no block NEXT is the suggestion's routine's NEXT from today-layouts.md: its routine anchor moved past sessions with no exercises, so the hero, the sheet's mark and Program's NEXT ▸ never name an empty session (round 3, B-F2).
The line is left out when nothing can be named.
T-DONE outranks T-READY: on a day with a finished workout the day is done, and the ready block keeps START BLOCK ▸ on Program's slab and takes Today's hero again the next day (round 2).
T-READY outranks T-PICK: a block is built to be started, and "Start a workout instead ›" costs one tap.
Without a block, T-PICK, T-FIX and T-FIRST cannot coincide: a session with exercises anywhere gives T-PICK, a live routine with none gives T-FIX, and neither gives T-FIRST (round 3).

The two notice rows:

| Notice | When | Action |
| --- | --- | --- |
| "Consider a deload · 3 signals ›" | No open workout, no review notice showing, `DeloadAdvisor.evaluate` returns an advisory, the deload alert setting is on, it is not dismissed this week, and the current phase is not a deload; a block is not required (round 3) | Opens the signals sheet; Dismiss hides it for the week |
| "Summer Block finished · Review ›" | No active block, no open workout, and `pendingReviewBlocks` returns the latest-ended block because it is still unreviewed | Opens BlockReviewView as a sheet; closing it by any route writes `reviewedAt`, so the row clears; when that write fails the row stays with "Couldn't save the review. Open it again to retry." under it (round 3, F-F1) |

When both are due the review notice shows and the advisory waits until the review is acknowledged, so a state never shows two notices.
Main already shows the advisory without a block (`refreshAdvisory` checks only the setting), and the redesign keeps that (round 3).

A block that ended because the next one started gets no notice: `pendingReviewBlocks` returns nothing while a block is active, and its tests pin that.
Starting the ready block under the notice has the same effect: the notice goes with the start.
Its review stays reachable from Program › Past blocks (O-5).

The deload week needs no banner, chip or badge: the plan line reads "· Deload", the hero's second caption reads "Deload week · lighter sets", and the hero's set count and the exercise sublines show the working sets the logger will generate, which `SessionFactory` cuts by the phase's volume multiplier in a deload week.

Plan complete needs no notice: the plan line's second line reads "Plan complete" and opens Block overview, where End block lives.

## Program

Purpose: plan what I am running and keep the routines it runs in order.
Primary question: what am I running now, and what comes after it?
Next action, by state: build a routine, plan a block, start the ready block, or open the active block.

### Zones, top to bottom

| Zone | What it holds | Why it is here |
| --- | --- | --- |
| Header | BRUHeaderBar: "Program", "+ New" in ink | The one creation entry (popover: + New block, + New routine), the same on every state. |
| Resume banner | Only with a workout in progress: a paper row with Resume ▸ and a visible Discard | Takes the signal on every underlying state: every other signal control draws in ink, "Today ▸" and "Next ▸" hide, and the open workout shows as "In progress" under its own name on the day it started; nothing else restyles (round 3). |
| Now | Ink slab for the active block: "● Active block … Open ›", the name, "Week 3 of 5 · Intensification" or "Plan complete", the routine name (with "· Rotation" for rotation blocks) | The lifter's current work, first and largest. The user's own mock-up (`bru-screens/Fitbod-Session/screens/phase-2--program.png`) puts it here. The week cells stay on Block overview (O-13). |
| This week | Seven day groups: Mon Legs A ✓ 52 min, Tue Arms ✓ 35 min (off-plan), Wed rest, Thu Push A · Today ▸, Sat Pull A | The block's rhythm. Weekday mode lists each day with one row per workout logged on it, off-plan workouts included, then the planned session while it is not done; rotation lists the slots with their latest logged workout and the next one, and every other workout this week under "Also this week". "Today ▸" (or "Next ▸") is the page's one forward action and shows exactly while Today's state is T-TODAY (round 3). |
| Planned | Cards for ready and draft blocks: chip, name, "6 weeks · 3 phases · Push Pull Legs", then "Created Oct 3" or the missing piece | What comes next. The first ready block takes the slab and carries Start block ▸ when nothing is active; the other ready blocks start from their overview. With drafts only, the newest draft leads as a paper slab with Continue block ▸ in ink (round 3). |
| Routines | Rows: name, "3 sessions · used by Spring Block", › | The building blocks, named under the thing that uses them. Archived routines as a muted last row whenever any exist. |
| Past | One row: Past blocks · 3 › | Finished work, out of the way, one tap to a list. Reviews reopen from there. |

### The relationship, made visible

A block runs one routine; a routine holds sessions; Today shows the session the block schedules.
Program shows the nesting in order: the Now slab names its routine, the routine row names its session count and the block using it, and This week names the sessions by day.
Chips no longer carry the relationship.

### State table

| State | When | Signal | Page |
| --- | --- | --- | --- |
| P-EMPTY | No live routine, no block | + New routine | Header, a paper hero "Start with a routine" with one sentence, "Archived routines · n ›" when any exist. Nothing else. |
| P-ROUTINE | Routines, no block | + New block (empty-section link under Blocks) | Blocks: "No block yet. + New block". Routines list. |
| P-PLANNED | Ready or draft blocks, none active | Start block ▸ on the ready slab; none with drafts only | The first ready block (oldest created, then name, then id) as an ink slab; Planned for the rest; Routines; Past if any. With drafts only, the newest draft as a paper slab with Continue block ▸ in ink, naming what it is missing ("No routine yet"). |
| P-ACTIVE | An active block | none ("Today ▸" in This week is ink text) | Now, This week, Planned if any, Routines, Past if any. |
| P-RESUME | Any state with a workout in progress | Resume ▸ in the banner | The banner above the page; every other signal control in ink; "Today ▸" and "Next ▸" hidden; the open workout as "In progress" on its day. |
| P-PAST | Only completed blocks | + New block (empty-section link) | Blocks: "No block planned. + New block". Routines. Past. |

The ready slab's Start block ▸ shows only when no block is active, so it never needs the swap confirmation.
Starting a ready block while another runs stays in Block overview, where "Start Block?" asks first.
Program shows no review notice: Today carries it, and the review is two taps inside Past blocks (the block, then Review ›).

## Shared vocabulary

One form for each fact, on Today, on Program and in Block overview.

| Fact | Say | Never |
| --- | --- | --- |
| Where the block is | Week 2 of 6 · Accumulation | W2 / 6, ACCUM, INTNS, DAY 04 / 28 |
| A logged workout | workout, "3 / 6 workouts done" | session, SESSIONS, "SESSIONS DONE" |
| A template in a routine | session | routine, Split, SessionTemplate |
| Block status | ACTIVE, READY, DRAFT, DONE | LIVE, PLAN COMPLETE as a status |
| A finished plan | Plan complete, in the block's position line | a status chip with no action |
| Deload | · Deload in the plan line, "Deload week · lighter sets" in the hero | a banner, a DL badge, a chip |
| When a planned block was made | Created Oct 3 | Saved, Starts, Planned for |

Block overview's "n / m SESSIONS DONE" becomes "n / m workouts done" under the same rule.
Program's READY and DRAFT chips are outlined ink; it draws no filled chip, because the active block is the Now slab, not a card.
Block overview's own status label is out of scope.
