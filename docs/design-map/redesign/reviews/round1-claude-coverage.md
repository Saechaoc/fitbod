# Round 1 review: capability coverage and factual accuracy

Reviewer: Claude worker, task task_1dca0a5403c8.
Code checked at `main` 0ef702ea, read-only.
Paths without a prefix are in the repository; `redesign/` is the proposal folder.

## Verdict

No, the proposal cannot be finalized as written.
Its central Today precedence depends on a review acknowledgement that the code does not perform: dismissing the block review does not set `reviewedAt`, so T-REVIEW would never clear and would hide T-READY for good.
Two more hero rules (the T-PICK suggestion and the "most recently edited" ready block) need data the models do not store, which contradicts the plan's "no data model change" promise.
The plan's test list also misses about twenty suites that the planned deletions, moves and copy changes will break, several of which read source files by path.
The rest of the findings are factual errors and lost capabilities that can be fixed in the documents without changing the direction.

## Findings

### Blocks finalization

**1. Dismissing the block review does not mark it reviewed, so T-REVIEW never clears.**
Trigger: a block ends, the lifter opens the review and closes it with "Plan custom" or a swipe.
Mechanism: only "Start next ▸" calls `acknowledge`, which sets `reviewedAt`; "Plan custom" only calls `dismiss()`, and the code comment says so on purpose.
The proposal states the opposite three times: the map says the sheet "opens by itself once", and today-layouts says REVIEW "marks `reviewedAt` on dismiss as now" and "Dismissing the review marks the block reviewed, as now".
Since T-REVIEW sits above T-READY, a lifter who already has a ready block can only reach START BLOCK ▸ by tapping Start next, which builds yet another block from the recommended template.
The design map already records this as a known bug (D-06), so "as now" describes a defect, not a behaviour to keep.
Blast radius: the Today hero for every lifter between blocks; T-READY becomes unreachable after any ended block; plan step 2.3's acceptance cannot pass.
Smallest fix: state in hierarchy.md and today-layouts.md that closing the review must call `acknowledge` (a behaviour change to `BlockReviewView`), list it as a plan 2.3 code change, and drop "as now".
Evidence: `fitbod/Periodization/BlockReviewView.swift:349-351`, `fitbod/Periodization/BlockReviewView.swift:355-358`, `fitbod/Periodization/BlockReviewView.swift:393-405`, `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:38-55`, `docs/design-map/audit.md` row D-06, `redesign/functionality-map.md:39`, `redesign/today-layouts.md:86`, `redesign/today-layouts.md:184`.
Severity: blocks finalization.

**2. The T-REVIEW trigger and the notice row do not match what "pending review" means in code.**
Trigger: a completed block with `reviewedAt == nil` while another block is active, or two ended blocks both unreviewed.
Mechanism: hierarchy.md defines T-REVIEW as "a completed block has no `reviewedAt` and no block is active", and the notice row covers the active case.
`pendingReviewBlocks` returns nothing while any block is active and returns only the latest-ended block, so older unreviewed blocks and the notice-row case have no query today.
Blast radius: the notice row (O-5) cannot be built from existing code; legacy stores with several unreviewed blocks get an undefined hero.
Smallest fix: define the notice-row query and say which unreviewed block wins (latest `endDate`), and whether older ones are ever surfaced.
Evidence: `fitbod/Periodization/BlockReviewView.swift:630-644`, `fitbod/Views/TodayView.swift:374-380`, `redesign/hierarchy.md:44`, `redesign/today-layouts.md:86`.
Severity: blocks finalization.

**3. The T-PICK suggestion rule and the ready-block choice need data the app does not store.**
Trigger: no active block and at least one routine, or several ready blocks.
Mechanism: today-layouts says the suggestion is "the slot after the most recent finished slotted workout", else "the routine edited most recently", and that "the most recently edited" ready block takes the hero.
Workouts started from the picker or the session sheet are ad hoc (`slot == nil`), so the suggestion never advances in the very state that shows it.
`Split` and `Block` have no edit timestamp; only `SessionTemplate` has `updatedAt`.
That contradicts plan.md's "Phase 1 changes no data model" and tradeoffs.md's "No data-model change in Phases 1 and 2".
Blast radius: the T-PICK hero, T-READY with several ready blocks, P-PLANNED card order, and the phase plan's no-schema promise.
Smallest fix: pick a rule the current models support (for example newest `Split.createdAt`, ready blocks by `startDate` then name) or add a V8 field and move the step out of the no-schema phases.
Evidence: `fitbod/Models/Split.swift:24-36`, `fitbod/Models/Block.swift:57-95`, `fitbod/Models/SessionTemplate.swift:47`, `fitbod/Routines/WorkoutStarter.swift:26-46`, `redesign/today-layouts.md:167`, `redesign/today-layouts.md:208-209`, `redesign/program-layouts.md:101`, `redesign/plan.md:4`, `redesign/tradeoffs.md:43`.
Severity: blocks finalization.

