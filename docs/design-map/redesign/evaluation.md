# Evaluation against the brief

The brief's five criteria, checked against the proposal.
"Verified" means the layouts show it; "needs the build" means only a running screen can prove it.
Counts come from `screen_budget.py`; this file quotes them and does not keep its own.

## 1. Five-second test: purpose and next action

One row per state in [hierarchy.md](hierarchy.md).

| Screen, state | What the lifter sees first | Next action | Status |
| --- | --- | --- | --- |
| Today, T-RESUME | RESUME · PUSH A · started 12:05 | RESUME ▸, the only orange element | Verified |
| Today, T-READY | READY · SPRING BLOCK | START BLOCK ▸ | Verified; the review notice above it is one row with its own › |
| Today, T-DONE | DONE · PUSH A and what comes next | None required; "Start another workout" as a ghost | Verified; outranks T-READY on the day of a workout |
| Today, T-FIX | "Routine has no sessions" or "Push B has no exercises" | GO TO ROUTINE ▸ or ADD EXERCISES ▸ in ink | Verified |
| Today, T-ATTACH | "Block has no routine" | OPEN BLOCK ▸ in ink, leading to END BLOCK | Verified; the state is defensive |
| Today, T-REST | REST DAY and the next training day | None required; "Start a workout anyway" as a ghost | Verified; the next day needs Phase 2 |
| Today, T-TODAY | The plan line, then an ink slab with TODAY and the session name | START WORKOUT ▸, the only orange element | Verified in the wireframe; needs the build for the fold |
| Today, T-PICK | NEXT UP · PUSH PULL LEGS · PULL A | START WORKOUT ▸ | Verified |
| Today, T-FIRST | BUILD YOUR FIRST ROUTINE | + NEW ROUTINE | Verified |
| Program, P-EMPTY | START WITH A ROUTINE | + NEW ROUTINE | Verified |
| Program, P-ROUTINE | BLOCKS · No block yet | + NEW BLOCK text link | Verified |
| Program, P-PLANNED | READY · SUMMER BLOCK | START BLOCK ▸ | Verified |
| Program, P-ACTIVE | The active block slab with week, phase, routine | TODAY ▸ in This week (Phase 2), or nothing; in Phase 1 only the slab's OPEN › | Verified |
| Program, P-RESUME | The resume banner | RESUME ▸ | Verified |
| Program, P-PAST | BLOCKS · No block planned | + NEW BLOCK text link | Verified |

Before: Today's first element was a row of zeros and the action was the fourth element (A-01).

## 2. Common workout tasks immediately accessible

Taps as `screen_budget.py` counts them; "current" comes from `docs/design-map/workflows/*.md`.

| Task | Taps before | Taps after |
| --- | --- | --- |
| Start today's workout | 1 | 1 |
| Resume a workout | 1 | 1 |
| Start another session while a block runs | 4 | 2 |
| Start a workout on a rest day | 4 | 2 |
| See this week's muscle volume from Today | a scroll | 1 |
| Start the ready block after one ends | 4 from Today, via Program | 1 |
| Open the review right after a block ends | opens by itself | 1 (the notice; it goes once the next block starts, O-5) |
| Reopen a finished block's review | not possible after the first sheet | 4 from Today (tab, Past blocks, block, Review) |
| End a block whose plan is over | 3 | 3 (plan line, END BLOCK, End Block) |
| See muscle volume from Progress | not possible | 1 |
| First launch to first workout | about 17 | about 15 (estimate, verify in Phase 1) |

Every everyday task fits the two-tap budget.

## 3. Detailed training analysis easy to find

Muscle volume and the heatmap move to Progress › Volume, reachable in one tap from Today's this-week row and in one tap from Progress.
Before, it was only a long scroll on Today and absent from Progress (D-131).
The Volume screen keeps the deload advisory ring by evaluating the advisor on appear.
History, PRs, tonnage, comparison and recaps stay on Progress.
The block's week strip, scheduling and archive stay on Block overview, one tap from either tab's block row.

## 4. Empty, active and data-rich states all intentional

Today has nine states, one with two fix-it variants, and Program six, each with a wireframe and a stated signal element.
Zero-value rows go: the stat strip's zeros, the 17 muscle rows on a fresh store, the zero WORKING SETS slab, and the this-week row on T-FIRST.
Needs the build: the this-week row on a week with no workouts reads "0 workouts · 0 sets" and may still be noise; Phase 1 acceptance checks it.

## 5. Every visible element earns its prominence

The rule "one signal element per screen" is stated in [hierarchy.md](hierarchy.md) and applied in every wireframe.
Removed because they earned nothing: the phase chip, the week cells on Today and on Program's Now slab, the DAY counter, the days-left count, the COMPOUND and WORK chips, the block band's BLOCK chip, the READY chip's accent, the four decorative chips on empty Program, the 68pt NO PROGRAM, the template section, the deload banner, the deload chip and the DL badge.
`screen_budget.py` reports two states over the element budget, both accepted because they are transient: P-RESUME, where the resume banner adds exactly its three elements to P-ACTIVE, and T-TODAY with a deload advisory, where the notice adds one row until it is acted on or dismissed.
With no state over budget, the script's hotspot is the longest job: first launch to first workout, about 15 taps, an estimate Phase 1 verifies.
The next longest job, reopening a finished block's review, takes four taps from Today, which is the price of O-5 (no notice for a block that ended because the next one started).
