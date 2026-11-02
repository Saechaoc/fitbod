# Round 3 coverage and factual accuracy review

Not final: 2 blockers.
Draft v3 still omits an existing alternate-workout path in two repair states and leaves the new Program start controls without a complete state contract.
The capability inventory and audit fact checks are saved; remaining checks are listed under Not reached and will be removed as they are completed.

Repository paths are relative to `/Users/chrissaechao/Desktop/fitbod`.
Proposal paths are relative to `docs/design-map/redesign/`.
This review concerns coverage and factual accuracy, not visual preference.
The current HEAD is `64f7d7a0`; comparison with `0ef702ea` found no changes under fitbod, fitbodTests or fitbodUITests, or in CLAUDE.md or docs/DEVELOPMENT.md.
No builds, tests, simulator runs, or source edits were performed.

## Blockers

### 1. **Two repair states silently lose the existing alternate-workout entry point**

Trigger: An active block has an empty routine or has lost its routine while another usable session exists.
Mechanism: Main shows TodaySessionPicker whenever there is no open workout and no resolved template, but v3 gives the empty-routine T-FIX state and T-ATTACH only their repair action, reserving Choose another session for the empty-session variant.
Blast radius: Lifting from an alternate session becomes unavailable directly from Today in these two states even though the functionality map claims to account for the picker and both repair paths.
Smallest fix: Include the existing alternate-session entry in both states, or record its intentional removal as an explicit product decision and identify the replacement path.
Evidence: `fitbod/Views/TodayView.swift:172`, `fitbod/Views/TodayView.swift:181`, `fitbod/Views/TodayView.swift:194`, `hierarchy.md:47`, `hierarchy.md:48`, `today-layouts.md:289`, `today-layouts.md:292`, `functionality-map.md:36`, `functionality-map.md:38`, `functionality-map.md:39`.
Severity: blocks finalization.

### 2. **Program's new start rows lack the state coverage specified for Today**

Trigger: A rotation block resolves to an empty session, a workout is already open, or a workout was finished today.
Mechanism: The rotation layout makes NEXT start a workout without specifying these cases, while the explicit open-workout suppression names only TODAY and the implementation step requires the Program rows to agree with Today.
Blast radius: The implementer must invent whether Program offers an empty-template start, resumes an open workout, or offers another start after Today's DONE state; the Today empty-session repair does not close this new entry point.
Smallest fix: Specify the result of both TODAY and NEXT for empty templates, open workouts and completed-today workouts, preserve WorkoutStarter's result handling, and add these cases to the proposed ThisWeekSectionTests.
Evidence: `program-layouts.md:79`, `program-layouts.md:80`, `program-layouts.md:166`, `plan.md:35`, `hierarchy.md:44`, `hierarchy.md:45`, `hierarchy.md:47`, `fitbod/Views/TodayView.swift:603`, `fitbod/Views/TodayView.swift:610`.
Severity: blocks finalization.

## Fix soon

### 3. **No-active-block fatigue advice is removed without a recorded decision**

Trigger: A lifter trains without an active block and meets the existing advisory conditions.
Mechanism: Main's advisory refresh checks the settings and enabled flag without requiring an active block, but the new shared hierarchy adds that requirement and the map describes the advisory as kept.
Blast radius: No-block lifters lose an advisory path without an O-row explaining the scope change.
Smallest fix: Keep main's eligibility rule or explicitly record the added active-block gate in the map and open decisions.
Evidence: `fitbod/Views/TodayView.swift:108`, `fitbod/Views/TodayView.swift:683`, `fitbod/Views/TodayView.swift:689`, `hierarchy.md:63`, `functionality-map.md:16`, `functionality-map.md:17`, `open-decisions.md:9`.
Severity: fix soon.

### 4. **The child-screen capability inventory is incomplete**

