# Round 2 verification: coverage lens

Reviewer: Claude worker, task task_8cb210c15fd7.
Code checked at `main` 0ef702ea, read-only.
`redesign/` is the bundle folder.

## Verdict

Draft v2 is final as written: no blockers remain.
All four round-1 blockers are closed or reduced to fix-soon residue.
Nine fix-soon findings remain, mostly stale claims and a missing test list in step 1.5.
Note: `plan.md` changed while I was reviewing (line 54 now says D-27 is not closed here), so I dropped my D-27 finding.

## Round-1 findings

| # | Status | Where |
| --- | --- | --- |
| 1 Review never clears | Closed | `today-layouts.md:203`, `plan.md:33` |
| 2 Pending-review semantics | Partly closed | `hierarchy.md:63-66`, `review-log.md:83`; placement conflict, see finding 5 |
| 3 Timestamps for the rules | Closed | `hierarchy.md:45`, `today-layouts.md:192`, `today-layouts.md:228`; `updatedAt` is written at `fitbod/Routines/RoutineDraft.swift:228` |
| 4 Test list incomplete | Partly closed | `plan.md:17-22`; step 1.5 still misses suites, see finding 1 |
| 5 T-ATTACH dead end | Closed | `today-layouts.md` T-ATTACH text; a leftover plan item, see finding 4 |
| 6 Unslotted T-DONE | Closed | `hierarchy.md:46`, `hierarchy.md:54` |
| 7 "46 sets" | Closed | `hierarchy.md:23`, `functionality-map.md:45` |
| 8 Advisory ring | Closed | `functionality-map.md:46`, `plan.md:20` |
| 9 Deload counts | Partly closed | Working sets are fixed in `plan.md:18`; warm-up counts are not, see finding 2 |
| 10 Session detail and discard | Closed | `functionality-map.md:39`, `today-layouts.md:315` |
| 11 Recap ordering | Closed | `functionality-map.md:51`, `plan.md:33` |
| 12 Review origin | Closed | `plan.md:36`, `program-layouts.md:187` |
| 13 Start block error | Closed | `today-layouts.md:190` |
| 14 Stale audit rows | Partly closed | See finding 7 |
| 15 Two wrong map rows | Closed | `functionality-map.md:14`, `functionality-map.md:85` |
| 16 Archived entry | Closed | `hierarchy.md:100` |
| 17 Omitted capabilities | Closed | `functionality-map.md:17-27`, `functionality-map.md:49-54` |

## Findings

### Blockers

None.

### Fix soon

**1. Step 1.5 does not name four suites that use Program's block card labels.**
Trigger: step 1.5 replaces the block cards with the Now slab, the Planned cards and the Past list.
Mechanism: these suites find Program's cards by the accessibility labels "ACTIVE block: …", "READY block: …", "DRAFT block: …" and "DONE block: …".
`BlockOverviewStatesUITests:26,44-46` uses them, as do `NewBlockSavesUITests:61,156-159`, `BlockReviewAfterEndUITests:60` and `BlockWeekCountsUITests:92-97`.
Step 1.5 names none of the four for this reason.
Blast radius: four UI suites go red in step 1.5 without warning.
The review log's claim that "every affected suite is named in its step" (B-5) is not quite true.
Smallest fix: add the four suites to step 1.5, or keep the labels on the new rows.

**2. The warm-up counts in the wireframes do not match the logger.**
Trigger: any session with two or more compound lifts.
Mechanism: `SessionFactory` gives a warm-up ramp only to the first qualifying compound (`fitbod/Sessions/SessionFactory.swift:178-181`, `:253-256`).
A barbell ramp has 4 sets and a dumbbell ramp has 2 (`fitbod/Prescription/WarmupRamp.swift:102`).
The wireframe shows "2 warm-up" on Bench Press and "1 warm-up" on Overhead Press (`today-layouts.md:28-30`).
The map says the helper returns warm-up counts (`functionality-map.md:29`), but step 1.2 only moves the deload rule (`plan.md:18`), and its acceptance test checks only working sets.
Blast radius: every exercise subline on Today.
Smallest fix: have the helper return the factory's warm-up counts, fix the wireframe, and add a check on warm-up counts to step 1.2's acceptance.

**3. Starting a workout from the sheet is ambiguous when one session fills more than one slot.**
Trigger: a routine like PPL ×2, where Push A fills slots 1 and 4, or one session used in two routines.
Mechanism: the sheet "carries over" the picker's grouping, which lists sessions in slot order with `ForEach(group.sessions, id: \.id)` (`fitbod/Views/TodaySessionPicker.swift:37-44`, `:65`).
A session that appears twice therefore produces duplicate IDs.
"Starts with that slot" (`today-layouts.md` session sheet rules) does not say which slot.
Blast radius: the rotation can advance to the wrong position on the glossary's own example routine.
Smallest fix: make one row per slot, keyed by the slot, and pass that row's slot.

