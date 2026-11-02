# Round 1 feasibility review (Claude)

Lens: can the plan be built as written in this repository under its conventions, and which tests and layouts break.
Repository paths are relative to `/Users/chrissaechao/Desktop/fitbod`.
Proposal paths are relative to the bundle folder (`plan.md`, `hierarchy.md` and so on).
GitNexus was not used, because its index is 15 commits behind HEAD; every claim below was checked against the current source.

## 1. Verdict

No, the proposal cannot be finalized as written.
Five findings block it.
The new Today precedence can trap the lifter in T-REVIEW, because the review is acknowledged only by "Start next ▸", not on dismiss as risks.md R-3 claims.
Two defaults (O-6 and the T-PICK fallback) need timestamps that Block and Split do not store, which is a schema change the plan says it does not make.
The T-PICK suggestion rule reads slotted workouts that the app never writes when no block is active.
The test inventory misses at least fifteen suites, including a New Block guardrail suite that risks.md R-1 says is untouched.
The rest of the findings are fixable during the build, but several Phase 1 steps depend on Phase 2 pieces or on files the step tables leave out.

## 2. Findings, worst first

### F-1. **T-REVIEW can hold the hero for good, because closing the review does not mark it seen**

Trigger: a block ends, no block is active, and the lifter opens REVIEW BLOCK ▸ and leaves with "Plan custom" or a swipe down.
Mechanism: `reviewedAt` is written only by `acknowledge()`, and only "Start next ▸" calls it.
"Plan custom" calls `dismiss()` alone, and `acknowledgeAndDismiss()` has no caller.
risks.md R-3 says "`reviewedAt` is written on dismiss today", which is false.
With the automatic sheet gone and T-REVIEW above T-READY in the precedence, the review stays pending until the lifter taps "Start next ▸".
That button acknowledges and then opens a blank builder from a template, not the ready block.
Blast radius: a lifter who ends a block with a ready block waiting never sees START BLOCK ▸ on Today unless they open a builder for a block they do not want.
plan.md step 2.3's acceptance ("Ending a block leads to REVIEW BLOCK ▸, then START BLOCK ▸ when a ready block exists") cannot pass.
Smallest fix: acknowledge the review when it closes by any route (an `onDisappear` or the sheet's `onDismiss` calling `BlockReviewStatistics.acknowledge`), or put T-READY above T-REVIEW and show the pending review as a notice row.
Correct R-3 to match the code.
Add a TodayState test for "review closed with Plan custom → ready".
Evidence: `fitbod/Periodization/BlockReviewView.swift:347-359` (Plan custom dismisses only; Start next acknowledges then opens the builder), `fitbod/Periodization/BlockReviewView.swift:395-410` (acknowledge and the uncalled acknowledgeAndDismiss), `fitbod/Periodization/BlockReviewView.swift:74-78` (Start next opens `BlockDraft(template:)`), `fitbod/Periodization/BlockReviewView.swift:642` (pending while `reviewedAt == nil`), `hierarchy.md:44-45` (T-REVIEW above T-READY), `risks.md:10`, `plan.md:33`.
Severity: blocks finalization.

### F-2. **Two defaults need stored timestamps that do not exist, which is a schema change**

Trigger: two or more ready blocks (O-6), or T-PICK with no slotted workout yet.
Mechanism: O-6 picks "the most recently edited" ready block, and the T-PICK fallback picks "the routine edited most recently".
`Block` stores no edit or creation time; its only date besides `endDate` and `reviewedAt` is `startDate`, which the builder overwrites with the planned start on save and `BlockLifecycleService.start` overwrites with now.
`Split` stores `createdAt` but no `updatedAt`.
Implementing either default means a new attribute on a SchemaV7 model.
plan.md:4 says Phase 1 changes no data model, and CLAUDE.md pins SchemaV7 with no migration chain.
I did not verify whether adding an attribute would pass through lightweight inference or trip the incompatible-store reset (unverified); either way it is the schema change the plan rules out.
Blast radius: a lifter with two ready blocks, or a lifter with routines but no slotted history, gets a hero the build cannot compute as specified.
In the worst case the store is moved aside, along with the lifter's whole workout history.
Smallest fix: restate both defaults in terms of fields that exist.
O-6: the ready block with the earliest `startDate` (its planned start), matching the order Program already sorts by.
T-PICK fallback: the non-archived routine with the latest `createdAt`, or the one whose session templates have the latest `SessionTemplate.updatedAt`.
Evidence: `fitbod/Models/Block.swift:56-95` (stored fields), `fitbod/Periodization/BlockDraft.swift:151` (save writes `startDate`), `fitbod/Periodization/BlockLifecycleService.swift:101` (start writes `startDate = now`), `fitbod/Models/Split.swift:25` (createdAt only), `fitbod/Models/SessionTemplate.swift:46-47`, `fitbod/Periodization/ProgramView.swift:97`, `open-decisions.md:13`, `today-layouts.md:167`, `today-layouts.md:208-209`, `plan.md:4`.
Severity: blocks finalization.

### F-3. **The T-PICK suggestion reads slotted workouts that the app never writes without a block**

Trigger: no active block and at least one routine with a session (T-PICK).
Mechanism: the rule is "the slot after the most recent finished slotted workout, in that workout's routine".
Only Today's hero passes a slot to `WorkoutStarter`, and the hero exists only under an active block; the picker and every other caller pass `slot: nil`.
So with no block, no workout is ever slotted, and the suggestion never moves however many workouts the lifter logs.
If an old block left slotted workouts behind, the suggestion follows that stale anchor, which can point into an archived routine.
plan.md step 1.3 does not say whether starting the suggested session writes its slot.
Blast radius: every no-block lifter sees the same suggested session after every workout, which is the exact replay the core value rejects.
Smallest fix: have T-PICK's START WORKOUT pass the suggested slot to `WorkoutStarter.start`, and define the anchor as the newest finished workout whose slot belongs to a non-archived routine.
`TodayResolver` already ignores workouts whose `block` is not the active block, so a slotted no-block workout cannot disturb a later block's rotation.
Add a unit test that two no-block workouts advance the suggestion twice.
Evidence: `fitbod/Views/TodayView.swift:163-168` (hero passes the slot), `fitbod/Views/TodayView.swift:195-199` (picker starts with no slot), `fitbod/Routines/WorkoutStarter.swift:29-34` (slot defaults to nil), `fitbod/Periodization/TodayResolver.swift:124-128` (anchor filter on `block?.id`), `today-layouts.md:208`, `plan.md:17`.
Severity: blocks finalization.

### F-4. **The New Block guardrail claim is false, and moving the sheets is a bigger refactor than the step lists**

Trigger: plan.md step 1.5 moves `NewBlockStartChoiceSheet` and `NewBlockPresetPickerSheet` to `NewBlockSheets.swift` and renames "CREATE BLOCK" to "NEW BLOCK".
Mechanism: `NewBlockBuilderFidelityTests`, one of the three New Block guardrail suites, reads `ProgramView.swift` and expects "CREATE BLOCK" and `.fullScreenCover(item: $pendingBlockBuilder)` there.
`ProgramViewFidelityTests` also expects "CREATE BLOCK" in `ProgramView.swift`.
risks.md R-1 says the guardrail suites are untouched because New Block does not change.
The sheets also do not move alone.
Program chains them through `presentingStartChoice`, `presentingPresetPicker`, `stagedBuilder`, two `onDismiss` handlers and `blockSheetDetents`, and then opens the builder full screen with `BlockDraft.newBlock()` and `initialPreset:`.
Today's `PendingBlockBuilder` has no `.newBlock` case and presents the builder as a sheet.
Blast radius: step 1.5 turns a guardrail suite red, and "Plan a block ›" on Today either duplicates Program's staging state or opens a different builder presentation than Program.
Smallest fix: move the sheets together with their staging logic as one view modifier (for example `.newBlockFlow(isPresented:)`) used by both tabs, keep the builder full screen in both, update the two pinned expectations in the same step, and name all three guardrail suites (`NewBlockBuilderFidelityTests`, `BlockBuilderViewCopyTests`, `BlockBuilderViewActivationTests`) in step 1.5.
Evidence: `fitbodTests/NewBlockBuilderFidelityTests.swift:60-69`, `fitbodTests/ProgramViewFidelityTests.swift:233-234`, `fitbod/Periodization/ProgramView.swift:233-269` (cover and staging), `fitbod/Periodization/ProgramView.swift:750-763` (CREATE BLOCK), `fitbod/Views/TodayView.swift:298-307` and `fitbod/Views/TodayView.swift:706-718` (Today's sheet and enum), `risks.md:8`, `plan.md:19`.
Severity: blocks finalization.

### F-5. **At least fifteen suites that pin removed strings, identifiers or files are not named**

Trigger: steps 1.1, 1.3, 1.5, 1.6, 2.3, 3.2 and 3.3 remove or rename what these suites assert.
Mechanism: risks.md R-2 says two UI suites use `today.sessions`; seven do, and two of them use it as the "Today has loaded" signal, so they fail before reaching their real subject.
Other suites read files the plan deletes, call static helpers on views it deletes, or tap controls it removes.
Suites the plan does not name:
- `fitbodUITests/ReseedRelaunchUITests.swift:68`, `fitbodUITests/SkipWarmupsUITests.swift:73`, `fitbodUITests/WeeklyRecapUITests.swift:51`, `fitbodUITests/WorkoutLoggerJourneyUITests.swift:101` and `:148`, `fitbodUITests/WorkoutSwapJourneyUITests.swift:41` (`today.sessions`).
- `fitbodUITests/NewBlockSavesUITests.swift:96-104` and `fitbodUITests/EditorSwipeDismissUITests.swift:75-76` and `:135` (tap Today's "Start a block", which step 1.3 deletes; EditorSwipeDismiss also loses its only Today-sheet builder path).
- `fitbodTests/BRUPeriodizationAuditTests.swift:217-218` and `fitbodTests/BRUPeriodizationRegressionTests.swift:217-220` (read `StartBlockCTA.swift` and `DeloadWeekBanner.swift`, which steps 1.1 and 1.3 delete).
- `fitbodTests/BlockPastPlanTests.swift:66-69` and `:101` (call `BlockContextBand.chipLabel` and `tickerWeek`).
- `fitbodTests/BlockReviewTriggerTests.swift:193-201` (pins the review sheet wiring in TodayView that step 2.3 removes) and `:105`, `:118` (see F-9).
- `fitbodTests/SessionWidgetsBRUCopyTests.swift:141-155` (pins ResumeWorkoutBanner, which step 1.6 changes).
- `fitbodTests/DeloadAdvisoryBannerBRUTests.swift` (step 1.1 reduces the banner).
- `fitbodTests/BRUPrimitivesTests.swift` ("Lift list", which step 1.2 relabels).
- `fitbodTests/NewBlockBuilderFidelityTests.swift:68` (see F-4).
- Phase 3.2, deleting `RoutinesListView.swift`: `RoutinesListBRUCopyTests`, `RoutinesListCopyTests`, `BlocksSectionTests` (its source is RoutinesListView, `fitbodTests/BlocksSectionTests.swift:46-61`), `ActiveSessionConflictTests`, `RoutineDraftValidationTests`, `SupersetGroupTests`, `Phase3BRUGrepAuditTests`, plus the app files `MoveRoutineSheet.swift`, `NewFolderSheet.swift`, `RoutineDuplicator.swift` and `RoutineRow.swift` that reference it.
- Phase 3.3, deleting `BlockCard.swift` and `BlockRow.swift`: `BlockCardWeekNavigationTests`, `BlockLifecycleEntryPointsTests`, and the app caller `fitbod/Periodization/BlockPickerMenu.swift`, which uses BlockRow.
The UI suites that tap "+ NEW" (`NewBlockSavesUITests`, `BlockDraftKeepsUITests`, `SlottedSessionDeleteUITests`, `SwipeBackUITests`) keep matching, because `UITestNavigation.hittable` compares labels without case, so they need no change for the label alone.
Blast radius: each Phase 1 step that runs only its named suites lands with other suites red, which is the failure the project memory records for New Block.
Smallest fix: give Today a stable root identifier (for example `today.root` on the header or hero), point the seven `today.sessions` suites at it or at Progress › History, and add the suites above to each step's "Tests to update" column.
Evidence: as listed, plus `fitbod/Views/TodayStatStrip.swift:167` (the identifier), `fitbodUITests/UITestNavigation.swift:537-539` (case-insensitive match), `risks.md:8-9`, `plan.md:15-20`, `plan.md:44-45`.
Severity: blocks finalization.

### F-6. **Phase 1 steps depend on pieces the plan builds later**

Trigger: building Phase 1 in the stated order (1.1, 1.2, 1.3, then 1.4, then 1.5 and 1.6).
Mechanism: step 1.3 adds "Plan a block ›" on T-PICK, which opens "the same start-choice sheet Program uses", but that sheet only becomes shareable in step 1.5, which is ordered last.
Step 1.3 builds five state slabs before `TodayState` exists (step 2.1), so the precedence is written twice in `TodayView.body` and then rewritten.
T-REST's "Next: Upper A · Tue" needs `nextTrainingDay`, which is step 2.2.
Step 1.1 says `BlockPosition.label` is used on Block overview, but `BlockOverviewScreen.swift` is not in its file list; the overview still shows "W\(n) / \(total)".
Blast radius: Phase 1 ships a dead "Plan a block ›" row or an interim copy of Program's sheets, and the three readouts disagree until a later step.
Smallest fix: move the sheet extraction (F-4) into step 1.3 or ahead of it, move `TodayState` into Phase 1 ahead of 1.3, mark T-REST's "next" line as Phase 2, and add `BlockOverviewScreen.swift` and its tests to step 1.1.
Evidence: `plan.md:17`, `plan.md:19`, `plan.md:22-24`, `plan.md:31-32`, `plan.md:15`, `fitbod/Periodization/BlockOverviewScreen.swift:583`, `functionality-map.md:27`, `functionality-map.md:33`.
Severity: fix soon.

### F-7. **Program's "+ New" through `HeaderSlot.action` is orange and has a smaller target**

Trigger: step 1.5 puts `HeaderSlot.action("+ New")` in Program's BRUHeaderBar.
Mechanism: `SlotView` renders every `.action` slot with `isSignal: true`, so "+ New" becomes a signal-colored label on every Program state.
That breaks "one signal element per screen" and step 1.6's acceptance ("One orange element on Program with a workout open"), since the resume banner already takes the signal.
The header label's touch area is the label plus a 12pt reach (`bruHitArea`), while ProgramChromeHeader gives "+ NEW" a measured 44pt target today.
The popover's position comes from the measured header height, so the new header needs the same `onGeometryChange` measurement.
Blast radius: two orange elements on P-ACTIVE and P-RESUME, and a smaller "+ New" target.
Smallest fix: use the `HeaderAction` form (`BRUHeaderBar(left:center:right:)` with `HeaderAction("+ New")`, whose `isSignal` defaults to false), keep the height measurement, and check the target height on the 17e capture.
Evidence: `fitbod/Design/BRUHeaderBar.swift:93`, `fitbod/Design/BRUHeaderBar.swift:369-370`, `fitbod/Design/BRUHeaderBar.swift:47-64`, `fitbod/Design/BRUHeaderBar.swift:301-305`, `fitbod/Periodization/ProgramView.swift:133-137`, `fitbod/Periodization/ProgramView.swift:307`, `fitbod/Periodization/ProgramView.swift:1048`, `hierarchy.md:4`, `plan.md:19-20`, `risks.md:16`.
Severity: fix soon.

### F-8. **The this-week row is costly on every Today render, and its "sets" is not a set count**

Trigger: any Today render once step 1.4 adds the row.
Mechanism: the volume total comes from `FatigueModel.weeklyVolumes`, which fetches every working set of the week and walks each set's exercise and muscle stimuli; FatigueSurfaceView calls it twice per body pass (this week and last week).
The number is a sum of stimulus-weighted sets per muscle, so one bench set adds to chest, triceps and shoulders.
"2 workouts · 46 sets" can therefore describe twenty logged sets.
risks.md R-7 promises "a narrower query", but no such API exists.
`TodayView.body` re-runs on every change to its whole-history `@Query`, so a body-time computation repeats the fetches each time.
Blast radius: Today keeps much of the cost the move was meant to remove, and the row tells the lifter a set count they did not log.
Smallest fix: count working sets (the count of `FatigueModel.fetchWorkingSets` for this week and last week), label them as sets, and compute them in a `.task(id:)` keyed on the finished workout IDs, as `emptyWorkoutIDs` already is.
Evidence: `fitbod/Fatigue/FatigueModel.swift:123-141`, `fitbod/Fatigue/FatigueSurfaceView.swift:96-101`, `fitbod/Fatigue/FatigueSurfaceView.swift:113-130`, `fitbod/Fatigue/FatigueSurfaceView.swift:171`, `fitbod/Views/TodayView.swift:56-57`, `fitbod/Views/TodayView.swift:387-395`, `hierarchy.md:23`, `risks.md:14`.
Severity: fix soon.

### F-9. **TodayState's inputs are not all available as the plan describes, and the day boundary is undefined**

Trigger: step 2.1 builds `TodayState` from (open workouts, active block, resolution, workouts finished today, pending reviews, ready blocks, routines) "with the injected calendar".
Mechanism, input by input:
- Pending reviews: `pendingReviewBlocks` returns nothing while any block is active, so it cannot feed the O-5 notice row "Summer Block finished · Review ›". That notice also contradicts two pinned tests and the function's documented contract that starting a block stops a put-off review.
- Ready blocks: `derivedStatus` is computed, so it cannot go in a `#Predicate`; a broad `@Query` on all blocks with a Swift filter works and is cheap.
- Resolution: it needs a `ModelContext` fetch, so it must be computed in the view and passed in as a value. A pure function is still possible, because every other input is already a `@Query` result.
- Calendar: there is no injected calendar in TodayView. It calls `TodayResolver.resolve` and `PeriodizationEngine` with their `Calendar.current` defaults.
- Day boundary: nothing re-renders Today at midnight (no `scenePhase` or `significantTimeChange` handling), so T-DONE or T-TODAY stays on screen into the next day while the app is open.
- Day attribution: R-4 uses `isDateInToday(completedAt)`, but Today's week counts use `startedAt`. A workout started at 23:40 and finished at 00:30 shows DONE on the next day and hides that day's planned session.
- T-DONE's rule disagrees between files: "a workout with a slot finished today" in hierarchy.md, but "any workout finished today, slotted or not" as the O-3 default.
- T-DONE exists only under an active block. A no-block lifter who just finished a workout sees T-PICK's orange START WORKOUT again, which fails step 2.2's acceptance.
Blast radius: wrong hero around midnight and across time zones, a notice row the existing review rules forbid, and an orange button after the day's workout for no-block lifters.
Smallest fix: read `@Environment(\.calendar)` and pass it to the resolver, the engine and `TodayState`.
Re-evaluate on `scenePhase` becoming active and on `UIApplication.significantTimeChangeNotification`.
Attribute a workout to the day of its `startedAt`.
Pick one T-DONE rule and allow it with or without a block.
Either drop the O-5 notice or change `pendingReviewBlocks` and its tests on purpose, in step 2.3.
Evidence: `fitbod/Periodization/BlockReviewView.swift:625-643`, `fitbodTests/BlockReviewTriggerTests.swift:105`, `fitbodTests/BlockReviewTriggerTests.swift:118`, `fitbod/Models/Block.swift:122-130`, `fitbod/Views/TodayView.swift:570-573`, `fitbod/Views/TodayView.swift:381-383`, `fitbod/Views/TodayView.swift:529-534`, `fitbod/Prescription/PeriodizationEngine.swift:21`, `fitbod/Prescription/PeriodizationEngine.swift:39`, `hierarchy.md:48`, `hierarchy.md:61`, `open-decisions.md:10`, `open-decisions.md:12`, `risks.md:11`, `plan.md:31-32`.
Severity: fix soon.

### F-10. **Moving Volume to Progress needs a screen wrapper, a shared route and the advisory state**

Trigger: step 1.4.
Mechanism: FatigueSurfaceView is a section, not a screen. Today embeds it in its own ScrollView, and it has no header, back control or scroll container.
`ProgressHomeRoute` is registered only on Progress's stack, so Today cannot push a `ProgressHomeRoute.volume` without registering Progress's whole route enum.
`MuscleSlugRoute` is registered only on Today's stack today.
`isAdvisoryActive`, which draws the amber ring on the bars, comes from Today's `currentAdvisory`. The file header mentions a "DeloadAdvisor refresh task", but no task exists, so opened from Progress the rings disappear.
Blast radius: Volume pushed from either tab shows no back control or does not scroll, and the deload highlight is lost on Progress.
Smallest fix: add a `VolumeScreen` (BRUHeaderBar with `.back`, a ScrollView and `navigationBarHidden`) that evaluates `DeloadAdvisor.evaluate` on appear.
Add a small `VolumeRoute` enum and register it and `MuscleSlugRoute` on both stacks.
Add the new file and its registration on Today to step 1.4's file list.
Evidence: `fitbod/Views/TodayView.swift:98`, `fitbod/Views/TodayView.swift:216-219`, `fitbod/Views/TodayView.swift:248-253`, `fitbod/Fatigue/FatigueSurfaceView.swift:25`, `fitbod/Fatigue/FatigueSurfaceView.swift:50-64`, `fitbod/Progress/ProgressHomeView.swift:60`, `fitbod/Progress/ProgressHomeView.swift:104-128`, `plan.md:18`.
FatigueSurfaceViewBRUTests pins copy inside FatigueSurfaceView only (`fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift:79-146`), so the move leaves it green; step 2.7's collapse row must keep "No sets logged this week" and "Volume This Week".
Severity: fix soon.

### F-11. **Starting the ready block from Today has no error path, and a draft block disappears from Today**

Trigger: START BLOCK ▸ on T-READY, or a ready block whose routine loses its last session.
Mechanism: risks.md R-10 says failures surface in the existing "Couldn't start" alert, but that alert is for workouts. Block overview calls `BlockLifecycleService.start` with `try?` in both places.
`derivedStatus` is live, so a block that was ready at render time can be a draft at tap time and throw `notReady`.
A ready block whose routine has no sessions becomes a draft (`missingPiece == .session`). Today then falls to T-PICK or T-FIRST, with nothing that says a block is waiting.
One-active-block and the swap confirmation are fine here: T-READY requires that no block is active, so `start` never takes its swap path from Today.
Blast radius: a tap that does nothing, and a planned block the lifter cannot see from Today.
Smallest fix: catch `start`'s error on Today and show a block-specific alert.
When a draft or ready block exists that cannot start, show a notice row naming the missing piece and opening Block overview.
Evidence: `fitbod/Periodization/BlockLifecycleService.swift:75-79`, `fitbod/Periodization/BlockOverviewScreen.swift:1357-1368`, `fitbod/Periodization/BlockOverviewScreen.swift:1402-1406`, `fitbod/Views/TodayView.swift:358-368`, `fitbod/Models/Block.swift:161-166`, `risks.md:17`, `hierarchy.md:45`.
Severity: fix soon.

### F-12. **T-ATTACH sends the lifter to a button that does nothing**

Trigger: an active block with no routine (the resolver returns `.noBlock` with an active block).
Mechanism: T-ATTACH's only action is OPEN BLOCK ▸.
Block overview shows "+ ATTACH ROUTINE ▸" on every non-completed block, including active ones.
`attachSplit` refuses active blocks with `splitChangeOnActiveBlock`, and the overview swallows the error with `try?`.
Blast radius: the hero's only action leads to a silent no-op, and the lifter is stuck in T-ATTACH until they end the block.
Smallest fix: make T-ATTACH's action END BLOCK with the existing confirmation, or allow `attachSplit` on an active block whose split is nil (a lifecycle rule change that needs its own test).
Hide the attach button on active blocks either way.
Evidence: `fitbod/Periodization/BlockOverviewScreen.swift:299-302`, `fitbod/Periodization/BlockOverviewScreen.swift:927-935`, `fitbod/Periodization/BlockOverviewScreen.swift:1629-1635`, `fitbod/Periodization/BlockLifecycleService.swift:148-151`, `hierarchy.md:47`.
Severity: fix soon.

### F-13. **Review from Block overview cannot be a push, and its "Start next" names the wrong tab**

Trigger: step 2.6's "Review ›" on a completed block's overview, reached from Program.
Mechanism: BlockReviewView wraps itself in a NavigationStack and uses `.back`, which calls `dismiss`, so it is built to be a sheet.
Pushing it onto Program's stack nests a second NavigationStack, which breaks the one-stack-per-tab rule.
Its "Start next ▸" opens the builder with `origin: .today`, under the comment "Only Today presents the review", so on Program the builder's back control reads "< TODAY".
Blast radius: broken back behavior and wrong copy on the review the lifter opens from Program.
Smallest fix: present the review as a sheet from Block overview, and pass the origin into BlockReviewView.
Evidence: `fitbod/Periodization/BlockReviewView.swift:43-49`, `fitbod/Periodization/BlockReviewView.swift:74-78`, `fitbod/Periodization/BlockBuilderView.swift:14-24`, `plan.md:36`, `functionality-map.md:72`.
Severity: fix soon.

### F-14. **The middle-truncation claim does not hold for a single Text**

Trigger: a long block name in the plan line or the Now slab (R-8, and step 1.5's `program--long-name` acceptance).
Mechanism: `.truncationMode(.middle)` on one Text holding "NAME · WEEK 12 OF 12 · INTENSIFICATION ›" puts the ellipsis in the middle of the whole string, so the week is cut, not the name.
Keeping the week needs the name and the position as separate Texts, with the position at a higher `layoutPriority` and `fixedSize`.
Two Texts in an HStack also need a planned wrap at accessibility sizes, since the proposal wants the chevron kept on the first line.
Blast radius: the one place Today and Program say where the lifter is in the block hides that fact for long names.
Smallest fix: specify the two-Text layout in today-layouts.md and program-layouts.md, and build the accessibility-size form with `ViewThatFits` or the `isAccessibilitySize` switch the repo already uses.
Evidence: `risks.md:15`, `plan.md:19`, `today-layouts.md:42`, `today-layouts.md:284`, `fitbod/Views/BlockContextBand.swift:103`.
Severity: fix soon.

### F-15. **The required captures need DEBUG seeds the plan does not list**

Trigger: plan.md:9 asks for 17e light and dark captures of every state each step touches, plus `program--long-name`.
Mechanism: the existing seed arguments cover an active block, block states, a past plan, ended-block recaps and demo workouts.
I found no seed that produces T-DONE (a slotted workout finished today), T-PICK (routines, no block), or a long block name.
I did not verify whether `-fitbod-seed-block-states` leaves a ready block with none active (unverified).
Blast radius: the acceptance captures cannot be made reproducibly, so the persistence and relaunch rules in CLAUDE.md cannot be followed for these states.
Smallest fix: add the seeds to the step file lists (`fitbod/App/*Seed.swift` and the launch-argument switch) for each new state.
Evidence: `fitbod/App/BlockStatesSeed.swift:41-42`, `fitbod/App/ActiveBlockSeed.swift:39`, `fitbod/App/ActiveBlockSeed.swift:56-57`, `fitbod/App/DemoWorkoutSeed.swift:54-60`, `plan.md:9`, `plan.md:19`.
Severity: fix soon.

### F-16. **Ending the block from a Today notice row is two taps away during a workout**

Trigger: plan complete while a workout is open (T-RESUME with the plan-complete notice).
Mechanism: notice rows stack independently of the hero, so END BLOCK ▸ shows above RESUME.
`BlockLifecycleService.end` freezes the archive at that moment, while the open workout belongs to the ended block and finishes after the freeze.
I did not verify whether `ArchivedBlockConfig` holds workout data that would then be missing (unverified).
The "End block?" alert lives inside BlockOverviewScreen's body, so step 2.4 must move it into a shared modifier before Today can use it.
Blast radius: a lifter can end the block in the middle of its last workout.
Smallest fix: hide the plan-complete notice in T-RESUME, and list the alert extraction in step 2.4.
Evidence: `hierarchy.md:39`, `hierarchy.md:59`, `fitbod/Periodization/BlockOverviewScreen.swift:329-340`, `fitbod/Periodization/BlockLifecycleService.swift:122-138`, `plan.md:34`.
Severity: fix soon.

### F-17. **The shared vocabulary would rename a pinned Block overview count**

Trigger: applying "A logged workout: workout, never SESSIONS" everywhere, as hierarchy.md says.
Mechanism: Block overview shows "n / 2 SESSIONS DONE", which `BlockWeekCountsUITests` asserts.
The plan does not say whether Block overview's copy changes, though the vocabulary table says it covers Block overview.
Blast radius: either the vocabulary does not hold on Block overview, or a UI suite turns red without being named.
Smallest fix: state the scope, and if Block overview changes, add the suite to the step.
Evidence: `hierarchy.md:105-110`, `fitbodUITests/BlockWeekCountsUITests.swift:23-42`.
Severity: fix soon.

## 3. Checked and found correct

- No `ObservableObject` or view model wrapping `@Query` is implied by any step.
- `BlockLifecycleService.start` preconditions and the one-active-block swap transaction.
- T-READY never needs the swap confirmation (no block is active).
- TodayResolver's rotation anchor ignores unslotted and no-block workouts, so O-2's default holds.
- `PlanWeek.of` gives the plan-complete notice its trigger without new state.
- `UserSettings.deloadAdvisoryDismissedWeekStart` carries the deload notice's dismiss.
- `HeaderSlot.action` exists, and UI suites match "+ NEW" without case.
- `.buttonStyle(.bruRow)` exists for the plan line.
- `Session.totalDurationSeconds` and `loggedSetCount` supply T-DONE's and T-RESUME's meta line.
- `FatigueSurfaceViewBRUTests` pins only FatigueSurfaceView's own source.
- `RoutinesListView` is not mounted on any tab.
- No schema change in steps 1.1 to 1.6 or 2.1 to 2.7 apart from F-2.