Trigger: An implementer uses the functionality map as the checklist for unchanged Block overview and review behavior.
Mechanism: The map records navigation into child screens but lacks dispositions for the child capabilities enumerated in the inventory below, including routine mutations, target editing, overview scheduling and inert EXPORT.
Blast radius: Behavior reachable from both redesigned tabs has no explicit keep, move, remove or fix disposition.
Smallest fix: Add compact grouped rows marking these children unchanged, explicitly name their mutations and failure states, and distinguish swapping a routine from confirming replacement of an active block; no redesign of these screens is required.
Evidence: `functionality-map.md:85`, `functionality-map.md:86`, `functionality-map.md:87`, `functionality-map.md:88`, `functionality-map.md:90`, `fitbod/Periodization/BlockOverviewScreen.swift:304`, `fitbod/Periodization/BlockOverviewScreen.swift:308`, `fitbod/Periodization/BlockOverviewScreen.swift:309`, `fitbod/Periodization/BlockOverviewScreen.swift:312`, `fitbod/Periodization/BlockOverviewScreen.swift:1629`, `fitbod/Periodization/BlockReviewView.swift:49`.
Severity: fix soon.

### 5. **The test inventory's claimed counts are not the source's counts**

Trigger: The implementer follows the re-check lists to find all Program card-label consumers and BlockBuilderView source readers.
Mechanism: Seven UI suites match Program's status-bearing card labels rather than five, while four suites actually read BlockBuilderView.swift rather than six because the two BRU audit suites explicitly retired those reads.
Blast radius: The plan overstates completed dependency checking and carries obsolete copy-test obligations; preserving labels also does not preserve tests that expect completed cards on the Program root after those cards move to Past.
Smallest fix: Correct the counts, list actual readers, and call out the existing root-level DONE-card lookups when updating the already-named journeys.
Evidence: `review-log.md:58`, `review-log.md:155`, `plan.md:21`, `plan.md:38`, `fitbodUITests/ArchiveRoutineUITests.swift:140`, `fitbodUITests/BlockDraftKeepsOnCancelUITests.swift:54`, `fitbodUITests/BlockLifecycleJourneyUITests.swift:45`, `fitbodUITests/BlockReviewAfterEndUITests.swift:60`, `fitbodTests/BRUPeriodizationAuditTests.swift:224`, `fitbodTests/BRUPeriodizationRegressionTests.swift:322`.
Severity: fix soon.

### 6. **The current-state description treats an unacknowledged review as one-time**

Trigger: The lifter dismisses the current review without choosing Start next block, then returns to Today.
Mechanism: The audit and map say the review opens once, but main recomputes pendingReviewBlocks on appearance and dismissal does not acknowledge it.
Blast radius: The baseline hides the repeated-presentation behavior that v3's new acknowledgement path is intended to fix.
Smallest fix: Describe automatic presentation as repeating until acknowledged and retain the proposed dismissal acknowledgement as the behavior change.
Evidence: `audit.md:43`, `functionality-map.md:51`, `fitbod/Views/TodayView.swift:309`, `fitbod/Views/TodayView.swift:374`, `fitbod/Periodization/BlockReviewView.swift:349`, `fitbod/Periodization/BlockReviewView.swift:355`, `fitbod/Periodization/BlockReviewView.swift:630`, `docs/design-map/workflows/today.md:108`, `plan.md:33`.
Severity: fix soon.

### 7. **The reused completed-workout seed is not reliably a completed-today fixture**

Trigger: The empty-workout seed launches during the first thirty minutes of a calendar day.
Mechanism: Its nonempty completed workout starts thirty minutes before now, while v3 defines DONE using startedAt within the current day.
Blast radius: The promised no-block DONE acceptance fixture becomes yesterday's workout and can select a different Today state.
Smallest fix: Make this fixture's clock explicit or seed a completed nonempty workout inside the injected current day; do not treat the existing relative-time seed as unconditional proof of DONE.
Evidence: `plan.md:19`, `hierarchy.md:54`, `fitbod/App/DemoWorkoutSeed.swift:69`, `fitbod/App/DemoWorkoutSeed.swift:135`, `fitbod/App/DemoWorkoutSeed.swift:138`.
Severity: fix soon.

### 8. **The plan preserves WeekTickerCells for a caller that does not use it**

Trigger: Step 1.1 deletes BlockContextBand and decides which components remain for Block overview.
Mechanism: The plan and map say WeekTickerCells stays for Block overview, but its production caller is BlockContextBand and Block overview uses a separate week carousel.
Blast radius: Cleanup retains a newly unused component and the source inventory misidentifies the overview implementation.
Smallest fix: Remove the claimed overview dependency and decide whether to delete WeekTickerCells and its previews with the band.
Evidence: `plan.md:17`, `functionality-map.md:25`, `fitbod/Views/BlockContextBand.swift:139`, `fitbod/Views/WeekTickerCells.swift:92`, `fitbod/Periodization/BlockOverviewScreen.swift:583`.
Severity: fix soon.

