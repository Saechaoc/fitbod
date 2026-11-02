# Review log

Adversarial reviews of this bundle, newest first.
Each round lists the reviewers, their lenses, the findings ranked by blast radius, and what changed in the bundle because of each.
A finding is a blocker when the design cannot be called final until it is closed or accepted with a reason.

## Round 3 (Codex): attempted on draft v3, blocked by the usage limit

The three Codex reviewers (GPT-6-Astra, max reasoning, Orca run `run_855deefac019`) were resumed on draft v3 with the specs in `reviews/specs/round3-codex-coverage.md`, `round3-codex-experience.md` and `round3-codex-feasibility.md`.
Each spec asks the reviewer to re-check the seven blockers and three fix-soon closures of rounds 1 and 2 against the leaves, then to attack v3 with its lens.
21:39 PST, 2026-11-01: the first resend landed a minute before the account's five-hour window reset and was refused.
21:41 PST: the second resend started all three; by 21:52 the three sessions had used 91% of the fresh window, and when each was asked to write up what it had, all three were refused with "try again at 2:41 AM on 2 Nov".
No Codex report exists, so nothing in v3 comes from a Codex finding, and no reviewer has checked v3 itself.

| Lens (round 3) | Dispatch | Terminal |
| --- | --- | --- |
| Coverage | `ctx_c5c90e2545ca` | `term_119ecd08-743e-4edb-ba53-c8c8a5d6f71c` |
| Experience | `ctx_7ba11a62bc0e` | `term_7e1e8606-69e4-42d5-948a-cdc9ba6cecd9` |
| Feasibility | `ctx_ef85d3b1fc2a` | `term_c44291f1-e180-4915-ab17-7f74247af6b3` |

To finish the round after the reset, send one reviewer at a time its spec, so one window carries one whole review: `orca terminal send --terminal <terminal> --text "Read <spec path> and do what it says." --enter`, then `orca orchestration check --run run_855deefac019 --wait --types worker_done --json` for its report.
Each spec names its report path under `reviews/`; fold the findings into this log the way rounds 1 and 2 were.

## Round 2: settled in draft v3

A verification pass of draft v2 by the same three lenses on the same run, each reviewer asked to confirm or deny every round-1 closure in the leaves and then to attack v2 afresh.
Reports: `reviews/round2-claude-coverage.md` (9 findings), `reviews/round2-claude-experience.md` (7), `reviews/round2-claude-feasibility.md` (9).
Verdicts: coverage and feasibility final as written with no blockers; experience not final, with two blockers.
All three confirmed every round-1 closure in the leaves; the claims they found overstated are B2-2, F2-2 and F2-4 below.
The 25 findings deduplicate into 2 blockers and 12 fix-soon items.
The Codex round was then attempted on v3 and blocked by the usage limit; see round 3 above.

#### Blockers

| # | Finding (sources) | Resolution in v3 |
| --- | --- | --- |
| B2-1 | The O-2 slot rule was undefined when one session fills two slots, which the slot picker allows (`SplitDetailView.swift:780`, `:869-890`) and the glossary's PPL ×2 invites; the first matching row could move a rotation back by half a cycle (Exp N-1; Feas N-3; Cov 3). | Each session lists once; a row of the active routine passes the resolver's next slot when it holds the session, else the first slot after it that holds it, wrapping. A `TodaySessionSheetTests` case covers a session in two slots. open-decisions.md O-2, today-layouts.md, functionality-map.md, risks.md R-5, plan.md 1.3. |
| B2-2 | O-6 and the Planned cards read `Block.startDate` as a planned start, but no screen sets one: the builder stamps `.now` at save (`BlockDraft.swift:19`, `:151`) and `start` overwrites it (`BlockLifecycleService.swift:101`), so "PLANNED FOR OCT 3" would show a past date, and B-3's "same-name blocks read apart" overstated (Exp N-2). | Cards say "Saved Oct 3", muted; the P-PLANNED slab drops its date line; O-6 orders by oldest saved, then name; a real planned start is O-14, a schema change. program-layouts.md, hierarchy.md, today-layouts.md, open-decisions.md O-6 and O-14, tradeoffs.md, risks.md R-23. |

#### Fix soon

