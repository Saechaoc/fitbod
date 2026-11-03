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
| Today, T-DONE | DONE · PUSH A and what comes next; one name row per workout when there are two | None required; "Start another workout" as a ghost | Verified; outranks T-READY on the day of a workout |
| Today, T-FIX | "Routine has no sessions", "Push B has no exercises", or, without a block, "Push Pull Legs has no exercises yet" | GO TO ROUTINE ▸ or ADD EXERCISES ▸ in ink; under a block, "Choose another session ›" as a ghost when a usable session exists | Verified |
| Today, T-ATTACH | "Block has no routine" | OPEN BLOCK ▸ in ink, leading to END BLOCK; "Choose another session ›" as a ghost when a usable session exists | Verified; the state is defensive |
| Today, T-REST | REST DAY and the next training day | None required; "Start a workout anyway" as a ghost | Verified; the next day needs Phase 2 |
| Today, T-TODAY | The plan line, then an ink slab with TODAY and the session name | START WORKOUT ▸, the only orange element | Verified in the wireframe; needs the build for the fold |
| Today, T-PICK | NEXT UP · PUSH PULL LEGS · PULL A, or NEXT UP · ARMS for a session in no routine | START WORKOUT ▸ | Verified |
| Today, T-FIRST | BUILD YOUR FIRST ROUTINE (only with no live routine and no session with exercises) | + NEW ROUTINE | Verified |
| Program, P-EMPTY | START WITH A ROUTINE | + NEW ROUTINE | Verified |
| Program, P-ROUTINE | BLOCKS · No block yet | + NEW BLOCK text link | Verified |
| Program, P-PLANNED | READY · SPRING BLOCK · CREATED OCT 3 | START BLOCK ▸; with drafts only, CONTINUE BLOCK ▸ in ink on the newest draft | Verified |
| Program, P-ACTIVE | The active block slab with week, phase, routine | TODAY ▸ in This week (Phase 2) exactly while Today is T-TODAY, or nothing; in Phase 1 only the slab's OPEN › | Verified |
| Program, P-RESUME | The resume banner, on any underlying state | RESUME ▸; every other signal control in ink | Verified |
| Program, P-PAST | BLOCKS · No block planned | + NEW BLOCK text link | Verified |

Before: Today's first element was a row of zeros and the action was the fourth element (A-01).

## 2. Common workout tasks immediately accessible

Taps as `screen_budget.py` counts them; "current" comes from `docs/design-map/workflows/*.md`.

| Task | Taps before | Taps after |
| --- | --- | --- |
| Start today's workout | 1 | 1 |
| Resume a workout | 1 | 1 |
| Start another session while a block runs | 4 | 2 |
| Start a workout on a rest day | 1 (the picker's START ▸, `workflows/today.md`) | 2 (the ghost row, then the session); one tap more, the price of one signal per screen |
| Preview a non-hero session before starting it | 1 | 3 (Program, the routine, the session), not an everyday job |
| See this week's muscle volume from Today | a scroll | 1 |
| Start the ready block after one ends | 4 from Today, via Program | 1 on a day with no counted workout; 2 on a day with one (T-DONE wins; Program's slab) |
| Open the review right after a block ends | opens by itself | 1 (the notice; it goes once the next block starts, O-5) |
| Reopen a finished block's review | not possible after the first sheet | 4 from Today (tab, Past blocks, block, Review) |
| End a block whose plan is over | 3 | 3 (plan line, END BLOCK, End Block) |
| See muscle volume from Progress | not possible | 1 |
| First launch to first workout | about 17 | about 15 (estimate, verify in Phase 1) |

Every everyday task fits the two-tap budget; the rest-day start and the non-hero preview each cost more taps than today, and the reasons are in [tradeoffs.md](tradeoffs.md) (round 3).

## 3. Detailed training analysis easy to find

Muscle volume and the heatmap move to Progress › Volume, reachable in one tap from Today's volume row and in one tap from Progress.
Before, it was only a long scroll on Today and absent from Progress (D-131).
The Volume screen keeps the deload advisory ring by evaluating the advisor on appear, behind the deload-alert setting.
History, PRs, tonnage and comparison stay on Progress; the all-time workout count Today's cell showed is History's "Past sessions · n sessions" head.
Recaps stay on Progress only once the all-recaps screen from the design map's mock-ups is built, which this bundle does not plan (D-27 stays open).
The block's week strip, scheduling and archive stay on Block overview, one tap from either tab's block row.

## 4. Empty, active and data-rich states all intentional

Today has nine states, one with three fix-it variants, and Program six, one with a drafts-only variant, each with a wireframe and a stated signal element.
Zero-value rows go: the stat strip's zeros, the 17 muscle rows on a fresh store, the zero WORKING SETS slab, and the volume row on T-FIRST.
Needs the build: the volume row on a week with no workouts reads "0 workouts · 0 sets" and may still be noise; Phase 1 acceptance checks it.

## 5. Every visible element earns its prominence

The rule "one signal element per screen" is stated in [hierarchy.md](hierarchy.md) and applied in every wireframe.
Removed because they earned nothing: the phase chip, the week cells on Today and on Program's Now slab, the DAY counter, the days-left count, the COMPOUND and WORK chips, the block band's BLOCK chip, the READY chip's accent, the four decorative chips on empty Program, the 68pt NO PROGRAM, the template section, the deload banner, the deload chip and the DL badge.
`screen_budget.py` reports two states over the element budget, both accepted because they are transient: P-RESUME, where the resume banner adds exactly its three elements to P-ACTIVE, and T-TODAY with a deload advisory, where the notice adds one row until it is acted on or dismissed.
With no unaccepted state over budget, the script's hotspot is the longest job: first launch to first workout, about 15 taps, an estimate Phase 1 verifies.
The next longest job, reopening a finished block's review, takes four taps from Today, which is the price of O-5 (no notice for a block that ended because the next one started).