### 9. **The audit still mixes captured evidence, current code and unsupported absolutes**

Trigger: A reader treats A-03, A-04, A-21 and A-22 as verified descriptions of the current app.
Mechanism: The streak algorithm accepts yesterday as the start of a continuing streak, the orange MRV legend adds another signal use, the scheduled deload banner precedes the advisory, and the plan-complete capture still shows W1 / 4 and DAY 08 / 28 while main has since changed those labels.
Blast radius: These baseline errors weaken the evidence for the redesign and can turn screenshot comparisons into false regressions.
Smallest fix: Correct the rest-day statement and banner order, avoid an exact accent count unless all visible uses are counted, and separate the captured plan-complete state from the current-source fix as A-01 already does.
Evidence: `audit.md:16`, `audit.md:17`, `audit.md:62`, `audit.md:70`, `fitbod/Views/TodayView.swift:472`, `fitbod/Views/TodayView.swift:102`, `fitbod/Views/TodayView.swift:108`, `fitbod/Fatigue/FatigueSurfaceView.swift:238`, `fitbod/Views/TodayStatStrip.swift:183`, `docs/design-map/screens/img/17e-default-light-today--plan-complete.png`.
Severity: fix soon.

## Capability inventory gaps and current-column corrections

The following reachable capabilities have no explicit row describing their behavior, even though the map promises hidden, dead and unwired capabilities and separate side effects (`functionality-map.md:3`, `functionality-map.md:6`, `functionality-map.md:7`).
A navigation-destination row preserves reachability but does not identify the mutations or known failure paths below.