| # | Finding (sources) | Resolution in v3 |
| --- | --- | --- |
| F2-1 | Step 1.5 did not name the UI suites that find Program's block cards by their accessibility labels "ACTIVE block: …" and the like (Cov 1). | Five suites named; the Now slab, Planned cards and Past rows keep the labels. plan.md 1.5. |
| F2-2 | The wireframes' warm-up counts could not come from the factory: only the first qualifying compound gets a ramp (4 sets for a barbell, 2 for dumbbells), and `WarmupRamp.shouldGenerate` needs a `SessionExercise`, the top weight and the bar; F-1's "counts the logger generates" held for working sets only (Cov 2; Feas N-9). | The helper is `workingSetCount(targetSets:phase:)`, taking the phase; sublines read "3 × 5-8" and drop the fixed "2 warm-up", which the factory never read. today-layouts.md, hierarchy.md, functionality-map.md, plan.md 1.2, risks.md R-17, tradeoffs.md. |
| F2-3 | With no block, a sheet start never moved the T-PICK suggestion, so the planned test passed only through the hero (Feas N-4). | A no-block row passes its routine slot under the two-slot rule, anchored at the suggestion. today-layouts.md, open-decisions.md O-2, plan.md 1.3. |
| F2-4 | Two leaves said Block overview shows "+ ATTACH ROUTINE ▸" on active blocks and step 2.4 hid it; the band already shows only on draft and ready blocks (`BlockOverviewScreen.swift:299-302`). Feasibility's N-6, which moved that hide into step 1.3, rested on the same wrong reading (Cov 4; Feas N-6 denied). | The no-op left step 2.4; the claims are corrected, including the re-check list below. today-layouts.md, program-layouts.md, functionality-map.md, plan.md 2.4. |
| F2-5 | The leaves disagreed on where the review notice shows: "independent of the hero" against "T-READY, T-PICK or T-FIRST", which left T-DONE without a block unnoticed until the next day (Cov 5; Exp N-5). | One rule: every state without an active block except T-RESUME. hierarchy.md, today-layouts.md, functionality-map.md, plan.md 2.1, screen_budget.py. |
| F2-6 | O-12 said Today never creates a block while the review's "Start next ▸" still does; the map named TodayView's builder for it, and the `.template` case at `TodayView.swift:206` loses its only caller with StartBlockCTA (Cov 6). | O-12 names the review's own `pendingNextBlockBuilder` as the exception; `.template` goes in step 1.3; `.edit` stays, because Block overview's Edit on Today's stack sets it (`:267`). open-decisions.md O-12, today-layouts.md, functionality-map.md, plan.md 1.3. |
| F2-7 | A swap in a rotation silently skipped the session it replaced (Exp N-4). | Rotation rows that are not NEXT end "skips Pull A, Legs A"; O-2 states the behaviour. today-layouts.md, open-decisions.md O-2. |
| F2-8 | T-READY outranked T-DONE every day a ready block waited, so "done for today" never showed (Exp N-6). | T-DONE outranks T-READY; Program's slab keeps the one-tap start and Today offers the block again the next day. T-READY still outranks T-PICK, accepted with the reason in tradeoffs.md and O-14 as the real fix. hierarchy.md, today-layouts.md, program-layouts.md, tradeoffs.md, evaluation.md. |
| F2-9 | The this-week row counted an open workout's sets, because `completedWorkingSets` selects by `startedAt` only, and a task keyed on finished IDs never rolled over on Monday; `fetchWorkingSets` needs no visibility change since `completedWorkingSets` is internal (Feas N-1). | Keyed on the finished IDs and the week start from `mondayAtMidnightForToday` with the environment calendar; counts `countedWorkouts` and their sets through `completedWorkingSets`. today-layouts.md, functionality-map.md, plan.md 1.4, risks.md R-7. |
| F2-10 | Step 2.1 missed `ArchiveRoutineUITests` (its helper waits for the automatic review) and `BlockReviewHeroLayoutTests`, did not say that the reopen-after-relaunch assertion in `BlockLifecycleEntryPointsUITests:51-55` is deleted on purpose, and the origin parameter needed a default for three `BlockReviewView(block:)` constructors; `acknowledge` sets `reviewedAt` with no guard (`BlockReviewView.swift:649-657`), so a reopened review would be re-dated (Feas N-2, N-5). | All named; `origin` defaults to `.today`; `acknowledge` guards on `reviewedAt == nil`. plan.md 2.1, program-layouts.md. |
| F2-11 | Two of the five seeds duplicated `-fitbod-seed-powerbuilding` and `-fitbod-seed-empty-workout`, and step 1.1's long-name capture needed a seed step 1.3 added (Cov 8; Feas N-7). | Three new seeds; step 1.1 captures from the powerbuilding seed. plan.md, functionality-map.md, risks.md R-19. |
| F2-12 | D-24 was half closed: a lifter whose only sessions sit in no routine saw T-FIRST and could not reach the sheet's "Other sessions" group (Cov 9). | T-FIRST gains a "Start a workout ›" ghost when such a session has exercises. hierarchy.md, today-layouts.md, functionality-map.md, tradeoffs.md, plan.md 1.3. |

