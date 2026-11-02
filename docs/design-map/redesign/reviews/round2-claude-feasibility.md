# Round 2 verification: feasibility lens

Reviewer: Claude, task task_28a4a2eeebd7, dispatch ctx_425431203c1e.
Bundle: draft v2.
Repository: `/Users/chrissaechao/Desktop/fitbod` at 0ef702ea.
Nothing was built or run; every claim is from reading the source, and anything not read is marked unverified.

## Verdict

Final as written, with 0 blockers and 9 fix-soon findings.
Every round 1 blocker is closed in the leaves.
Every Phase 1 step can be built with no schema change, no `ObservableObject`, no `@Query` in a view model and no multi-level optional chain in a `#Predicate`.
The fix-soon findings are wording and test-list gaps a step can absorb when it is planned; none changes the hierarchy.

## 1. Round 1 findings: closure status

| Round 1 | v2 id | Status | Where v2 closes it | What is left |
| --- | --- | --- | --- | --- |
| F-1 T-REVIEW trap | B-1 | Closed | hierarchy.md:58-65, today-layouts.md:195-205, plan.md:33 (2.1), risks.md:11 | The test list for 2.1 is incomplete (N-2). |
| F-2 timestamps need a schema change | B-3 | Closed | open-decisions.md O-6, hierarchy.md:45, today-layouts.md:228 (`SessionTemplate.updatedAt`) | None. |
| F-3 T-PICK slot data | B-2 | Partly closed | open-decisions.md:10 (O-2), today-layouts.md:313, plan.md:19 | A sheet start with no block is always unslotted, and a session can fill two slots (N-3, N-4). |
| F-4 CREATE BLOCK guardrail and sheets | B-5 | Closed | plan.md:21 (1.5 "CREATE BLOCK stays"), program-layouts.md:56, :201 | None. |
| F-5 unnamed suites | B-5 | Partly closed | plan.md:17-38 | All 31 suites I spot-checked exist; `ArchiveRoutineUITests` and `BlockReviewHeroLayoutTests` are missing from 2.1 (N-2). |
| F-6 phase ordering | F-13 | Partly closed | plan.md:17-26 | T-ATTACH in 1.3 leads to the attach button that 2.4 hides (N-6); 1.1's acceptance uses a seed 1.3 adds (N-7). |
| F-7 header orange | F-14 | Closed | program-layouts.md:55, risks.md:17 | None; see section 2.6. |
| F-8 this-week cost | F-3 | Partly closed | today-layouts.md:48, risks.md:15, plan.md:20 | The row counts the open workout and does not roll over at week start (N-1). |
| F-9 TodayState inputs and midnight | F-15 | Closed | plan.md:17, hierarchy.md:54, risks.md:12 | The new queries are not named in the step (N-8, wording only). |
| F-10 Volume wrapper | F-16 | Closed | plan.md:20, risks.md:29 | None; no route conflict (section 2.5). |
| F-11 start error path | F-17 | Closed | today-layouts.md:190-191, risks.md:18 | None. |
| F-12 T-ATTACH dead end | F-18 | Partly closed | today-layouts.md:283, plan.md:36 (2.4) | The fix lands in Phase 2 while the state ships in Phase 1 (N-6). |
| F-13 review push and origin | F-19 | Closed | plan.md:33, :36 | The origin parameter needs a default value (N-5). |
| F-14 middle truncation | F-8 | Closed | today-layouts.md (two Texts), plan.md:17 acceptance | None. |
| F-15 seeds | F-20 | Closed | plan.md:19, risks.md:27 | Ordering against 1.1 (N-7). |
| F-16 End block mid-workout | F-21 | Closed | open-decisions.md O-10 | None. |
| F-17 SESSIONS vocabulary | F-22 | Closed | plan.md:17 ("n / m WORKOUTS DONE", `BlockWeekCountsUITests`) | None. |

review-log.md claims no closure that I could not find in a leaf.
One claim is narrower than it reads: review-log.md:146 says the hero and sublines "show the counts the logger generates".
That holds for working sets only; the warm-up count cannot share the factory's rule (section 2.2).

## 2. Answers to the brief's questions

### 2.1 Phase 1 against the conventions

No Phase 1 step needs a schema change: `TodayState`, `BlockPosition`, `VolumeScreen`, `VolumeRoute`, `ThisWeekRow` and the seeds read stored fields only.
No step needs `ObservableObject` or a view model over `@Query`; the new inputs are `@Query` in TodayView with Swift post-filters, which TodayResolver already models (`fitbod/Periodization/TodayResolver.swift:104-128`).
The T-PICK anchor ("newest finished workout whose slot's routine is not archived") needs `session.slot?.split?.isArchived`, which must be a Swift filter after a flat `completedAt != nil` fetch, as the resolver does.
The plan does not say this, but it does not contradict it either.