**4. The plan's test list misses suites that the planned changes will break.**
Trigger: running the full test plan after Phases 1 and 2.
Mechanism: the plan names eleven suites, but these also touch the changed code or copy and are not named.
Source-reading suites that fail when files move or are deleted: `BRUPeriodizationAuditTests` and `BRUPeriodizationRegressionTests` (read `StartBlockCTA.swift` and `DeloadWeekBanner.swift`), `NewBlockBuilderFidelityTests:62-69` (reads `ProgramView.swift` for the fullScreenCover, `BlockDraft.newBlock()` and "CREATE BLOCK"), `BlockReviewTriggerTests:193-201` (asserts `.sheet(item: $pendingBlockReview, onDismiss: showRecapAfterReview)` in `TodayView.swift`, which plan 2.3 removes).
UI suites that rely on `today.sessions`: `ReseedRelaunchUITests:68`, `WorkoutSwapJourneyUITests:41`, `WorkoutLoggerJourneyUITests:101,148`, `WeeklyRecapUITests:51`, `SkipWarmupsUITests:73`.
UI suites that rely on the auto-opened review or old copy: `BlockReviewAfterEndUITests:47-48`, `BlockLifecycleEntryPointsUITests:38-55`, `ArchiveRoutineUITests:290`, `NewBlockSavesUITests:96-104` and `EditorSwipeDismissUITests:75,127,135` ("Start a block", "< TODAY"), `BlockDraftKeepsUITests:30` ("CHOOSE PRESET"), `BlockWeekCountsUITests:72-73,119` (Today band PLAN COMPLETE chip).
Unit suites on removed or renamed views: `BlockPastPlanTests` (band chip and ticker, `ProgramView.activeBlockWeek`), `DeloadAdvisoryBannerBRUTests`, `BRUPrimitivesTests:131` ("Lift list"), `ExerciseDisplayNameSourceTests` (`LiftListRow`), `BlocksSectionTests:51` ("No blocks yet.").
Unverified but likely affected: `TodayPolishUITests` (added in 91b6b6ed), `BlockOverviewScreenCopyTests`, `BlockOverviewStatesTests`, `WeeklyRecapSheetBRUTests`, `WeeklyRecapTargetTests`.
Blast radius: every plan step ends red; source-reading suites fail silently until the full suite runs.
Smallest fix: add each suite to the step that breaks it, and add the guardrail suites to step 1.5, not only 2.6.
Evidence: paths and lines above, `redesign/plan.md:15-20`, `redesign/plan.md:31-37`.
Severity: blocks finalization.

### Fix soon

**5. T-ATTACH's OPEN BLOCK ▸ leads to a screen with no attach control.**
Trigger: an active block with no routine.
Mechanism: the attach and swap band on Block overview shows only for draft and ready blocks, and `attachSplit` refuses an active block.
Blast radius: a rare but dead-end state; the fix-it slab promises an action the destination cannot do.
Smallest fix: send T-ATTACH to END BLOCK or to the block editor, or allow attach on active blocks and say so in the plan.
Evidence: `fitbod/Periodization/BlockOverviewScreen.swift:299-303`, `fitbod/Periodization/BlockLifecycleService.swift:148-151`, `redesign/today-layouts.md:246`.
Severity: fix soon.

**6. T-DONE only covers slotted workouts, so A-09 persists for ad hoc workouts.**
Trigger: the lifter finishes a workout from the picker or session sheet today, or a slotted workout not attributed to the active block.
Mechanism: the rotation anchor is the latest completed session with `block == this block`, `slot != nil` and `slot.split == block.split`; an ad hoc workout does not move it, so T-TODAY offers the same session again.
The proposal does not say whether "finished today" uses `completedAt` or `startedAt`, nor what T-PICK shows after a workout.
Blast radius: the "done for today" fix the audit asks for works only in one path.
Smallest fix: define "finished today" as any non-empty session with `completedAt` today, for all states.
Evidence: `fitbod/Periodization/TodayResolver.swift:124-140`, `fitbod/Routines/WorkoutStarter.swift:26-46`, `redesign/audit.md:22`, `redesign/plan.md:31`.
Severity: fix soon.