Smaller items, fixed in place: step 1.1 names its new queries and their Swift post-filters (Feas N-8); hierarchy.md's P-RESUME line now matches program-layouts.md, its ACTIVE-chip sentences are replaced because Program draws no ACTIVE chip, T-DONE's rotation next line reads "the resolver's next slot", and evaluation.md marks P-ACTIVE's TODAY ▸ as Phase 2 (Exp N-5); "DISMISS" replaces "×" on the advisory row, the review notice truncates the name and keeps "REVIEW ›", and the deload hero reads "~17 MIN" per `setCount * 3 + 2` (Exp N-7); audit rows A-01, A-02 and A-06 quote the captures and note what main shows (Cov 7).

#### Accepted as is, with the reason

- Starting the ready block under a pending review removes the notice; the notice is seen first, and the review stays reachable from Past blocks (Exp N-3). O-5 records the other way and its cost.
- T-READY outranks T-PICK while a ready block waits (Exp N-6, second half).
- Phase 1's P-ACTIVE has no forward action beyond the slab's OPEN ›, because This week is Phase 2 (Exp N-5).

#### Reviewer claims re-checked against the source before the revision

- The attach band shows only on draft and ready blocks: `if block.derivedStatus == .draft || block.derivedStatus == .ready { splitAttachSwapBand }` at `BlockOverviewScreen.swift:299-302`. Coverage was right; feasibility's N-6 was not.
- `BlockReviewStatistics.acknowledge` sets `block.reviewedAt = now` with no guard (`BlockReviewView.swift:649-657`); `BackupRestorer.swift:440` also writes `reviewedAt` on restore.
- `BlockDraft.startDate` defaults to `.now` and `save(into:)` writes it back (`BlockDraft.swift:19`, `:151`); `BlockLifecycleService.start` overwrites it (`:101`) and its comment at `:39` calls the unstarted value a default; no view binds it.
- TodayView sets `pendingBlockBuilder = .template(BlockTemplates.blank)` only at `:206` (StartBlockCTA) and `.edit` only at `:267` (Block overview's `onEdit` on Today's stack), so `.edit` stays.
- `LiftListRow.setSubLine` reads "2 warm-up · n work" when `generateWarmups` is on, else "n × lo-hi"; `SessionFactory` never reads `generateWarmups`.
- `BlackSlabCTA.estimatedMinutes` is `max(1, setCount * 3 + 2)`.
- `SplitDetailView`'s slot picker lists every unarchived session with no duplicate guard (`:780`, `:869-890`); `TodaySessionPicker.groups` lists a routine's sessions in slot order without deduplication.
- The glyph table lists "×" as times and has no close mark; the banner draws "✕".
- The card labels "ACTIVE block: …", "READY block: …", "DRAFT block: …", "DONE block: …" are at `ProgramView.swift:635-641`; five UI suites match them.
- `PowerbuildingSeed` has the long block name; `DemoWorkoutSeed` (`-fitbod-seed-empty-workout`) logs a finished Push A with no block.

## Round 1

Three lenses, dispatched through Orca run `run_855deefac019` on 2026-11-01, each reviewer given only the bundle, the repository at 0ef702ea and its lens:

| Lens | Question |
| --- | --- |
| Coverage | Does the functionality map account for every capability in the Swift source and the design map, and are the audit's claims about current behaviour true? |
| Experience | Does the hierarchy pass the brief's five criteria, respect decisions.md and the approved mock-ups, and cover every state without a wrong screen? |
| Feasibility | Can the plan be built as written in SwiftUI and SwiftData under the project's conventions, and which tests and layouts break? |

### Codex round: stalled at the usage limit