| Missing capability or grouped behavior | Source evidence |
|---|---|
| Routine rename, edit mode, arrow and drag reordering, removal confirmation, save-error reporting, live-edit banner, Used in display, archive eligibility and confirmation, and dismissal of a routine archived from another tab. | `fitbod/Periodization/SplitDetailView.swift:143`; `fitbod/Periodization/SplitDetailView.swift:148`; `fitbod/Periodization/SplitDetailView.swift:168`; `fitbod/Periodization/SplitDetailView.swift:187`; `fitbod/Periodization/SplitDetailView.swift:192`; `fitbod/Periodization/SplitDetailView.swift:198`; `fitbod/Periodization/SplitDetailView.swift:239`; `fitbod/Periodization/SplitDetailView.swift:366`; `fitbod/Periodization/SplitDetailView.swift:452`; `fitbod/Periodization/SplitDetailView.swift:534`; `docs/design-map/workflows/build-a-routine.md:23` |
| Add existing session, create and automatically attach a new session, and permit another slot for an already-slotted template. | `fitbod/Periodization/SplitDetailView.swift:780`; `fitbod/Periodization/SplitDetailView.swift:795`; `fitbod/Periodization/SplitDetailView.swift:816`; `fitbod/Periodization/SplitDetailView.swift:855`; `fitbod/Periodization/SplitDetailView.swift:869` |
| Archived-routine restore, empty state and save-failure rollback. | `fitbod/Periodization/ArchivedRoutinesView.swift:65`; `fitbod/Periodization/ArchivedRoutinesView.swift:83`; `fitbod/Periodization/ArchivedRoutinesView.swift:92`; `docs/design-map/workflows/build-a-routine.md:41` |
| Builder phase replacement confirmation, duration and volume/intensity editing, add/delete/reorder phase, undo deletion, attach/swap routine, weekday selection, Save Draft versus Save Ready/Changes, and dirty dismissal confirmation. | `fitbod/Periodization/BlockBuilderView.swift:161`; `fitbod/Periodization/BlockBuilderView.swift:185`; `fitbod/Periodization/BlockBuilderView.swift:203`; `fitbod/Periodization/BlockBuilderView.swift:1837`; `fitbod/Periodization/BlockBuilderView.swift:2013`; `fitbod/Periodization/BlockBuilderView.swift:2583`; `fitbod/Periodization/BlockBuilderView.swift:2642`; `fitbod/Periodization/BlockBuilderView.swift:2924`; `fitbod/Periodization/BlockBuilderView.swift:3033`; `docs/design-map/workflows/run-a-block.md:22` |
| Overview header EDIT, routine SWAP for draft/ready, scheduling-mode and weekday changes, mismatch hint, week-carousel selection/day states, phase status and progression, fatigue strip, and missing versus unreadable archive states. | `fitbod/Periodization/BlockOverviewScreen.swift:288`; `fitbod/Periodization/BlockOverviewScreen.swift:296`; `fitbod/Periodization/BlockOverviewScreen.swift:944`; `fitbod/Periodization/BlockOverviewScreen.swift:982`; `fitbod/Periodization/BlockOverviewScreen.swift:1021`; `fitbod/Periodization/BlockOverviewScreen.swift:1040`; `fitbod/Periodization/BlockOverviewScreen.swift:1124`; `fitbod/Periodization/BlockOverviewScreen.swift:1160`; `fitbod/Periodization/BlockOverviewScreen.swift:1169` |
| Review statistics, e1RM movement/empty state, recommendation, acknowledgement error and inert EXPORT. | `fitbod/Periodization/BlockReviewView.swift:49`; `fitbod/Periodization/BlockReviewView.swift:57`; `fitbod/Periodization/BlockReviewView.swift:86`; `fitbod/Periodization/BlockReviewView.swift:215`; `fitbod/Periodization/BlockReviewView.swift:299` |
| Muscle-detail totals and delta, contributing exercises, frequency, in-place target editing, missing-target creation, ordered-target validation and reset to RP defaults. | `fitbod/Fatigue/PerMuscleDetailView.swift:134`; `fitbod/Fatigue/PerMuscleDetailView.swift:172`; `fitbod/Fatigue/PerMuscleDetailView.swift:205`; `fitbod/Fatigue/PerMuscleDetailView.swift:227`; `fitbod/Fatigue/MuscleVolumeTargetStepper.swift:113`; `fitbod/Fatigue/MuscleVolumeTargetStepper.swift:122`; `docs/design-map/workflows/check-progress.md:30` |
| Recap metric grid, workout/routine counts, muscles hit, PRs, under-target muscles, progress deltas, recent note and dismissal-only Start W action. | `fitbod/Fatigue/WeeklyRecapSheet.swift:161`; `fitbod/Fatigue/WeeklyRecapSheet.swift:420`; `fitbod/Fatigue/WeeklyRecapSheet.swift:447`; `fitbod/Fatigue/WeeklyRecapSheet.swift:484`; `fitbod/Fatigue/WeeklyRecapSheet.swift:526`; `fitbod/Fatigue/WeeklyRecapSheet.swift:565`; `fitbod/Fatigue/WeeklyRecapSheet.swift:610`; `fitbod/Fatigue/WeeklyRecapSheet.swift:631` |
| Fatigue-signal breakdown and dismissal, distinct from the notice's eligibility and weekly dismissal. | `fitbod/Fatigue/DeloadSignalDetailSheet.swift:53`; `fitbod/Fatigue/DeloadSignalDetailSheet.swift:59`; `fitbod/Fatigue/DeloadSignalDetailSheet.swift:105` |

Current-column error confirmed: the automatic review is not once-only until acknowledged, as finding 6 explains (`functionality-map.md:51`).
The volume empty-state row gives a necessary condition only: the complete test also excludes muscles with at least one rounded set, so a muscle without a positive MEV can still appear when it has volume (`functionality-map.md:49`, `fitbod/Fatigue/FatigueSurfaceView.swift:106`).
The row's dismissal glyph is typographically inaccurate: the banner uses ✕, not × (`functionality-map.md:16`, `fitbod/Fatigue/DeloadAdvisoryBanner.swift:80`).