**7. "46 sets" on the this-week row is not a count of logged sets.**
Trigger: any week with compound lifts.
Mechanism: the volume total sums stimulus-weighted direct plus indirect sets across muscles, so one bench set counts toward chest, triceps and shoulders.
T-DONE shows "15 SETS" for the same workout from logged sets, so the two numbers will disagree on one screen.
Blast radius: the one summary number the redesigned Today keeps.
Smallest fix: say which number the row shows and label it ("46 muscle sets" or a logged set count).
Evidence: `fitbod/Fatigue/FatigueSurfaceView.swift:118-122`, `fitbod/Fatigue/FatigueModel.swift:46`, `redesign/hierarchy.md:23`, `redesign/today-layouts.md:35`.
Severity: fix soon.

**8. Moving volume off Today loses the deload advisory ring.**
Trigger: a deload advisory is active.
Mechanism: `FatigueSurfaceView` takes `isAdvisoryActive` from Today and draws an amber ring on bars; Progress does not evaluate the advisory.
Blast radius: the visual link between the advisory and the muscles behind it.
Smallest fix: list the ring in the map and say whether Progress evaluates the advisory or the ring is dropped.
Evidence: `fitbod/Views/TodayView.swift:216-219`, `fitbod/Fatigue/FatigueSurfaceView.swift:50-52`, `fitbod/Fatigue/FatigueSurfaceView.swift:301`, `fitbod/Fatigue/MuscleVolumeBar.swift:300`.
Severity: fix soon.

**9. Deload sublines do not show reduced sets, and removing the banner loses the only explanation.**
Trigger: the current phase is a deload.
Mechanism: `LiftListRow` and `BlackSlabCTA` read the template's `targetSets`, not a deload-scaled count, and `LiftListRow` shows a fixed "2" warm-ups.
The banner's "Working sets cut by ~50%" text is the only place the cut is stated.
Blast radius: deload weeks show full-volume numbers with no warning.
Smallest fix: keep the banner text in the hero subline, or add deload scaling to the plan as code work.
Evidence: `fitbod/Views/LiftListRow.swift:50-51`, `fitbod/Views/BlackSlabCTA.swift:52-59`, `fitbod/Periodization/DeloadWeekBanner.swift:20-30`, `redesign/today-layouts.md:64`.
Severity: fix soon.

**10. The session sheet drops session detail and misstates the empty-workout discard.**
Trigger: the lifter wants to preview or edit a non-hero session from Today.
Mechanism: today the picker row opens `SessionTemplateDetailView` (preview, edit, last workout, start); the proposed sheet rows start the logger directly.
The sheet's "a workout with no sets discards without a prompt" is wrong: Finish with no work set shows a "Discard workout" dialog.
Blast radius: a lost route for every session except the hero; one wrong behaviour claim.
Smallest fix: list the detail route in the map as removed or moved, and correct the discard sentence.
Evidence: `fitbod/Views/TodaySessionPicker.swift:78-94`, `fitbod/Routines/SessionTemplateDetailView.swift:62-211`, `fitbod/Sessions/SessionLoggerView.swift:40-42`, `fitbod/Sessions/SessionLoggerView.swift:152-161`, `redesign/today-layouts.md:271`.
Severity: fix soon.

**11. Removing the automatic review sheet breaks the weekly recap's ordering.**
Trigger: a block ends at a week boundary.
Mechanism: `checkWeeklyRecap` defers the recap while a review is pending and shows it from the review sheet's `onDismiss`; plan 2.3 removes that sheet but keeps the recap (O-4) without saying when it now appears.
Blast radius: the recap may stack over the new T-REVIEW hero or never show.
Smallest fix: state the new recap trigger in plan 2.3.
Evidence: `fitbod/Views/TodayView.swift:309-312`, `fitbod/Views/TodayView.swift:629-660`, `redesign/plan.md:33`.
Severity: fix soon.

**12. Opening the review or builder from Program shows Today's back label.**
Trigger: the review or "Start next ▸" reached from Program.
Mechanism: `BlockReviewView` hard-codes `origin: .today` ("Only Today presents the review"), so the builder shows "< TODAY"; Program presents the builder as a fullScreenCover with a start-choice and preset chain, Today as a sheet with a blank template.
Blast radius: wrong back copy and two different New Block entry flows.
Smallest fix: list the origin parameter and the two presentation styles in the map, and say which one the redesign keeps.
Evidence: `fitbod/Periodization/BlockReviewView.swift:76-81`, `fitbod/Periodization/BlockBuilderView.swift:14-25`, `fitbod/Views/ProgramView.swift:233-272`, `fitbod/Views/TodayView.swift:298-307`.
Severity: fix soon.

**13. T-READY's START BLOCK ▸ has no error path.**
Trigger: `start` throws, for example the block is no longer ready.
Mechanism: the overview calls `try? start` and drops the error; the proposal copies the action to Today without an alert.
Blast radius: a silent no-op on the new main hero action.
Smallest fix: name the alert in today-layouts T-READY.
Evidence: `fitbod/Periodization/BlockOverviewScreen.swift:1355-1368`, `fitbod/Periodization/BlockLifecycleService.swift:75-105`.
Severity: fix soon.