18:40 PST: all three Codex reviewers (GPT-6-Astra, max effort) stopped after about three minutes because the ChatGPT account reached its five-hour usage limit (reset 21:39 PST).
No Codex report was written.
Their terminals and dispatches stayed open on the run; the round resumed on draft v3 as round 3 above and stalled again.

### Interim Claude round: settled in draft v2

The same three specs were re-dispatched to Claude workers on the same run.
Reports: `reviews/round1-claude-coverage.md` (17 findings), `reviews/round1-claude-experience.md` (19), `reviews/round1-claude-feasibility.md` (17).
All three verdicts: not final as written.
The 53 findings overlap heavily; below they are deduplicated into 5 blockers and 26 fix-soon items, each with its resolution in draft v2 or the reason it is accepted as is.
"Exp", "Feas" and "Cov" name the three reports; the numbers are the findings in them.
Every code claim the revision relies on was re-checked against the source; the list is at the end.

#### Blockers

| # | Finding (sources) | Resolution in v2 |
| --- | --- | --- |
| B-1 | The T-REVIEW hero could never clear, because only "Start next ▸" writes `reviewedAt`. It outranked T-READY, left a lifter between blocks no way to start a workout, made Today and Program disagree after a block ended, needed a notice query that `pendingReviewBlocks` cannot answer, and broke the weekly recap's ordering (Exp F-1, F-2, F-10; Feas F-1, F-9; Cov 1, 2, 11). | T-REVIEW removed. A pending review is one notice row on T-READY, T-PICK and T-FIRST, fed by `pendingReviewBlocks` as it is, so no notice shows while a block is active and O-5 closes by that contract. Closing the review by any route calls `acknowledge` (a BlockReviewView change; the dead `acknowledgeAndDismiss` is deleted). T-READY leads, so both tabs show START BLOCK ▸; T-READY and T-PICK keep "Start a workout instead ›". The recap shows on first appear when due. hierarchy.md, today-layouts.md, plan.md 2.1, risks.md R-3, R-18, R-20, open-decisions.md O-5. |
| B-2 | Every alternate start was unslotted, so doubles and swaps never moved a rotation block (D-19 widened, not closed); the T-PICK suggestion read slotted workouts the app never writes without a block; "done for today" had two definitions, used `completedAt` against the week counts' `startedAt`, and existed only under a block (Exp F-3, F-5; Feas F-3, F-9; Cov 6). | O-2's default is now "yes": a sheet row whose session is a slot of the active routine starts with that slot. T-PICK's START passes the suggested slot; its anchor is the newest finished workout whose slot's routine is not archived. T-DONE is any workout with logged sets that started today and has finished, with or without a block; its "Next" line is the resolver's next slot or nothing. The sheet marks the resolver's next slot "NEXT". hierarchy.md, today-layouts.md, open-decisions.md O-2, O-3, risks.md R-4, R-5. |
| B-3 | The "most recently edited" ready block and the T-PICK fallback by "routine edited most recently" need timestamps `Block` and `Split` do not store, which is a schema change the plan rules out (Feas F-2; Exp F-9; Cov 3). | O-6: the ready block with the earliest planned start (`startDate`), then by name; Program's Planned cards show the planned start, so same-name blocks read apart. The T-PICK fallback uses `SessionTemplate.updatedAt`. No field is added. open-decisions.md O-6, tradeoffs.md, today-layouts.md, program-layouts.md. |
| B-4 | A routine with an empty session fell into T-TODAY with "0 EXERCISES" and a signal button that ends in an alert, and stranded a rotation block on that slot (Exp F-4). | A T-FIX variant, "PUSH B HAS NO EXERCISES" with ADD EXERCISES ▸ (ink) and "Choose another session ›", above T-TODAY. T-PICK skips empty sessions. Sheet rows for empty sessions are disabled. hierarchy.md, today-layouts.md, functionality-map.md. |
| B-5 | The plan renamed "CREATE BLOCK" and moved the new-block sheets, which two guardrail suites pin in ProgramView.swift, and the sheets chain through Program's staging state; the test inventory missed at least fifteen suites, seven of them using `today.sessions` as the loaded signal (Feas F-4, F-5; Cov 4). | "CREATE BLOCK" and the sheets stay where they are; Today never creates a block (O-12), so nothing needs sharing. A `today.root` identifier replaces the loaded signal. Every affected suite is named in its step, from an `rg` over both test targets for each removed string and type; Phase 3.2 and 3.3 list their dependents. plan.md, risks.md R-1, R-2, open-decisions.md O-12. |