All eleven workflow files were checked for their entry, action and exit paths.
Settings, backup/export, plate management, logger controls, workout-history editing limitations, Library and exercise-progress internals are outside the named changes and were treated as unchanged child workflows, not new redesign requirements (`index.md:31`, `functionality-map.md:13`, `functionality-map.md:54`, `functionality-map.md:97`, `docs/design-map/workflows/settings-units-backup-restore-export.md:16`, `docs/design-map/workflows/plates-and-the-calculator.md:16`, `docs/design-map/workflows/log-a-workout.md:16`, `docs/design-map/workflows/review-a-workout-and-edit-history.md:25`, `docs/design-map/workflows/find-and-create-exercises.md:16`).
Session prescription and superset editing remain reachable through the retained routine/session path; a grouped unchanged-child row would make this boundary explicit without expanding the build (`functionality-map.md:40`, `docs/design-map/workflows/build-a-session-and-its-prescription.md:20`, `docs/design-map/workflows/build-a-session-and-its-prescription.md:50`).
The workflow documents contain historical failures, so they were used as coverage inputs rather than substituted for current source behavior (`docs/design-map/workflows/build-a-routine.md:99`, `fitbod/Periodization/SplitDetailView.swift:516`).

## Ten review-log closure checks

| Claim | Result against the leaves | Evidence |
|---|---|---|
| B-1, pending review acknowledgement and reachability | Closed in the proposal: persistent notice, dismissal acknowledgement and recap independence are explicitly assigned. | `review-log.md:90`; `hierarchy.md:64`; `plan.md:33` |
| B-2, alternate starts and DONE semantics | Closed for Today: slot forwarding and finished-today precedence are specified; Program's new start path still needs the cases in finding 2. | `review-log.md:91`; `today-layouts.md:322`; `hierarchy.md:45`; `hierarchy.md:54`; `plan.md:19`; `plan.md:35` |
| B-3, nonexistent updatedAt fields | Closed: the leaves use session-template recency and the real saved Block date, without a schema addition. | `review-log.md:92`; `today-layouts.md:234`; `today-layouts.md:235`; `program-layouts.md:59`; `open-decisions.md:22` |
| B-4, empty sessions | Partial: Today has T-FIX and the picker disables empties, but Program's new start row does not specify the equivalent case. | `review-log.md:93`; `hierarchy.md:47`; `today-layouts.md:326`; `program-layouts.md:80`; `plan.md:35` |
| B-5, guardrails and test inventory | Partial: CREATE BLOCK and the sheet declarations stay in ProgramView, and today.root replaces the old root cue; the factual inventory errors in finding 5 remain and the exhaustive test cross-check is not yet complete. | `review-log.md:94`; `plan.md:9`; `plan.md:17`; `plan.md:21`; `program-layouts.md:199` |
| B2-1, duplicate slot selection | Closed in the leaves: each template appears once and selection prefers the resolver slot, then the first slot after the anchor with wraparound. | `review-log.md:20`; `today-layouts.md:320`; `today-layouts.md:322`; `today-layouts.md:325`; `plan.md:19` |
| B2-2, saved date versus planned start | Closed in the leaves: Saved copy and oldest-saved ordering replace a nonexistent planned date, which is explicitly outside the schema. | `review-log.md:21`; `program-layouts.md:59`; `program-layouts.md:104`; `open-decisions.md:22` |
| F2-1, Program accessibility-label consumers | Partial: the label contract is retained and all seven known suites are named somewhere in the step, but the claimed five-suite inventory and root-versus-Past behavior need correction. | `review-log.md:27`; `plan.md:21`; finding 5 |
| F2-9, this-week count and reload keys | Closed in the written plan: only counted finished workouts contribute working sets and task inputs include those IDs and the week boundary; runtime behavior remains unverified. | `review-log.md:35`; `plan.md:20` |
| F2-11, missing seeds | Partial: three distinct fixtures are requested and the existing fixtures broadly match their scenarios, but the completed-today reuse has the boundary failure in finding 7 and truncation evidence is unverified. | `review-log.md:37`; `plan.md:19`; `fitbod/App/BlockStatesSeed.swift:113`; `fitbod/App/ActiveBlockSeed.swift:75`; `fitbod/App/PowerbuildingSeed.swift:45`; finding 7 |

## Audit spot checks already completed

