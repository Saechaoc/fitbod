# Open decisions

Product calls the proposal did not make for the user.
Each names the default the layouts assume, so the build can start without the answer and change later.
Defaults marked "round 1" were set or changed by the adversarial review; [review-log.md](review-log.md) has the reasons.
On 2026-11-05 the user asked for the calls to be made; the decisions are in the first table, and the register of questions, defaults and alternatives follows it unchanged.

## Decisions, 2026-11-08

Two calls from the gym playtest of 2026-11-08 (`docs/user-testing-notes/fitbod-playtest-roadmap-reconciliation.md`).

| # | Call | Why |
| --- | --- | --- |
| O-15 | Dark slabs stay dark in dark mode: `bruSlab` (`#0A0A0A` light, `#1F1C16` dark) with `bruOnSlab` text, on T-RESUME, the current Done slab and the Volume summary. | `bruInk` inverts to near-white, so the Resume card and the Done panel glared in the gym (FT-14, FT-15); light mode is unchanged. |
| O-16 | The logger lives on Today's stack only; Program's RESUME ▸, a session's START WORKOUT ▸ and the Live Activity switch to Today and open it there, so ‹ always lands on Today. | Back had no predictable destination because `dismiss()` returned to whichever stack pushed the logger (FT-02); one request (`ResumeWorkoutRequest`) and one stack give one answer. |

## Decisions, 2026-11-05

Every call takes the default the layouts assume, so no leaf changes and the build can start on draft v6.

| # | Call | Why |
| --- | --- | --- |
| O-1 | Drop the day streak and Today's all-time count. | A day streak misreads planned rest days as breaks, and the all-time count already lives on History. |
| O-2 | Yes: a workout started from the session sheet moves a rotation block forward. | One `StartSlot` rule anchored at NEXT, checked in all three rounds; unslotted starts would offer the skipped session again (D-19). |
| O-3 | Any finished workout with logged sets started today counts as done. | Done means trained, not trained as planned, and T-DONE outranking T-READY keeps the rest of the day calm. |
| O-4 | Keep the automatic weekly recap sheet. | It is the only recap surface, opens once a week on first appear and never during a workout; a notice row would add a third notice kind to rank against the review and the advisory. |
| O-5 | No: a finished block's review stays hidden while a newer block is active. | The pinned `pendingReviewBlocks` contract already hides it, and Past blocks keeps the review reachable. |
| O-6 | The oldest created ready block leads, then by name, then by id. | Deterministic, visible through "Created Oct 3", and needs no new attribute. |
| O-7 | Routine folders do not ship. | Nothing in the brief needs grouping, and one flat routine list reads faster. |
| O-8 | Block presets live only inside + New block. | Keeps the empty Program screen to one action. |
| O-9 | Program's "This week" rows act as the leaves describe. | Opening a logged day is what a lifter expects, and the TODAY row is the same start as Today's hero. |
| O-10 | A "Plan complete" line opens Block overview; no automatic end. | Ending a block is consequential and keeps its dialog; nothing ends by itself. |
| O-11 | Today's exercise rows open nothing. | "View ›" is the one way into the session, and exercise progress stays on Progress. |
| O-12 | A block cannot be planned from Today. | Program › + New is the one entry; Today only starts. |
| O-13 | No week cells on Program's Now slab. | The caption names the week and phase; the cells belong to Block overview. |
| O-14 | No planned start date. | The creation date tells blocks apart without a Schema V8 attribute. |

