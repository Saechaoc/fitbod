# Changelog

Newest first.
One entry per iteration: what changed and why.

## 2026-11-08, playtest fixes ahead of steps 1.3, 1.4 and 2.5

A gym playtest (`docs/user-testing-notes/fitbod-playtest-roadmap-reconciliation.md`) found 21 issues; the ones that touch the redesign landed ahead of their steps.
Dark slabs draw on `bruSlab` with `bruOnSlab` text, so T-RESUME and the Done slab stay dark in dark mode (FT-14, FT-15; decision O-15).
With no block and routines, Today shows one routine action, the picker's + New routine, in place of two (FT-15).
The logger lives on Today's stack only: Program's banner, a session's START WORKOUT ▸ and the Live Activity open it through `ResumeWorkoutRequest`, so ‹ lands on Today (FT-02; decision O-16).
Volume opens from Progress through `VolumeScreen`, every region and bar opens the muscle's detail, the neck is a tracked muscle, and muscles under MEV draw amber (FT-17, FT-18; parts of steps 1.4 and 2.5).
Plan rows 1.3, 1.4 and 2.5 record what landed and the device check that remains (FT-16).

## 2026-11-07, step 1.2 landed

The hero reads TODAY on a fixed-weekly block and NEXT UP · n OF m on a rotation, in place of NEXT and the DAY counter.
Its set count and each exercise row count the working sets the phase yields, through `PeriodizationEngine.workingSetCount`, the one rule the session factory now plans from.
The deload caption "Deload week · lighter sets" lands in the hero here, since 1.1 removed the banner.
The list head reads EXERCISES · n with VIEW ›, which opens the session, and the rows drop the COMPOUND and WORK chips and the warm-up count.
The hero keeps its 3 min per set estimate while the session detail's differs, as before this step.
The hand-made block seeds (`BlockStatesSeed`) give deload phases the catalog's 0.5 volume, so the deload capture and UI test cut sets as a real block does.
`SessionFactory.start` and `WorkoutStarter.start` take a calendar, `.current` by default, so Today's hero, rows and start read the same block day.

## 2026-11-06, step 1.1 landed

`TodayState` resolves the Today state table and the plan line (block name over `WEEK N OF M · PHASE`, or `PLAN COMPLETE`) replaces the stat strip, block band and week cells.
`PlanCompleteNote` and Today's end alert are deleted: the plan line opens Block overview, where END BLOCK lives.
The ready block Today shows is now the oldest created (O-6).
`DeloadAdvisory.bannerCopy` is deleted, and the deload week shows no banner, only the advisory row.
`BlockOverviewScreen.stripHeader` takes a date.
`TodayState.pick` carries no payload until step 1.3.
`-fitbod-seed-block-states-deload` seeds Spring Block 22 days in, for the deload capture.
The long-name capture renames the Powerbuilding block to "Powerbuilding Winter Strength and Size Block Two Revised" (through the simulator store, since "Powerbuilding" alone fits), and the name line ends in an ellipsis while the position line stays whole.

## 2026-11-05, product calls

The user asked for the fourteen open product calls to be made.
Each takes the default the layouts assume, with a one-line reason in open-decisions.md's new Decisions table, so no leaf changes and draft v6 stands.
index.md says the calls are made.

## 2026-11-02, draft v6

Revised after the Codex feasibility reviewer finished its pass on draft v5 (0 blockers and 3 fix-soon findings, all closed; review-log.md, round 3), which closes round 3 with no open blocker.
The deload-alert setting gate moves into `DeloadAdvisor.evaluate`, so Volume's advisory ring and Today's notice honour it once.
`BlockOverviewScreen.nextTrainingDay` moves into `StartSlot` as `nextTrainingDate` with its contract and tests unchanged, distinct from NEXT, so Block overview keeps its NEXT cell.
`BlockLifecycleEntryPointsUITests` expects no review notice after its journey closes the review and relaunches; `BlockReviewAfterEndUITests` relaunches before tapping the notice.
Step 1.4 forwards the stack's navigation path into FatigueSurfaceView, step 1.5 keeps the header's geometry and z-order modifiers, step 2.1 names `BlockReviewedAtTests`, and step 1.2's placeholder deletion lands with step 1.3.
`screen_budget.py` is unchanged: no state was added or removed.

## 2026-11-02, draft v5

Revised after the Codex coverage reviewer finished its pass on draft v4 (1 blocker and 6 fix-soon findings, all closed) and the Codex feasibility reviewer's partial pass on it (2 blockers and 1 fix-soon finding, all closed; it stopped at the usage limit with five of eleven checks done and resumes on this draft; review-log.md, round 3).
No-block NEXT skips sessions with no exercises under one rule shared by the hero, the session sheet and Program, and a routine with no usable session passes the suggestion on.
A failed review acknowledgement keeps the notice and says so under the row that opened the sheet, with tests at the persistence boundary.
The start pipeline takes the environment calendar, the volume row filters the fatigue helper's sets by the counted workouts, and the session sheet keeps slot identity per row.
`TodayState` takes every live routine, empty ones included, and the sessions with exercises that no live routine holds, so a fresh store, an empty routine and a standalone session give T-FIRST, T-FIX and T-PICK; `TodayStateTests` covers the three stores and Program reuses the inputs.
The per-step test lists name the factory, Progress and resolver suites and `BlockReviewMathTests`, drop three wrong-screen matches, and say "production caller" where previews exist.
The empty-workout fixture is anchored to the later of 30 minutes before launch and today's midnight with every timestamp bounded by launch, in place of a start clamp that could finish the workout after launch.
open-decisions.md gains a table of nine defaults decided in the leaves; O-3, O-5, O-6 and O-14 state their precedence rules, and O-4 marks the Progress recaps screen deferred.
The drafts-only rule keeps newest created and says so; the zone table, the review-notice list and the T-FIX row agree with the notice table and the no-block layout.
Review-log corrections: "Plan custom" at `BlockReviewView.swift:349`, `WeekTickerCells`' previews, the precise `pendingReviewBlocks` rule, "two active blocks", and the long-name fixture's unmeasured fit in the plan line.
`screen_budget.py` is unchanged: no state was added or removed.

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