| Audit row | Result | Evidence |
|---|---|---|
| A-01 | The captured zero-state strip and compact phase copy support the stated baseline. | `audit.md:14`; `fitbod/Views/TodayView.swift:472`; `docs/design-map/screens/img/17e-default-light-today.png` |
| A-02 | DAY 01 / 28 appears in the cited default capture; the scheduled capture has a different plan denominator. | `audit.md:15`; `docs/design-map/screens/img/17e-default-light-today.png`; `docs/design-map/screens/img/17e-default-light-today--scheduled.png` |
| A-04 | The named orange uses exist, but an exact total of four undercounts the visible orange MRV legend, with further orange values in the scheduled capture. | `audit.md:17`; `fitbod/Fatigue/FatigueSurfaceView.swift:238`; `docs/design-map/screens/img/17e-default-light-today.png` |
| A-06 | DAY 01 / 28 is supported by the default capture; it is state-specific rather than universal copy. | `audit.md:19`; `docs/design-map/screens/img/17e-default-light-today.png` |
| A-14 | Seeded MEV targets make zero-volume muscle rows visible; no-target alone is insufficient to prove the empty state when logged volume exists. | `audit.md:41`; `fitbod/Fatigue/FatigueSurfaceView.swift:106`; `fitbod/Fatigue/FatigueSurfaceView.swift:175` |
| A-26 | The captured plural is stale relative to the current singular-capable count component; v3 records that distinction. | `audit.md:81`; `fitbod/Periodization/ProgramView.swift:650`; `docs/design-map/screens/img/17e-default-light-program.png` |

The remaining audit rows were checked for factual source predicates, rather than adopting their experience judgments.
A-03 needs the streak correction in finding 9; its population claim that most lifters see 0 or 1 was not established by the code (`audit.md:16`, `fitbod/Views/TodayView.swift:482`).
A-05 correctly describes the band as a gesture rather than a native Button (`audit.md:18`, `fitbod/Views/BlockContextBand.swift:154`).
A-07 through A-09 match the current list, picker gate and resolver-driven hero; A-10 through A-12 match the volume surface's content (`audit.md:20`, `audit.md:21`, `audit.md:22`, `fitbod/Views/TodayView.swift:158`, `fitbod/Views/TodayView.swift:194`, `fitbod/Views/TodayView.swift:211`, `fitbod/Fatigue/FatigueSurfaceView.swift:171`).
A-15, A-17 through A-20 and A-23 through A-28 match the source affordances, with the one-active-block constraint still applying to A-23's ambiguous phrase two live blocks (`audit.md:42`, `audit.md:44`, `audit.md:45`, `audit.md:53`, `audit.md:61`, `audit.md:78`, `fitbod/Views/TodayView.swift:205`, `fitbod/Views/TodaySessionPicker.swift:96`, `fitbod/Periodization/ProgramView.swift:394`, `fitbod/Periodization/ProgramView.swift:621`).
A-29 needs the qualification same status and same displayed week/phase as well as same name, because those values distinguish cards (`audit.md:84`, `fitbod/Periodization/ProgramView.swift:588`, `fitbod/Periodization/ProgramView.swift:631`).
A-30 through A-32 match the empty hero, resume placement and context-menu discard (`audit.md:92`, `audit.md:93`, `audit.md:94`, `fitbod/Periodization/ProgramView.swift:141`, `fitbod/Periodization/ProgramView.swift:973`, `fitbod/Periodization/ProgramView.swift:982`, `fitbod/Sessions/ResumeWorkoutBanner.swift:106`).
Unverified: A-01's five-second-test conclusion, A-10's four-screen length, A-13's exact interactive hit area and all assertions about what lifters notice or feel were not measured in this coverage review (`audit.md:14`, `audit.md:30`, `audit.md:33`).

## Not reached

- Exhaustive per-step test dependency inventory, including the unnamed factory and Progress suites and navigation assumptions after completed cards move to Past.
- Every statement in both source re-check lists, including glyph spelling, backup acknowledgement writes, logger dismissal and legacy caller claims.
- Full new-seed uniqueness audit across every DEBUG seed body and all acceptance claims for the three reused fixtures.
- Exhaustive comparison of every layout default with open-decisions.md.
- Runtime compilation, simulator execution and rendered truncation or layout acceptance, which this read-only review does not run.

## Checked and correct

- SchemaV7 field reuse
- Duplicate-slot rule
- Saved-date semantics
- Today DONE precedence
- CREATE BLOCK sheet ownership
- Today volume navigation destinations
- Two LIVE BLOCK UI-suite references
- Seven today.sessions UI-suite references
- Working-set-only display helper
- Guarded review acknowledgement proposal