### 2.2 The prescribed-count helper

Only the working-set count can be shared.
Inputs: `targetSets: Int` and the scheduled phase (`BlockPhase?`, read for its kind and `volumeMultiplier`).
Output: `phase is deload ? max(1, floor(targetSets × volumeMultiplier)) : targetSets`, as at `fitbod/Sessions/SessionFactory.swift:288-296`.
The helper should take the phase, not compute it, because the factory resolves the phase with the default `Calendar.current` (`SessionFactory.swift:186-189`) while Today will use the environment calendar.
The factory keeps its behaviour if it passes `re.targetSets` and `scheduledBlockPhase`.
The warm-up count cannot share `WarmupRamp.shouldGenerate` (`fitbod/Prescription/WarmupRamp.swift:49-79`).
It needs a `SessionExercise`, the prescribed top weight from a history fetch (`SessionFactory.swift:237-246`), the bar weight, `warmupOverride`, and the session-level rule that only the first qualifying compound gets a ramp (`SessionFactory.swift:255-267`).
The only part Today can share is "0 warm-ups in a deload" (guard 1).
`LiftListRow`'s "2 warm-up" reads `generateWarmups` (`fitbod/Views/LiftListRow.swift:50-56`), which the factory never reads, so outside a deload the subline stays an approximation for every row after the first ramp.
risks.md:25 accepts that approximation; plan.md:18 should say so (N-9).
`BlackSlabCTA` sums raw `targetSets` (`fitbod/Views/BlackSlabCTA.swift:49-53`) and can call the helper per row.

### 2.3 TodayState inputs TodayView does not already hold

| Input | Source | New query? |
| --- | --- | --- |
| Ready blocks | Broad `@Query<Block>`, Swift filter on `derivedStatus == .ready` | Yes, one Block query, which also feeds the next row |
| Pending review | `pendingReviewBlocks` over the same Block query | No, if derived from the Block query; otherwise a context fetch |
| Routines with a session that has exercises | `@Query<Split>(!isArchived)` as in `fitbod/Views/TodaySessionPicker.swift:18`, Swift filter on slots | Yes in TodayView, or lift the picker's |
| T-PICK suggestion | The finished-session list TodayView already holds, Swift-filtered on the slot's routine | No |
| T-PICK fallback | `SessionTemplate.updatedAt` across the routines above | No, if read through the Split query |
| Calendar | `@Environment(\.calendar)` | No |
| Scene activation and the time-change notice | `@Environment(\.scenePhase)`, `.onReceive` | No |

### 2.4 The this-week row

Making `fetchWorkingSets` non-private is not needed: `completedWorkingSets(startedFrom:before:in:)` is already internal (`fitbod/Fatigue/FatigueModel.swift:306-345`), and `fetchWorkingSets` only wraps it (`FatigueModel.swift:276-286`).
It is not enough as specified, for three reasons in N-1: the key misses the week boundary, the fetch counts the open workout, and the fetch does a full-history identifier pass a count does not need.

### 2.5 VolumeRoute and MuscleSlugRoute on Progress

No conflict found.
`ProgressHomeRoute` has five cases and none is a volume or muscle route (`fitbod/Progress/ProgressHomeView.swift:55-63`).
`sessionHistoryDestinations` registers `SessionHistoryRoute` only (`fitbod/Sessions/SessionHistoryRoute.swift:25-34`).
RootView owns one path per tab (`fitbod/App/RootView.swift:68`, reset at :184, `ProgressTabHost` at :273 and :380), so a new destination on the Progress host does not reach Today.
`PerMuscleDetailView` draws its own Back and hides the bar (`fitbod/Fatigue/PerMuscleDetailView.swift:100-128`), which matches Progress's hidden bar (`ProgressHomeView.swift:121`).

### 2.6 Program's `HeaderAction("+ New")` and the height measurement

BRUHeaderBar supports it.
`HeaderAction` exists with `isSignal` defaulting to false (`fitbod/Design/BRUHeaderBar.swift:47-61`, path from `rg --files`), so it draws in ink.
The row has a 44pt minimum height (`BRUHeaderBar.swift:181`, :221) and the label's touch area reaches past it through `bruHitArea` (:307).
The measurement is an `onGeometryChange` on Program's header container (`fitbod/Periodization/ProgramView.swift:118`, :134, used at :305), so it works with any header view.
The label renders as written, so the UI test target is "+ New"; matching is case-insensitive, as plan.md:21 notes.