#### Fix soon

| # | Finding (sources) | Resolution in v2 |
| --- | --- | --- |
| F-1 | The deload week showed full volume: the hero and sublines read raw `targetSets`, and whether the advisory is hidden in a deload phase was unspecified (Exp F-6; Cov 9). | The hero and sublines show the counts the logger generates, through one helper holding `SessionFactory`'s deload rule (floor of `targetSets × volumeMultiplier`, at least one); round 2 narrowed this to working sets (F2-2). The reviewers' claim that nothing applies the multiplier was true of Today but not of the factory. The advisory notice is hidden while the phase is a deload. today-layouts.md, functionality-map.md, plan.md 1.2, risks.md R-17. |
| F-2 | A mis-tap in the session sheet cost more than R-12 said: the logger's ‹ only dismisses and the empty-workout discard goes through a dialog (Exp F-7; Cov 10). | Corrected: ‹ leaves the workout open, Today shows RESUME, and its DISCARD asks nothing when no sets are logged, so the cost is two taps. No logger change. risks.md R-12, today-layouts.md, tradeoffs.md. |
| F-3 | The this-week row's "46 sets" was the stimulus-weighted sum, not logged sets, and `weeklyVolumes` would run on every Today render; the muscle cue that steers a session choice was gone (Exp F-8; Feas F-8; Cov 7). | The row counts finished workouts and working sets (`fetchWorkingSets`) in a `.task(id:)`, with no delta. The muscle cue stays on Volume: accepted, because early in the week most muscles are under MEV and the cue reads as a standing warning. hierarchy.md, today-layouts.md, tradeoffs.md, risks.md R-7. |
| F-4 | A block past its plan showed a stale week on both tabs; "days left" had no stored source; the End block dialog dropped the consequence (Exp F-11). | The plan line's second line and the Now slab's caption read "PLAN COMPLETE" from `BlockPosition.label`; days left is gone; the dialog reads "Ends Spring Block and saves its plan to history. New workouts will not count toward it." today-layouts.md, program-layouts.md, functionality-map.md. |
| F-5 | Program's This week rows misreported off-plan and swapped workouts and dropped the mock-up's "TODAY ▸"; the two leaves used different example weeks (Exp F-12). | Rows list logged workouts on the day they happened; "TODAY ▸" is an ink text action that starts the scheduled session with its slot; one example week across hierarchy.md, today-layouts.md and program-layouts.md. risks.md R-22. |
| F-6 | P-ACTIVE had eleven elements above the fold with the week told three times (Exp F-13). | The Now slab is four lines: no cells, no days left, no training days. Eight elements. O-13 records the mock-up's cells as the other way. program-layouts.md, screen_budget.py. |
| F-7 | Notice rows were capped at two but three were listed, with no order (Exp F-14). | One notice per state: the deload advisory with an active block, the review notice without one. Plan complete lives in the plan line. hierarchy.md. |
| F-8 | The one-line plan line and the this-week row did not fit 390pt at default size, and middle truncation on one Text cuts the week (Exp F-15; Feas F-14). | The plan line is two Texts: the name tail-truncates, the position line never does. The this-week row is "2 workouts · 20 sets". today-layouts.md, risks.md R-8. |
| F-9 | Copy broke the glossary, the glyph table and P-8: "×" as close, "▲", two T-PICK labels and layouts, weekdays repeated in hero labels (Exp F-16). | CANCEL in the sheet header's left slot; no "▲"; one T-PICK label and layout; hero labels "TODAY", "DONE", "REST DAY". "A routine is your split" is kept: accepted, because "split" is the gym word and the glossary bans the code name, not the English word. today-layouts.md, program-layouts.md, tradeoffs.md. |
| F-10 | Removed affordances were not all replaced or recorded: the documented history entry, the rotation position, sessions outside any routine (Exp F-17). | The CLAUDE.md baseline change is in step 1.1; the rotation label reads "NEXT UP · 2 OF 3"; the sheet gains an "Other sessions" group (D-24). functionality-map.md, plan.md. |
| F-11 | The evaluation checked seven of sixteen states and its tap counts disagreed with the script (Exp F-18). | One row per state; every count quoted from `screen_budget.py`, which gained the review, fix-it and advisory states. evaluation.md, screen_budget.py. |
| F-12 | P-RESUME restyled the whole page to move the signal (Exp F-19). | The banner is a paper row holding the signal; the Now slab stays ink; only "TODAY ▸" hides. program-layouts.md. |
| F-13 | Phase 1 steps depended on later pieces: the shared sheet, `TodayState`, the next-day helper, and Block overview missing from step 1.1 (Feas F-6). | `TodayState` is step 1.1; no sheet is shared (O-12); the next lines are Phase 2; Block overview is in step 1.1. plan.md. |
| F-14 | `HeaderSlot.action` renders orange with a smaller target than the old chrome (Feas F-7). | The `HeaderAction` form, ink by default, with the height measurement kept. program-layouts.md, risks.md R-9. |
| F-15 | `TodayState`'s inputs were not all available as described, and the day boundary was undefined (Feas F-9). | The calendar comes from the environment; the resolution is computed in the view; ready blocks come from a broad query with a Swift filter; Today re-evaluates on scene activation and the significant-time-change notification; a workout belongs to the day of its `startedAt`. plan.md 1.1, risks.md R-4. |
| F-16 | Moving Volume needed a screen wrapper, a shared route and the advisory state, or the ring is lost (Feas F-10; Cov 8). | `VolumeScreen` with Back and a ScrollView, evaluating `DeloadAdvisor` on appear; `VolumeRoute` on both stacks; `MuscleSlugRoute` on Progress. plan.md 1.4, risks.md R-21. |
| F-17 | START BLOCK ▸ on Today had no error path, and a draft block vanished from Today (Feas F-11; Cov 13). | "Couldn't start block" alert with "Try again" and "Open block". Drafts stay on Program only: accepted, because Program's Planned card names the missing piece and Today's job is the next action, not planning. today-layouts.md, risks.md R-10. |
| F-18 | T-ATTACH led to an attach button that `attachSplit` refuses on active blocks (Feas F-12; Cov 5). | T-ATTACH's copy says to end the block; OPEN BLOCK ▸ leads to an overview that already shows attach only on draft and ready blocks, so END BLOCK is the one action. The state is defensive: the UI cannot create it. today-layouts.md, program-layouts.md. |
| F-19 | The review cannot be pushed from Program (it wraps its own NavigationStack) and hard-codes Today as its origin (Feas F-13; Cov 12). | A sheet from Block overview with the origin passed in; `BlockBuilderView.Origin` already has `.program`. program-layouts.md, plan.md 2.4. |
| F-20 | The required captures needed DEBUG seeds the plan did not list (Feas F-15). | Five seeds named in step 1.3 and used by later steps. plan.md, risks.md R-19. |
| F-21 | A plan-complete notice with END BLOCK ▸ could end the block mid-workout and needed the overview's alert extracted (Feas F-16). | No End block on Today at all; the plan line opens Block overview. open-decisions.md O-10. |
| F-22 | The vocabulary would rename Block overview's pinned "SESSIONS DONE" without saying so (Feas F-17). | "WORKOUTS DONE" in step 1.1 with `BlockWeekCountsUITests`. hierarchy.md, plan.md. |
| F-23 | Audit rows described a build older than main: "1 sessions", the past-plan disagreement, the day counter wrapping, "ACCUM" in the strip, the empty-state volume copy, and A-04's missing accent uses (Cov 14). | A-01, A-02, A-04, A-06, A-14 and A-26 corrected against main and the screenshots. audit.md. |
| F-24 | Two map rows were wrong: the date already has the weekday; the overview's confirmation is the block swap (Cov 15). | Corrected. functionality-map.md. |
| F-25 | P-EMPTY said "Nothing else" but the archived routines entry shows there (Cov 16). | The entry stays in every state. hierarchy.md, program-layouts.md. |
| F-26 | The map omitted the advisory setting gate and dismissal, `markRecapSeen`, rest-timer clearing on discard, the empty-workout exclusion, the picker's disabled START, the lift list placeholder, the identifiers, the seeds and `TrendDirection` (Cov 17). | One row each. functionality-map.md. |