| # | Question | Default in the layouts | The other way |
| --- | --- | --- | --- |
| O-1 | Drop the day streak and Today's all-time count? | Dropped (the streak counts consecutive days ending today or yesterday, so a rest day breaks it and a lifter who rests between training days reads 1 or 2). The all-time count stays on Progress › History's "Past sessions · n sessions" head, which already shows it (round 3). | Keep a streak on Progress, counted by training weeks rather than days, which is a new feature. |
| O-2 | Should a workout started from the session sheet move a rotation block forward? | Yes (round 1; the rule fixed in round 2 and anchored at NEXT in round 3). A sheet row of the active block's routine passes NEXT when it holds that session, else the first slot after NEXT that holds the session, wrapping, so a session slotted twice never moves the rotation backwards. NEXT is the resolver's next slot in a rotation block and, in a weekday block, today's slot or the next training day's; with no block the row passes a slot under the same rule anchored at its own routine's anchor. A session outside the routine starts unslotted and moves nothing. In a rotation block, and with no block, a row that is not NEXT says what it skips ("skips Pull A, Legs A": the slots from NEXT up to the one it passes), because the anchor moves past those slots for this cycle; weekday blocks skip nothing. One helper, `StartSlot`, holds the rule for every start route. | No: every sheet start unslotted, so a double or a swapped session never moves the rotation and the skipped session is offered again (D-19). |
| O-3 | What counts as done for today? | Any workout with logged sets that started today and has finished, slotted or not, with or without a block (round 1). With several, the slab lists each (round 3). The slab's "Next" line names NEXT, or nothing. T-DONE outranks T-READY, so a finished workout hides START BLOCK ▸ until the next day (round 3). | Only a workout logged for today's slot. An unslotted workout leaves the planned session up. |
| O-4 | Keep the automatic weekly recap sheet? | Kept: once per week on Today's first appear when due; it no longer waits for a block review (round 1). The all-recaps screen on Progress ("Recaps ›", D-27) is not part of this bundle and stays deferred, so the sheet is the only recap surface delivered (round 3). | Replace the sheet with a notice row, "Week 2 recap ready ›", so nothing opens by itself. |
| O-5 | Surface a finished block's review while a newer block is active? | No (round 1). `pendingReviewBlocks` returns nothing while a block is active, and its tests pin that, so Today shows no notice; the review opens from Program › Past blocks. This also means the notice above T-READY's START BLOCK ▸ goes when the lifter taps that button; the notice sits first, so it is seen before the start (round 2). Closing the review by any route acknowledges it, and a pending review outranks the deload advisory (round 3). | A notice row in that case too, kept until the review is opened or dismissed, which needs a new query over the pinned contract, a dismissal, and a second notice on T-TODAY beside the deload advisory. |
| O-6 | Which ready block takes START BLOCK ▸ when there are several? | The oldest created (`startDate`, which the builder stamps when the draft is created, keeps on edit, and `start` overwrites), then by name, then by id (round 1; reworded in round 2 because no screen plans a start; "created" and the id tie-break in round 3). Both slabs carry "Created Oct 3 · 1 of 2 ready" and Program's Planned cards show "Created Oct 3", so same-name blocks made on different days read apart and the lifter sees why this one leads. With drafts only, the newest created draft leads with CONTINUE BLOCK ▸ in ink, ties by name then id (round 3). | None until the lifter picks on Program, or a real planned start (O-14). |
| O-7 | Do the routine folders ship? | No. RoutinesListView stays unwired and out of the product; the RoutineFolder model stays in the schema. Deleting the view is a Phase 3 cleanup. | Wire folders into Program's routines section as collapsible groups. |
| O-8 | Where do block presets live? | Only inside + New block › Use preset. | Also as a section on the empty Program screen, as now. |
| O-9 | Should Program's "This week" rows act? | Logged rows open the workout; the TODAY ▸ (or NEXT ▸) row starts the scheduled session with its slot, and shows exactly while Today's state is T-TODAY; a planned session with no exercises opens its detail; the open workout's row and the rest are read-only (round 3). | All rows read-only. |
| O-10 | Plan complete: a line into Block overview, or an automatic end? | The plan line's second line reads "Plan complete" and opens Block overview, where End block stays with the consequence in its dialog (round 1). Today itself has no End block. | Automatic end on the first appear after the plan's last day, with the review as the next thing shown. |
| O-11 | Should the exercise rows on Today open anything? | No, as now. The section head's "View ›" opens the session detail. | Rows open the exercise's progress screen. |
| O-12 | Can a block be planned from Today? | No (round 1). Program › + New is the one entry; Today starts a ready block and nothing else. The one exception is the review sheet's own "Start next ▸", which opens the builder from BlockReviewView, not from Today (round 2). | A "Plan a block ›" ghost on T-PICK opening Program's start-choice sheet, which means sharing the sheet and its staging state between the tabs. |
| O-13 | Week cells on Program's Now slab? | No (round 1). The slab shows the name, "Week 2 of 6 · Accumulation" and the routine; the cells stay on Block overview. | The mock-up's phase-labelled cells in place of the caption. |
| O-14 | Should a block carry a planned start date? | No (round 2). `Block.startDate` is the creation date until `start` stamps the real start (the builder stamps it when the draft is created and keeps it on edit, `BlockDraft.swift:19`, `:80`, `:151`); Program and Today show "Created Oct 3", and Today leads with the oldest ready block from the day it is created, unless an open workout (T-RESUME) or a finished workout today (T-DONE) outranks it (round 3). | A planned start set in the builder, which is a Schema V8 attribute; Today would then lead with the ready block only from that date, and same-name blocks would read apart by plan rather than by creation day. |

## Defaults decided in the leaves

These are product calls the layouts make without an open question.
They are indexed here so the register is complete (round 3, V4-F4); changing one is a change to the leaf named, not a new decision.

| Default | Where it is recorded |
| --- | --- |
| With no block, the hero is the NEXT of the live routine holding the newest finished slotted workout, its anchor moved past sessions with no exercises, and a routine with no usable session passes the suggestion on; a session in no routine is the fallback hero; a fresh store, an empty routine and a standalone session give T-FIRST, T-FIX and T-PICK; the repair slab names the live routine holding the most recently updated session, else the newest routine | today-layouts.md (T-PICK, T-FIX), hierarchy.md, tradeoffs.md |
| With drafts only, the newest created draft leads Program with CONTINUE BLOCK ▸; drafts never change Today | program-layouts.md (P-PLANNED, drafts only), tradeoffs.md, O-6 |
| Session-sheet rows of a routine start on tap; "Other sessions" rows open the session's detail; an empty routine session is repaired through Program | today-layouts.md (session sheet) |
| The block review is an opt-in notice; closing it by any route acknowledges it, and a failed acknowledgement keeps the notice and says so under it; a pending review outranks the deload advisory | today-layouts.md (review notice), hierarchy.md (notice table), O-5 |
| The deload advisory shows with or without a block, never while a workout is open or in a deload phase | hierarchy.md (notice table), plan.md 1.1 |
| Discarding a workout with no logged sets asks nothing, on Today and on Program; Program's always-confirm flow goes | today-layouts.md (T-RESUME), program-layouts.md (P-RESUME), tradeoffs.md, plan.md 1.6 |
| Volume sits one tap behind both tabs, untrained muscles collapse into one row, and T-FIX without a block has no volume row | today-layouts.md, plan.md 1.4 and 2.5 |
| Completed blocks move to Past blocks; the review reopens from Block overview and keeps its first acknowledgement date | program-layouts.md, tradeoffs.md, plan.md 2.1 and 2.4 |
| Empty Program leads with routine creation; block creation stays enabled and its routine picker offers + New routine | program-layouts.md (P-EMPTY), tradeoffs.md, plan.md 2.6 |