**14. Several audit rows describe a build older than `main`.**
Trigger: a reader uses the audit to justify a change.
Mechanism: A-26 "1 sessions" was fixed by d227a1cb (`BRUCountLabel` is singular now); A-02 and A-06 (past-plan disagreement, day counter wraps) were fixed by 91b6b6ed (PLAN COMPLETE, no day past plan); A-01 cites "ACCUM" while its screenshot shows a dash placeholder; A-14 says the empty week reads "No sets logged this week", but the screenshot shows muscle rows because muscles with MEV above zero are always listed.
A-04 omits the orange COMPOUND chip and "±0" on the same screenshot.
Blast radius: four fixes aimed at bugs that are gone, and one aimed at an empty state that rarely shows.
Smallest fix: re-check each A row against `main` and mark fixed rows.
Evidence: `fitbod/Design/BRUCountLabel.swift:22-24`, `fitbod/Views/TodayView.swift:589-594`, `fitbod/Views/TodayStatStrip.swift:109`, `fitbod/Views/TodayStatStrip.swift:180`, `fitbod/Fatigue/FatigueSurfaceView.swift:106-115`, `redesign/audit.md:14-94`.
Severity: fix soon.

**15. Map rows misdescribe two current behaviours.**
Trigger: reading the map as the baseline.
Mechanism: the header date already shows the weekday ("Wed · May 22"), so "gains the weekday" is wrong; the overview's swap confirmation is the "Start Block?" block swap, not a routine swap.
Blast radius: two "Kept" rows hide that nothing changes, or that a confirmation does not exist.
Smallest fix: correct both rows.
Evidence: `fitbod/Views/TodayView.swift:451-462`, `fitbod/Periodization/BlockOverviewScreen.swift:1395-1411`, `redesign/functionality-map.md:13`, `redesign/functionality-map.md:71`.
Severity: fix soon.

**16. P-EMPTY says "Nothing else" but the archived routines entry still shows.**
Trigger: no live routines or blocks, but archived routines exist.
Mechanism: Program shows the archived entry even in the empty state.
Blast radius: a lifter who archived everything loses the way back if the layout is built as written.
Smallest fix: add the archived entry to P-EMPTY.
Evidence: `fitbod/Views/ProgramView.swift:153-170`, `redesign/hierarchy.md:93`.
Severity: fix soon.

**17. The functionality map omits capabilities and side effects the rebuild must keep.**
Trigger: building Phase 1 from the map alone.
Mechanism: not listed are the `deloadAlertEnabled` setting gate and the per-week dismissal (`deloadAdvisoryDismissedWeekStart`), the recap's `markRecapSeen` on appear, `RestTimerEngine` clearing on discard, the exclusion of empty workouts from counts, the picker's disabled START for sessions without exercises, the lift list's "Add an exercise to begin." placeholder, the `today.sessions`, `resumeSlab.resume`, `resumeSlab.discard` and `blockReview.*` identifiers, and the DEBUG seed flags the UI tests launch with.
`TrendDirection` lives in `TodayStatStrip.swift`, so deleting that file removes a type.
Blast radius: silent regressions and broken UI test launches.
Smallest fix: add one map row per item.
Evidence: `fitbod/Views/TodayView.swift:683-702`, `fitbod/Views/TodayView.swift:327-335`, `fitbod/Views/TodayView.swift:387-395`, `fitbod/Views/ResumeWorkoutSlab.swift:118`, `fitbod/Views/ResumeWorkoutSlab.swift:146`, `fitbod/Views/ResumeWorkoutSlab.swift:163-166`, `fitbod/Views/TodaySessionPicker.swift:96-99`, `fitbod/Views/LiftListSection.swift:42-53`, `fitbod/Views/TodayStatStrip.swift:18-26`, `fitbod/Views/TodayStatStrip.swift:167`, `fitbod/App/RootView.swift:120`.
Severity: fix soon.

## Checked and found correct

- Resume precedence above every other Today state.
- Resume slab confirms only when sets are logged; Program banner always confirms.
- Picker hidden when a session is scheduled (A-08).
- Start a block opens a blank builder (A-15).
- `noBlocksRow` only with zero blocks (A-25).
- ALL HISTORY ▸ threshold of more than three done blocks.
- Block cards have no chevron.
- `.emptySplit` and `.restDay` are distinct resolver cases.
- `BlockLifecycleService.start` ends the other active block.
- Program empty gate (no blocks and no live routines).
- Workout started yesterday and still open reaches T-RESUME.