#### Accepted as is, with the reason

- "A routine is your split, like Push / Pull / Legs." stays (F-9).
- The this-week row carries no muscle cue (F-3).
- P-RESUME shows ten elements above the fold, over the budget of eight, because the banner is transient (F-6, F-12).
- Draft blocks are not surfaced on Today (F-17).
- Older unreviewed blocks in a legacy store are reachable only from Past blocks, because `pendingReviewBlocks` returns only the latest-ended one (B-1).
- The sheet title "CREATE BLOCK" under the popover item "+ New block" stays (B-5).

#### Reviewer claims re-checked against the source before the revision

- `reviewedAt` is written by `BlockReviewStatistics.acknowledge`, called only from "Start next ▸", and by `BackupRestorer.swift:440` on restore (round 2 correction); "Plan custom" calls `dismiss()`; `acknowledgeAndDismiss` has no caller.
- `pendingReviewBlocks` returns nothing while any block is active, else only the latest-ended unreviewed block; `BlockReviewTriggerTests` pins both.
- BlockReviewView wraps its own NavigationStack and opens the builder with origin `.today`; `BlockBuilderView.Origin` has `.program` and `.today`.
- `TodayResolver`'s rotation anchor requires the workout's block, slot and split to match; fixed-weekly maps the weekday through `trainingDays.firstIndex`.
- Only Today's hero passes a slot to `WorkoutStarter`; the picker and every other caller pass nil.
- TodayView uses `Calendar.current`; `checkWeeklyRecap` waits on the review sheet; `deloadAlertEnabled` gates the advisory; `DeloadAdvisor.evaluate` ignores the phase.
- `BlackSlabCTA` sums raw `targetSets`; `LiftListRow` shows raw `targetSets` and a fixed "2 warm-up"; `SessionFactory` cuts working sets by the multiplier in a deload phase and `WarmupRamp` skips warm-ups then.
- `FatigueModel.weeklyVolumes` walks every working set's stimuli; the slab's total is stimulus-weighted; `fetchWorkingSets` is private.
- `Block` stores `startDate`, `endDate` and `reviewedAt`; `Split` has `createdAt` only; `SessionTemplate` has `updatedAt`.
- `attachSplit` throws on active blocks; the overview shows the attach band only on draft and ready blocks (`:299-302`; round 2 correction of "whenever the split is nil") and calls `start` with `try?`; the End alert names the Program tab; `SwapConfirmSheet` is the block swap; `SplitDeletionGuard` refuses to delete a split used by a live block.
- `HeaderSlot.action` renders with `isSignal: true`; `HeaderAction` defaults to `isSignal: false`.
- `BlockStatesSeed` seeds an active, a ready and a draft block, so no seed has a ready block with none active.
- `BRUCountLabel` is singular; the day counter is nil past the plan; the header date carries the weekday; muscles with a MEV target always list; the Today screenshot shows the dash in the strip, the orange ACCUMULATION chip, the orange COMPOUND border and the orange "±0".
- The logger's ‹ only dismisses; discarding a set-less workout goes through the ••• menu and a dialog.
- `MuscleSlugRoute` is registered only on Today's stack and `ProgressHomeRoute` only on Progress's.
- `BlockOverviewScreen.nextTrainingDay` exists as a static helper.
- `BlockCard` has no app caller; `BlockRow` is called from RoutinesListView, and `BlockRow.sortedForDisplay` from BlockPickerMenu.
- The suites that read `ProgramView.swift` by path are `NewBlockBuilderFidelityTests`, `ProgramViewFidelityTests` and `AdaptiveColorSourceTests`; six suites read `BlockBuilderView.swift` by path; "CREATE BLOCK" is pinned by `NewBlockBuilderFidelityTests` and `ProgramViewFidelityTests`.
- `RoutinesListView` has no caller, and its file declares `SessionRoute`, which Today and Program push; `MoveRoutineSheet` and `RoutineRow` are used only by it; `RoutineDuplicator` is used by `RoutineBuilderView` and `SessionTemplate`.
- The test inventory from `rg` matched the reviewers' lists and added `BlockReviewPRMarkTests`, `BRUPhase5GrepAuditTests`, `Phase3BRUGrepAuditTests`, `RoutinesListCopyTests`, `Fatigue/SuggestedActionTests` and `ExerciseHistoryRowsUITests` as suites to verify.

Not verified: whether adding an attribute to a SchemaV7 model would trip the incompatible-store reset (moot, since no attribute is added), and which "ALL HISTORY" `ExerciseHistoryRowsUITests` taps.