**4. Two claims about attaching a routine are wrong, and step 2.4 includes a change that is already in the code.**
Trigger: reading `functionality-map.md:86` or step 2.4.
Mechanism: the attach band already shows only on draft and ready blocks (`fitbod/Periodization/BlockOverviewScreen.swift:300-302`).
The review log's line "the overview shows attach whenever the split is nil" (`review-log.md:97`) is false.
Blast radius: a no-op task in step 2.4 and one wrong claim in the review log's re-check list.
Smallest fix: drop "Hide + ATTACH ROUTINE ▸" from step 2.4 and fix both rows.

**5. The leaves disagree about where the review notice shows.**
Trigger: no active block, a pending review, and either a workout finished today (T-DONE) or an open workout (T-RESUME).
Mechanism: `hierarchy.md:40` says the notice row is independent of the hero, and `hierarchy.md:63` gives its condition only as no active block.
`plan.md:33` and `today-layouts.md:198` limit it to T-READY, T-PICK and T-FIRST.
Blast radius: `TodayStateTests` will encode one version, and either the leaves or the code will be wrong.
Smallest fix: pick one rule and state it in all three leaves.

**6. The review's "Start next ▸" still creates a block from Today, and the map names the wrong builder.**
Trigger: reading O-12 next to `today-layouts.md:205` and `functionality-map.md:52`.
Mechanism: O-12 says Today never creates a block, yet "Start next ▸" opens a builder from Today.
That builder is the review's own sheet (`pendingNextBlockBuilder`, `fitbod/Periodization/BlockReviewView.swift:76-81`), not TodayView's `pendingBlockBuilder`.
Once StartBlockCTA is removed, TodayView's `.template` case at `fitbod/Views/TodayView.swift:206` has no caller.
Blast radius: dead code in TodayView, and one decision stated in a way that contradicts a kept feature.
Smallest fix: allow the review's "Start next ▸" as an exception in O-12, fix map row 52, and delete the `.template` case in step 1.3.

**7. Three audit rows are still not true for both main and the screenshots.**
Trigger: reading A-01, A-02 and A-06.
Mechanism: A-01's "dash where the phase label goes" is true only of the screenshot.
On main, a flat week shows the phase's short label (`fitbod/Views/TodayStatStrip.swift:109`).
A-02 and A-06 quote "DAY 04 / 28", but `docs/design-map/screens/img/17e-default-light-today.png` shows "DAY 01 / 28".
A-04, A-14 and A-26 check out.
Blast radius: small; the rows' conclusions still hold.
Smallest fix: note that main shows "ACCUM" in A-01, and quote the captured day number.

**8. Two of the five new seeds duplicate existing ones, and step 1.1 depends on a seed that step 1.3 adds.**
Trigger: step 1.3's seed list (`plan.md:19`).
Mechanism: `PowerbuildingSeed` already seeds a block whose name is too long for the phone, and `program--long-name.png` was captured from it (`fitbod/App/PowerbuildingSeed.swift:5-7`).
`-fitbod-seed-empty-workout` already logs a Push A 30 minutes ago with no block (`fitbod/App/DemoWorkoutSeed.swift:22-23`), which covers T-DONE without a block.
`-fitbod-seed-ended-block-recap` already leaves a routine with no live block, though with a review pending.
Only three states are new: a ready block with none active, a session with no exercises, and T-DONE with a block.
Step 1.1's acceptance needs a `today--long-name` capture before step 1.3 adds that seed.
Blast radius: duplicate seed code and a step-order dependency.
Smallest fix: reuse `-fitbod-seed-powerbuilding` and `-fitbod-seed-empty-workout`, and add only the three missing seeds.

**9. D-24 is only half closed.**
Trigger: a lifter whose only sessions sit in no routine.
Mechanism: T-PICK needs a routine with a session that has exercises, so this lifter sees T-FIRST.
T-FIRST shows nothing else (`today-layouts.md:250`), so the sheet's "Other sessions" group cannot be reached.
D-24's second case, a session in no routine that cannot be started again, therefore remains.
`plan.md:52` still lists D-24 as closed.
Blast radius: the case D-24 names.
Smallest fix: add "Start a workout ›" to T-FIRST when any session exists, or mark D-24 as partly closed.

## Reviewer claims re-checked

Two claims are wrong: finding 4, and the claim that `reviewedAt` is written only by `acknowledge`.
`BackupRestorer.swift:440` also writes `reviewedAt` on restore, which does no harm.
The rest held: `acknowledgeAndDismiss` has no caller, and BlockReviewView wraps its own NavigationStack.
Only Today's hero passes a slot.
TodayView uses `Calendar.current`.
`fetchWorkingSets` is private.
`DeloadAdvisor.evaluate` takes no phase.
`HeaderSlot.action` renders with `isSignal: true`.
The routes are registered on one stack each.
`nextTrainingDay` is at `:463`.
`BlockCard` has no caller; `BlockRow` is called only from RoutinesListView and BlockPickerMenu.
`SplitDeletionGuard` refuses to delete a split used by a live block.
No code clears a block's routine.
`SessionFactory`'s deload rule matches.