### 2.7 The review as a sheet with acknowledge on dismiss

What breaks:
- `BlockReviewTriggerTests` pins `.sheet(item: $pendingBlockReview, onDismiss: showRecapAfterReview)` and `BlockReviewView(block: block)` (`fitbodTests/BlockReviewTriggerTests.swift:193-201`) and "Plan custom" (:175). Named in 2.1.
- `BlockLifecycleEntryPointsUITests` asserts that after a relaunch "the review the lifter put off opens again" (`fitbodUITests/BlockLifecycleEntryPointsUITests.swift:51-55`). Named in 2.1, but the step does not say this assertion is deleted because the behaviour is reversed on purpose.
- `BlockReviewAfterEndUITests` asserts "Today's first visit after the block ended must open its review" (`fitbodUITests/BlockReviewAfterEndUITests.swift:56-63`). Named, and the step says it taps the notice instead.
- `ArchiveRoutineUITests` has a helper that waits for the automatic review and taps "Plan custom" (`fitbodUITests/ArchiveRoutineUITests.swift:278-291`). Not named in 2.1.
- `BlockReviewHeroLayoutTests` (`fitbodTests/BlockReviewHeroLayoutTests.swift:105`) and `BlockReviewPRMarkTests` (`fitbodTests/BlockReviewPRMarkTests.swift:124`) construct `BlockReviewView(block: block)`. They break if the origin parameter has no default. HeroLayout is not named in 2.1.
- `BRUPrimitivesTests` builds a "Plan custom" button (`fitbodTests/BRUPrimitivesTests.swift:155`); the copy does not change, so it stays green.
`rg` for `BlockReviewView(`, "Plan custom", `pendingBlockReview` and `acknowledgeAndDismiss` over both test targets returns exactly these seven files.

### 2.8 Named suites

I checked 31 suite names from plan.md with `rg -l` over `fitbodTests` and `fitbodUITests`; every one exists.
The seven `today.sessions` users in plan.md:17 match `rg -l "today\.sessions"` exactly.
Missing: the two in N-2.

### 2.9 Phase 1 steps that still depend on Phase 2

One: T-ATTACH (1.3) sends the lifter to Block overview, which shows "+ ATTACH ROUTINE ▸" on an active block until 2.4 hides it (`fitbod/Periodization/BlockOverviewScreen.swift:299-302`, :927-935), and `attachSplit` refuses active blocks (`fitbod/Periodization/BlockLifecycleService.swift:148-151`) (N-6).
T-DONE's next line and the review notice are correctly deferred to Phase 2.

## 3. New findings

Ranked by blast radius.
No blockers.

### Fix soon

#### N-1 The this-week row counts the open workout and misses the week rollover

Trigger: a workout is open with sets logged, or Monday arrives with no new workout finished.
Mechanism: `completedWorkingSets` selects sessions by `startedAt` only, with no `completedAt` filter (`fitbod/Fatigue/FatigueModel.swift:306-345`), so the open workout's sets count while "workouts" counts finished ones; and a `.task(id:)` keyed only on finished workout IDs does not re-run when the week changes.
Blast radius: Today's last row shows numbers that disagree with each other during a workout and shows last week's numbers on Monday morning; read-only data, no store damage.
Smallest fix: key the task on the finished IDs plus the week start from `mondayAtMidnightForToday(weekStartsMonday:calendar:)` (`fitbod/Fatigue/MondayAtMidnight.swift:23-33`) with the environment calendar; count sets of finished, non-empty workouts only (`countedWorkouts`, `fitbod/Sessions/SessionSetActions.swift:136-147`); call `completedWorkingSets` directly, or add a count-only variant that skips the full-history identifier fetch.

#### N-2 Step 2.1's test list misses two suites and one reversed assertion

Trigger: step 2.1 runs its named suites and lands.
Mechanism: `ArchiveRoutineUITests`'s helper waits for the automatic review (`fitbodUITests/ArchiveRoutineUITests.swift:278-291`); `BlockReviewHeroLayoutTests` constructs the view (`fitbodTests/BlockReviewHeroLayoutTests.swift:105`); `BlockLifecycleEntryPointsUITests:51-55` pins the reopen-after-relaunch behaviour v2 removes.
Blast radius: two suites go red after the step reports green; one assertion might be "fixed" back toward the old behaviour.
Smallest fix: add both suites to 2.1 and state that the reopen-after-relaunch assertion is deleted.

#### N-3 One session can fill two slots, so "start with that slot" is ambiguous

