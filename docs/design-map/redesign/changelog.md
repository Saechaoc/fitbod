# Changelog

Newest first.
One entry per iteration: what changed and why.

## 2026-11-02, draft v4

Revised after round 3's Codex experience review (4 blockers and 10 fix-soon findings, all closed or accepted) and the partial Codex coverage review (2 blockers and 7 fix-soon findings, folded in as far as the report goes); the feasibility review has not run (review-log.md, round 3).
NEXT is one value per scheduling mode, held by a new pure helper `StartSlot`, and every start route passes the slot it computes: the hero, the session sheet, Program's TODAY ▸ and NEXT ▸, and the session detail, which gains a `routine: Split?` parameter and computes its slot when Start is tapped.
Program's start controls show exactly while Today's state is T-TODAY, from the same `TodayState` function; the open workout lists as IN PROGRESS on its day; This week is seven day groups with one row per counted workout.
T-DONE lists every finished workout; T-FIRST is only a fresh store, with the no-block T-FIX variant and a standalone T-PICK hero taking the cases it covered; the block repair slabs and T-ATTACH keep "Choose another session ›".
"Created Oct 3" replaces "Saved"; both ready slabs read "CREATED OCT 3 · 1 OF 2 READY"; Past blocks carry the year across years; P-PLANNED has a drafts-only variant with CONTINUE BLOCK ▸.
"VOLUME THIS WEEK" names the volume row's destination; the deload advisory shows with or without a block and yields to a pending review notice; the discard rule is shared with Program's banner; P-RESUME overlays every state and demotes every other signal control.
Plan corrections: seven card-label UI suites and the five root-level DONE lookups in step 1.5, four BlockBuilderView readers in step 2.6, `WeekTickerCells` deleted with the band, the empty-workout seed clamped to today's midnight, Block overview's `origin` passed from the pushing tab; risks R-24 and R-25 added.
Audit rows A-03, A-04, A-16, A-21, A-22, A-23 and A-29 corrected against the captures and the source; the functionality map gains a grouped row for every unchanged child screen.
`screen_budget.py` gained the no-block T-FIX and drafts-only P-PLANNED states and the preview job; it reports `222 -> 109 (50% fewer)` across 17 states, with the same two accepted over-budget states.

## 2026-11-01, draft v3

Revised after round 2, a verification pass of v2 by the same three Claude lenses; the Codex reviewers were then resumed on v3 and stopped again at the account's usage limit before writing a report (review-log.md, round 3).
Two blockers closed.
The session sheet lists each session once and passes the resolver's next slot or the first after it that holds the session, so a session slotted twice never moves a rotation backwards; rotation rows say what a swap skips.
`Block.startDate` is the save date, not a plan: Planned cards read "Saved Oct 3", the ready-block order is oldest saved, and a real planned start is the new O-14.
Twelve fix-soon findings closed or accepted; review-log.md has the list.
T-DONE now outranks T-READY; the review notice shows on every state without an active block except T-RESUME; T-FIRST gains a "Start a workout ›" ghost when a session sits in no routine; the sublines show working sets only, through `workingSetCount(targetSets:phase:)`; the this-week row keys on the week start and skips the open workout.
Plan corrections: five card-label UI suites in step 1.5, `ArchiveRoutineUITests` and `BlockReviewHeroLayoutTests` in step 2.1 with a default origin and a guarded `acknowledge`, three seeds instead of five, the attach no-op removed from step 2.4, the `.template` builder case deleted in step 1.3, and step 1.1's queries named.
Copy: "DISMISS" instead of "×", "~17 MIN", a truncation rule for the review notice; audit rows A-01, A-02 and A-06 corrected.
`screen_budget.py` gained the T-DONE-with-review state (13 → 5 elements), so its totals read 199 → 100; the two accepted over-budget states are unchanged.

## 2026-11-01, draft v2

Revised after round 1's interim Claude reviewers (coverage, experience and feasibility lenses); the Codex round is still waiting for its quota reset.
Five blockers closed.
The block review is a notice row that clears when the review closes by any route, not a hero that outranked the ready block and could never clear.
Alternate starts carry the slot when the session belongs to the active routine, and "done for today" covers every finished workout, with or without a block.
The ready-block and session-suggestion rules use stored fields only, so no schema change hides in Phase 1.
An empty session is a fix-it state, not a failing signal button.
"CREATE BLOCK" and the new-block sheets stay where their guardrail suites expect them, Today no longer plans blocks, and every affected test suite is named in its step.
Twenty-six fix-soon findings closed or accepted with a reason; review-log.md has the list.
Today's plan line is two lines; Program's Now slab drops its week cells and days-left; the this-week row counts logged sets; the deload week shows prescribed counts after the phase's multiplier; the volume screen keeps the advisory ring.
Two new open decisions (O-12, O-13); the defaults of O-2, O-3, O-5, O-6 and O-10 changed.
Audit rows A-01, A-02, A-04, A-06, A-14 and A-26 corrected against main; two functionality-map rows corrected and the omitted capabilities added.
`screen_budget.py` gained the advisory, fix-it and review-pending states and an accepted-over-budget list.

## 2026-11-01, draft v1

Created the bundle from the design brief, the design map captured at 61353088, the user's BRU mock-ups and the Today and Program source.
Audit of 32 problems across 17 screenshots.
Hierarchy with ten Today states and six Program states, one signal element per screen.
Wireframes for every state, a map of every capability to its new place, a three-phase plan, tradeoffs, risks, open decisions, an evaluation against the brief and a runnable screen budget.
Sent for adversarial review (round 1, see review-log.md).
