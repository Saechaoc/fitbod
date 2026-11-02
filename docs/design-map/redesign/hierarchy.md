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
| Notice row | At most one: "Consider a deload · 3 signals ›" with an active block, or "Summer Block finished · Review ›" without one; none while a workout is open | Advice or an overdue action, one line, with its own action. |
| Hero | One state slab: label, name, one meta line, the signal button, an optional ghost | The answer to "what now". Ink slab when there is something to start, paper slab when there is not. |
| Exercises | Section head "Exercises · 5" with "View ›", numbered rows "Bench Press · 3 × 5-8" | What the workout holds. Only with a scheduled or suggested session. No chips, no warm-up counts. |
| Secondary action | One ghost row: "Choose another session ›" | The escape hatch D-163 asks for, without a second signal. |
| This week | One row: "This week · 2 workouts · 20 sets ›" | The link to the analytics, not the analytics. Opens Volume. |

Nothing else.
The volume bars, the heatmap, the day streak, the all-time workout count and the week cells leave Today; functionality-map.md says where each goes.
Today never creates a block: planning lives on Program (O-12 in [open-decisions.md](open-decisions.md)).

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
| T-RESUME | A workout has no `completedAt` | Ink: RESUME · Push A · started 12:05 · 4 sets logged | Resume ▸ | Discard (asks first when sets exist) | Plan line with a block, this week |
| T-DONE | A workout with logged sets that started today has finished, with or without a block | Paper: DONE · Push A · 47 min · 15 sets; "Next: Pull A · Sat", "Next up: Pull A", or no next line | none | Start another workout › | Plan line with a block, review notice if pending (no block), this week |
| T-READY | No active block, a ready block exists (the oldest saved, then name) | Ink: READY · Spring Block · 6 weeks · 3 phases · Push Pull Legs | Start block ▸ | Open › (Block overview) | "Start a workout instead ›" row, review notice if pending, this week |
| T-FIX | Active block, `.emptySplit`, or the scheduled session has no exercises | Paper: "Push Pull Legs has no sessions" with Go to routine ▸ (ink), or "Push B has no exercises" with Add exercises ▸ (ink) | none | "Choose another session ›" in the empty-session case | Plan line, this week |
| T-ATTACH | Active block whose routine is nil (defensive: the UI cannot produce it, restored data can) | Paper: "Spring Block has no routine. End it to plan a new one." with Open block ▸ (ink) | none | none | Plan line, this week |
| T-REST | Active block, `.restDay` | Paper: REST DAY · Next: Pull A · Sat | none | Start a workout anyway › | Plan line, this week |
| T-TODAY | Active block, `.session(slot)` with exercises | Ink: TODAY (weekday mode) or NEXT UP · 2 OF 3 (rotation) · Push A · 5 exercises · 15 sets · ~47 min | Start workout ▸ | Choose another session › | Plan line, exercises, this week |
| T-PICK | No block, at least one routine with a session that has exercises | Ink: NEXT UP · PUSH PULL LEGS · Pull A · 5 exercises · 15 sets · ~47 min | Start workout ▸ (with the session's slot) | Choose another session › | Review notice if pending, exercises, this week |
| T-FIRST | No block, no routine with a session that has exercises | Paper: BUILD YOUR FIRST ROUTINE + one sentence | + New routine | "Start a workout ›", only when a session with exercises sits in no live routine | Review notice if pending. No this-week row. |

"Today" for T-DONE is the day of `startedAt` in the calendar from the environment, so a workout that ran past midnight stays with the day it began.
T-DONE's next line names what the resolver returns for the next training day (weekday mode), the resolver's next slot (rotation), or the T-PICK suggestion (no block), and is left out when none exists.
T-DONE outranks T-READY: on a day with a finished workout the day is done, and the ready block keeps START BLOCK ▸ on Program's slab and takes Today's hero again the next day (round 2).
T-READY outranks T-PICK: a block is built to be started, and "Start a workout instead ›" costs one tap.

The two notice rows:

| Notice | When | Action |
| --- | --- | --- |
| "Consider a deload · 3 signals ›" | An active block, no open workout, `DeloadAdvisor.evaluate` returns an advisory, the deload alert setting is on, it is not dismissed this week, and the current phase is not a deload | Opens the signals sheet; Dismiss hides it for the week |
| "Summer Block finished · Review ›" | No active block, no open workout, and `pendingReviewBlocks` returns the latest-ended unreviewed block | Opens BlockReviewView as a sheet; closing it by any route writes `reviewedAt`, so the row clears |

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
| Resume banner | Only with a workout in progress: a paper row with Resume ▸ and a visible Discard | Takes the signal; START BLOCK ▸ goes ink and the current day's "Today ▸" reads "In progress"; nothing else restyles. |
| Now | Ink slab for the active block: "● Active block … Open ›", the name, "Week 3 of 5 · Intensification" or "Plan complete", the routine name (with "· Rotation" for rotation blocks) | The lifter's current work, first and largest. The user's own mock-up (`bru-screens/Fitbod-Session/screens/phase-2--program.png`) puts it here. The week cells stay on Block overview (O-13). |
| This week | Day rows: Mon Legs A ✓ 52 min, Tue Arms ✓ 35 min (off-plan), Wed rest, Thu Push A · Today ▸, Sat Pull A | The block's rhythm. Weekday mode lists the seven days with whatever was logged on each, off-plan workouts included; rotation lists the slots with their latest logged date and the next one. "Today ▸" is the page's one forward action. |
| Planned | Cards for ready and draft blocks: chip, name, "6 weeks · 3 phases · Push Pull Legs", then "Saved Oct 3" or the missing piece | What comes next. The ready card carries Start block ▸ when nothing is active. |
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
| P-PLANNED | Ready or draft blocks, none active | Start block ▸ on the ready slab | The first ready block (oldest saved, then name) as an ink slab; Planned for the rest; Routines; Past if any. A draft without a routine reads "No routine yet". |
| P-ACTIVE | An active block | none ("Today ▸" in This week is ink text) | Now, This week, Planned if any, Routines, Past if any. |
| P-RESUME | Any state with a workout in progress | Resume ▸ in the banner | The banner above the page; "Today ▸" hidden while a workout is open. |
| P-PAST | Only completed blocks | + New block (empty-section link) | Blocks: "No block planned. + New block". Routines. Past. |

The ready slab's Start block ▸ shows only when no block is active, so it never needs the swap confirmation.
Starting a ready block while another runs stays in Block overview, where "Start Block?" asks first.
Program shows no review notice: Today carries it, and the review is one tap inside Past blocks.

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

Block overview's "n / m SESSIONS DONE" becomes "n / m workouts done" under the same rule.
Program's READY and DRAFT chips are outlined ink; it draws no filled chip, because the active block is the Now slab, not a card.
Block overview's own status label is out of scope.