Trigger: a routine slots Push A twice (for example Push A, Pull, Push A, Legs), and the lifter starts Push A from the sheet.
Mechanism: the Add session picker lists every non-archived template, slotted or not (`fitbod/Periodization/SplitDetailView.swift:780-781`), and `addSlot` has no duplicate guard (:869-890); O-2 (open-decisions.md:10) and today-layouts.md:313 say "starts with that slot" as if there were one.
Blast radius: the wrong slot becomes the rotation anchor (`TodayResolver.swift:124-140`), so the next hero skips or repeats a session.
Smallest fix: state the rule in O-2: the resolver's next slot if it holds this session, else the first slot after the anchor that holds it; add one `TodaySessionSheetTests` case.

#### N-4 With no block, a sheet start never moves the T-PICK suggestion

Trigger: no active block, and the lifter starts a session from the sheet instead of the hero.
Mechanism: O-2 slots a sheet row only when it belongs to "the active block's routine" (open-decisions.md:10), so with no block every sheet start is unslotted, and T-PICK's anchor needs a slotted workout (today-layouts.md:228).
Blast radius: the suggestion repeats a session the lifter just did by another route; plan.md:19's test "two no-block starts advance the suggestion twice" passes only through the hero.
Smallest fix: with no block, a sheet row of a routine starts with its slot under the same rule as N-3; or state that only the hero advances T-PICK and name the test that way.

#### N-5 BlockReviewView's origin parameter needs a default

Trigger: step 2.1 adds `origin` without a default value.
Mechanism: three constructors in tests (`BlockReviewTriggerTests.swift:193-201`, `BlockReviewHeroLayoutTests.swift:105`, `BlockReviewPRMarkTests.swift:124`) call `BlockReviewView(block:)`.
Blast radius: the test target does not compile.
Smallest fix: `origin: BlockBuilderView.Origin = .today`.
Also unverified: whether `acknowledge` on a block reviewed long ago overwrites `reviewedAt` when the review is reopened from Block overview (2.4); if it does, guard on `reviewedAt == nil`.

#### N-6 T-ATTACH ships in Phase 1 but its exit lands in Phase 2

Trigger: step 1.3 lands and a restored store has an active block with no routine.
Mechanism: OPEN BLOCK ▸ opens Block overview, which still shows the attach button on active blocks (`BlockOverviewScreen.swift:299-302`) until 2.4, and `attachSplit` throws on them (`BlockLifecycleService.swift:148-151`).
Blast radius: one defensive state the UI cannot produce; the lifter meets a button that fails.
Smallest fix: move "Hide + ATTACH ROUTINE ▸ on active blocks" from 2.4 into 1.3, with `BlockOverviewScreenCopyTests`.

#### N-7 Step 1.1's acceptance uses a seed step 1.3 adds

Trigger: step 1.1 runs its acceptance before 1.3.
Mechanism: 1.1 requires the `today--long-name` capture (plan.md:17), but the long-block-name seed is listed in 1.3 (plan.md:19).
Blast radius: 1.1 cannot meet its acceptance alone.
Smallest fix: add the long-name seed to 1.1, or move that capture to 1.3.

#### N-8 Step 1.1 does not name the new queries

Trigger: an executor builds `TodayState` from plan.md:17 alone.
Mechanism: the step lists inputs but not their sources; two need new `@Query`s and one needs a Swift post-filter on a two-level chain (section 2.3).
Blast radius: an executor may put `slot?.split?.isArchived` inside `#Predicate` or wrap the queries in a view model.
Smallest fix: add the table in section 2.3 to step 1.1, one line per input.

#### N-9 The helper's scope is wider in plan.md than the source allows

Trigger: step 1.2 is planned from plan.md:18.
Mechanism: the step says the factory, hero and sublines all call one helper "holding SessionFactory's deload rule ... warm-ups skipped", which reads as covering warm-ups too; `shouldGenerate` cannot be shared (section 2.2).
Blast radius: an executor tries to move warm-up logic out of the factory and changes what the logger generates.
Smallest fix: name the helper's signature as `workingSetCount(targetSets:phase:)`, say the warm-up subline is 0 in a deload and otherwise unchanged, and cite risks.md:25 for the accepted approximation.

## 4. Not verified

- Whether `BlockReviewStatistics.acknowledge` overwrites an existing `reviewedAt` (N-5).
- The width of the "+ New" touch area; the height is 44pt by the row minimum.
- Which "ALL HISTORY" `ExerciseHistoryRowsUITests` taps, carried over from review-log.md:109.
- The step 1.1 edit to the project CLAUDE.md: the baseline line is hand-written, not inside the profile section marked "do not edit manually", so I found no conflict, but GSD's own rules on CLAUDE.md edits were not read.
