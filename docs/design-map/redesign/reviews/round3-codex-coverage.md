# Round 3 coverage and factual accuracy review

Draft v4 verdict: not final, 1 blocker and 6 fix-soon findings.
The remaining coverage checks are complete, but the new no-block states require inputs absent from the specified TodayState contract; the remaining findings concern test inventory, fixture chronology and contradictory or missing decision records.
The saved draft v3 review below is historical; the current findings and evidence are under Draft v4 pass.

Draft v3 saved verdict: not final, 2 blockers.
Draft v3 still omits an existing alternate-workout path in two repair states and leaves the new Program start controls without a complete state contract.
The capability inventory and audit fact checks below are the saved v3 checks; the remaining spec items were completed against v4 below.

Repository paths are relative to `/Users/chrissaechao/Desktop/fitbod`.
Proposal paths are relative to `docs/design-map/redesign/`.
This review concerns coverage and factual accuracy, not visual preference.
The saved v3 review used HEAD `64f7d7a0`; comparison with `0ef702ea` found no changes under fitbod, fitbodTests or fitbodUITests, or in CLAUDE.md or docs/DEVELOPMENT.md.
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

No requested static-review item remains unchecked.
Runtime compilation, simulator execution and rendered truncation or layout acceptance remain unverified because this review prohibits builds and tests; these are implementation acceptance tasks, not unfinished static-review items.

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

## Draft v4 pass

Verdict: not final, 1 blocker and 6 fix-soon findings.
Status: test dependencies, both source re-check lists, seed uniqueness and reuse, and the layout-default comparison are complete.
The two saved v3 blockers are closed at proposal level by `hierarchy.md:47`, `hierarchy.md:48`, `plan.md:35` and `program-layouts.md:77`.
The v3 section above is retained as requested; its proposal citations refer to draft v3 at commit `12ea884a`, while citations in this section refer to draft v4 at `e403d287`.
No app or test source differs from the spec's `0ef702ea` baseline.
Correction to the saved v3 report: its `BlockDraftKeepsOnCancelUITests` and `BlockLifecycleJourneyUITests` citations should read `BlockDraftKeepsUITests` and `BlockLifecycleEntryPointsUITests`; the former names do not exist (`review-log.md:77`, `fitbodUITests/BlockDraftKeepsUITests.swift:54`, `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:45`).

### Blockers

#### V4-B1. **The new no-block states cannot be distinguished by the specified TodayState inputs**

Trigger: Compare three stores with no block, workout history or pending review: a fresh store, one live routine with no sessions, and one usable standalone session with no routine.
Mechanism: Step 1.1 passes only routines with non-empty sessions and lists no standalone-template query or input, so those three stores produce the same specified inputs while hierarchy requires T-FIRST, T-FIX and T-PICK respectively.
Blast radius: Today cannot choose the required onboarding, repair or workout action from the advertised pure-function contract, and Program's instruction to reuse that contract carries the omission forward.
Smallest fix: Pass all live routine summaries, including empty routines, plus eligible standalone templates from a flat SessionTemplate query with membership filtered in Swift; update the explicit input list and the three no-history fixtures in TodayStateTests, then reuse those inputs in Program.
Evidence: `plan.md:17`, `plan.md:19`, `plan.md:35`, `hierarchy.md:47`, `hierarchy.md:51`, `hierarchy.md:52`, `hierarchy.md:62`, `fitbod/Views/TodayView.swift:46`, `fitbod/Views/TodayView.swift:56`, `fitbod/Views/TodaySessionPicker.swift:37`, `fitbod/Views/TodaySessionPicker.swift:43`, `fitbod/Models/SessionTemplate.swift:48`, `fitbod/Models/SessionTemplate.swift:57`.
Severity: blocks finalization.

### Fix soon

#### V4-F6. **Summary rows still contradict the repaired no-block behavior**

Trigger: An implementer uses the hierarchy's zone table or the review-notice leaf to build a no-block advisory or no-block T-FIX screen.
Mechanism: The zone table still restricts the advisory to an active block, the review-notice leaf omits T-FIX from its state list, and T-FIX's state-table row includes volume although its no-block layout explicitly excludes it.
Blast radius: Following different canonical leaves can suppress an eligible advisory or pending review, or add a volume row that the no-block repair layout excludes.
Smallest fix: Align the zone summary with the advisory eligibility table, add no-block T-FIX to the review-notice list, and qualify the T-FIX volume entry by block presence.
Evidence: `hierarchy.md:19`, `hierarchy.md:47`, `hierarchy.md:68`, `today-layouts.md:220`, `today-layouts.md:321`, `plan.md:33`, `fitbod/Views/TodayView.swift:684`.
Severity: fix soon.

#### V4-F4. **The decision register omits behavioral defaults and still includes an excluded destination**

Trigger: Product or implementation work treats open-decisions.md as the register of the defaults the layouts assume.
Mechanism: No O-row records the suggestion and repair-selection policies, the drafts-only selection, the differing session-sheet tap behavior, the shared discard confirmation rule, or the review-versus-advice priority; O-4 additionally includes Progress Recaps although the plan and evaluation explicitly exclude it.
Blast radius: Several behavior choices have rationale only in leaves or tradeoffs, while the register implies a navigable Recaps destination that this bundle does not deliver.
Smallest fix: Add O-rows or explicit links to accepted decisions for the missing defaults in the inventory below, extend O-3/O-5/O-14 with their precedence and acknowledgement qualifications, and mark Progress Recaps deferred in O-4.
Evidence: `open-decisions.md:4`, `open-decisions.md:10`, `open-decisions.md:12`, `open-decisions.md:13`, `open-decisions.md:14`, `open-decisions.md:22`, `today-layouts.md:248`, `today-layouts.md:320`, `today-layouts.md:353`, `today-layouts.md:354`, `program-layouts.md:130`, `program-layouts.md:206`, `hierarchy.md:71`, `plan.md:54`, `evaluation.md:58`.
Severity: fix soon.

#### V4-F1. **The remaining test inventory mixes unnamed dependencies with irrelevant matches**

Trigger: An implementer follows the per-step test lists when extracting the set-count rule, moving volume, or guarding acknowledgement.
Mechanism: Step 2.1 omits BlockReviewMathTests, which calls acknowledge and reads its source file, while steps 1.2 and 1.4 use generic factory and Progress-suite descriptions instead of names; other entries are comment or wrong-screen matches.
Blast radius: The persistence assertion protecting reviewedAt and the existing count/warm-up tests can be missed, while unrelated suites appear to be affected by the redesign.
Smallest fix: Name BlockReviewMathTests in 2.1, expand the factory and Progress shorthands with the concrete suites below, and label or remove irrelevant matches without adding new copy-pinning tests.
Evidence: `plan.md:18`, `plan.md:19`, `plan.md:20`, `plan.md:21`, `plan.md:33`, `fitbodTests/BlockReviewMathTests.swift:226`, `fitbodTests/BlockReviewMathTests.swift:240`, `fitbodTests/Phase6/BRU/BRUGrepAuditPhase6Tests.swift:52`, `docs/DEVELOPMENT.md:63`.
Severity: fix soon.

#### V4-F3. **The midnight seed correction leaves future completion timestamps**

Trigger: The reused empty-workout fixture launches at 00:05 after applying v4's proposed start clamp.
Mechanism: The nonempty workout starts at midnight but finishPushA still sets completedAt to start plus ten minutes and derives completed-set times from start, so a workout described as already finished can finish in the future.
Blast radius: The acceptance fixture reaches DONE through impossible chronology and cannot validate the same day-boundary behavior as a real finished workout.
Smallest fix: Bound the workout end and completed-set timestamps by the injected now, derive duration from those bounds, and clamp only this fixture rather than changing the older-workout fixtures that share seedFinished.
Evidence: `plan.md:19`, `risks.md:27`, `fitbod/App/DemoWorkoutSeed.swift:70`, `fitbod/App/DemoWorkoutSeed.swift:141`, `fitbod/App/DemoWorkoutSeed.swift:290`, `fitbod/App/DemoWorkoutSeed.swift:297`.
Severity: fix soon.

#### V4-F5. **The drafts-only rationale mistakes creation order for edit recency**

Trigger: A lifter creates drafts A then B, then returns to edit A while both remain drafts.
Mechanism: The leaf selects the newest-created draft but justifies it as the draft touched last; BlockDraft preserves startDate during editing, so B still leads although A was touched last.
Blast radius: The promised reason for Program's leading draft is false, and an implementer trying to honor both statements would need an edit-recency input the proposed stored-field contract does not provide.
Smallest fix: Keep the explicit newest-created rule and rewrite its rationale as creation order, with deterministic ties; defer any last-edited behavior as a separate decision rather than implying startDate provides it.
Evidence: `program-layouts.md:130`, `program-layouts.md:149`, `tradeoffs.md:46`, `tradeoffs.md:63`, `fitbod/Periodization/BlockDraft.swift:19`, `fitbod/Periodization/BlockDraft.swift:80`, `fitbod/Periodization/BlockDraft.swift:151`.
Severity: fix soon.

#### V4-F2. **The source re-check still reports comments and source strings as executable callers**

Trigger: A maintainer uses the verified-caller claims to scope cleanup or constructor compatibility.
Mechanism: SessionTemplate mentions RoutineDuplicator only in comments, RoutinesListView has two preview constructions despite the plan's only-comments wording, and only two suites construct BlockReviewView while the third checks an initializer-shaped source string.
Blast radius: The stated dependency inventory is inaccurate even though keeping RoutineDuplicator is still correct because RoutineBuilderView calls it.
Smallest fix: Say production caller when excluding previews, remove SessionTemplate from the executable caller list, and describe BlockReviewTriggerTests as a source-wiring assertion rather than a constructor consumer.
Evidence: `review-log.md:251`, `plan.md:45`, `plan.md:33`, `fitbod/Models/SessionTemplate.swift:19`, `fitbod/Models/SessionTemplate.swift:51`, `fitbod/Routines/RoutineBuilderView.swift:588`, `fitbod/Routines/RoutinesListView.swift:495`, `fitbod/Routines/RoutinesListView.swift:512`, `fitbodTests/BlockReviewTriggerTests.swift:199`, `fitbodTests/BlockReviewPRMarkTests.swift:124`, `fitbodTests/BlockReviewHeroLayoutTests.swift:105`.
Severity: fix soon.

### Completed item: test dependencies

The requested strings and removed symbols were searched in both test targets, and source-reader hits were distinguished from comments, exclusions and similarly named controls on other screens.

| Step | Dependency result and smallest inventory correction | Evidence |
|---|---|---|
| 1.1 | All seven today.sessions suites and both LIVE BLOCK suites are named; the block name remains a separate label or gains a replacement identifier. | `plan.md:17`; `fitbodUITests/EmptyWorkoutCountsUITests.swift:93`; `fitbodUITests/ReseedRelaunchUITests.swift:68`; `fitbodUITests/SkipWarmupsUITests.swift:73`; `fitbodUITests/SwipeBackUITests.swift:44`; `fitbodUITests/WeeklyRecapUITests.swift:51`; `fitbodUITests/WorkoutLoggerJourneyUITests.swift:101`; `fitbodUITests/WorkoutSwapJourneyUITests.swift:41`; `fitbodUITests/ArchiveRoutineUITests.swift:116`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:101` |
| 1.2 | Name SessionFactoryTests, SessionFactoryPhase3Tests, DeloadVolumeApplicationTests and WarmupDeloadIntegrationTests under the factory shorthand because they already assert the set-count and ramp behavior being separated. | `plan.md:18`; `fitbodTests/SessionFactoryTests.swift:220`; `fitbodTests/SessionFactoryPhase3Tests.swift:116`; `fitbodTests/DeloadVolumeApplicationTests.swift:90`; `fitbodTests/DeloadVolumeApplicationTests.swift:110`; `fitbodTests/WarmupDeloadIntegrationTests.swift:126` |
| 1.3 | The removed StartBlockCTA readers and both UI entry consumers are named; SuggestedActionTests' No active block match concerns PlateauDetector, not Today copy, and no test directly constructs SessionTemplateDetailView(template:) in either target. | `plan.md:19`; `fitbodTests/TodayViewBlockStackingTests.swift:67`; `fitbodUITests/NewBlockSavesUITests.swift:101`; `fitbodUITests/EditorSwipeDismissUITests.swift:135`; `fitbodTests/Fatigue/SuggestedActionTests.swift:246`; `fitbodTests/Fatigue/SuggestedActionTests.swift:249` |
| 1.4 | Expand the Progress-home shorthand to BRUGrepAuditPhase6Tests, which actually reads ProgressHomeView.swift; the other named volume and Today-source suites are accounted for. | `plan.md:20`; `fitbodTests/Phase6/BRU/BRUGrepAuditPhase6Tests.swift:52`; `fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift:79`; `fitbodTests/TodayViewBRUCopyTests.swift:193` |
| 1.5 | All seven card-label suites and all five root-level DONE lookups are now identified; they need the Past-list navigation change as v4 says. | `plan.md:21`; `fitbodUITests/BlockOverviewStatesUITests.swift:85`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:45`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:58`; `fitbodUITests/ArchiveRoutineUITests.swift:140`; `fitbodUITests/BlockReviewAfterEndUITests.swift:60`; `fitbodUITests/BlockDraftKeepsUITests.swift:54`; `fitbodUITests/NewBlockSavesUITests.swift:159`; `fitbodUITests/BlockWeekCountsUITests.swift:92` |
| 1.5 | BRUPeriodizationRegressionTests reads RoutinesListView for No blocks yet, and ExerciseHistoryRowsUITests taps Library's View all history, not Program's ALL HISTORY or + NEW; these do not establish Program dependencies. | `plan.md:21`; `fitbodTests/BRUPeriodizationRegressionTests.swift:269`; `fitbodTests/BRUPeriodizationRegressionTests.swift:277`; `fitbodUITests/ExerciseHistoryRowsUITests.swift:64`; `fitbodUITests/ExerciseHistoryRowsUITests.swift:68` |
| 1.6 | RoutinesListCopyTests is the actual reader pinning Discard active workout; the rg found no UI assertion for that title, and BlockLifecycleEntryPointsUITests does not exercise banner long-press discard. | `plan.md:22`; `fitbodTests/RoutinesListCopyTests.swift:99`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:26`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:65` |
| 2.1 | Add BlockReviewMathTests, and optionally list the existing BlockReviewView source scans beside the named constructor tests rather than claiming constructors cover those readers. | `plan.md:33`; `fitbodTests/BlockReviewMathTests.swift:226`; `fitbodTests/BRUPeriodizationAuditTests.swift:229`; `fitbodTests/BRUPeriodizationRegressionTests.swift:324`; `fitbodTests/BlockReviewPRMarkTests.swift:124`; `fitbodTests/BlockReviewHeroLayoutTests.swift:105` |
| 2.2 | The nextTrainingDay caller suite is BlockOverviewStatesTests, already named; expand the resolver shorthand to TodayResolverTests rather than leaving a future search. | `plan.md:34`; `fitbodTests/BlockOverviewStatesTests.swift:65`; `fitbodTests/BlockOverviewStatesTests.swift:75`; `fitbodTests/TodayResolverTests.swift:99` |
| 2.3 and 2.4 | No existing ThisWeekSection exists; the new state cases and the relevant overview tests are named, and Program edits inherit the three source readers from the plan's global rule. | `plan.md:9`; `plan.md:35`; `plan.md:36` |
| 2.5 and 2.6 | The volume source reader is named, and four actual BlockBuilderView readers replace the incorrect six-suite claim; the retired BRU audit entries are comments. | `plan.md:37`; `plan.md:38`; `fitbodTests/NewBlockBuilderFidelityTests.swift:74`; `fitbodTests/BlockBuilderViewCopyTests.swift:22`; `fitbodTests/NewBlockProgressionChartTests.swift:66`; `fitbodTests/AdaptiveColorSourceTests.swift:29`; `fitbodTests/BRUPeriodizationAuditTests.swift:224`; `fitbodTests/BRUPeriodizationRegressionTests.swift:322` |
| 3.2 and 3.3 | Named legacy-view and folder readers cover the symbol/file references found by the search; views used only in previews are not production callers. | `plan.md:45`; `plan.md:46`; `fitbodTests/BlocksSectionTests.swift:50`; `fitbodTests/BRUPeriodizationRegressionTests.swift:325`; `fitbodTests/BRUPeriodizationRegressionTests.swift:328` |

The shared UI label helper is case-insensitive, so changing visible + NEW to + New is not itself a selector break (`fitbodUITests/UITestNavigation.swift:537`).
The extra + New matches in MilestoneOneJourneyUITests and CustomExerciseEditorBRUUITests are Library actions, not omitted Program header consumers (`fitbodUITests/MilestoneOneJourneyUITests.swift:32`, `fitbodUITests/CustomExerciseEditorBRUUITests.swift:53`).
No build or test was run; this is a dependency inventory, not evidence that the proposed implementation passes.

### Completed item: source re-check lists

Both original lists and the new round-3 list were checked against source, with seed-specific claims assigned to the next checkpoint rather than inferred from one fixture.

| Review-log entry | Result and source evidence |
|---|---|
| Round 2, line 145: attach visibility | Correct: draft/ready only, `fitbod/Periodization/BlockOverviewScreen.swift:301`. |
| Round 2, line 146: unguarded acknowledgement and restore | Correct: `fitbod/Periodization/BlockReviewView.swift:654`; `fitbod/Backup/BackupRestorer.swift:440`. |
| Round 2, line 147: draft date, save and start overwrite | Correct for an unstarted block: `fitbod/Periodization/BlockDraft.swift:19`; `fitbod/Periodization/BlockDraft.swift:80`; `fitbod/Periodization/BlockDraft.swift:151`; `fitbod/Periodization/BlockLifecycleService.swift:101`; no date binding occurs in BlockBuilderView. |
| Round 2, line 148: Today builder setters | Correct: `fitbod/Views/TodayView.swift:206`; `fitbod/Views/TodayView.swift:267`. |
| Round 2, line 149: warm-up subline and unused template flag | Correct: `fitbod/Views/LiftListRow.swift:50`; `fitbod/Views/LiftListRow.swift:55`; `fitbod/Sessions/SessionFactory.swift:256`; the factory has no generateWarmups read. |
| Round 2, line 150: estimate | Correct: `fitbod/Views/BlackSlabCTA.swift:58`. |
| Round 2, line 151: duplicate slots and groups | Correct: `fitbod/Periodization/SplitDetailView.swift:780`; `fitbod/Periodization/SplitDetailView.swift:869`; `fitbod/Views/TodaySessionPicker.swift:37`. |
| Round 2, line 152: glyphs | Correct: `docs/design-system/iconography.md:15`; `fitbod/Fatigue/DeloadAdvisoryBanner.swift:80`. |
| Round 2, line 153: card labels | Correct with the v4 seven-suite correction, as the test inventory above shows; `fitbod/Periodization/ProgramView.swift:631`. |
| Round 2, line 154: reused fixtures | Static fixture and rendering limitations are recorded in the seed checkpoint. |
| Round 1, line 233: reviewedAt writers and dead helper | Correct: `fitbod/Periodization/BlockReviewView.swift:349`; `fitbod/Periodization/BlockReviewView.swift:355`; `fitbod/Periodization/BlockReviewView.swift:407`; `fitbod/Backup/BackupRestorer.swift:440`. |
| Round 1, line 234: pending review | Correct, with the precise rule that the newest ended block must itself be unreviewed; older unreviewed blocks do not become pending after it is acknowledged: `fitbod/Periodization/BlockReviewView.swift:638`; `fitbodTests/BlockReviewTriggerTests.swift:128`. |
| Round 1, line 235: review stack and origin | Correct: `fitbod/Periodization/BlockReviewView.swift:44`; `fitbod/Periodization/BlockReviewView.swift:79`; `fitbod/Periodization/BlockBuilderView.swift:15`. |
| Round 1, line 236: resolver matching | Correct: `fitbod/Periodization/TodayResolver.swift:124`; `fitbod/Periodization/TodayResolver.swift:170`; `fitbod/Periodization/TodayResolver.swift:178`. |
| Round 1, line 237: current slot forwarding | Correct for production WorkoutStarter calls: `fitbod/Views/TodayView.swift:167`; `fitbod/Views/TodayView.swift:604`; `fitbod/Routines/SessionTemplateDetailView.swift:211`. |
| Round 1, line 238: calendar, recap and advisory | Correct: `fitbod/Views/TodayView.swift:531`; `fitbod/Views/TodayView.swift:644`; `fitbod/Views/TodayView.swift:684`; `fitbod/Fatigue/DeloadAdvisor.swift:130`. |
| Round 1, line 239: set counts and deload | Correct, with fixed warm-ups conditional on the flag: `fitbod/Views/BlackSlabCTA.swift:53`; `fitbod/Views/LiftListRow.swift:50`; `fitbod/Sessions/SessionFactory.swift:290`; `fitbod/Prescription/WarmupRamp.swift:57`. |
| Round 1, line 240: fatigue aggregation/access | Correct: `fitbod/Fatigue/FatigueModel.swift:128`; `fitbod/Fatigue/FatigueModel.swift:134`; `fitbod/Fatigue/FatigueModel.swift:276`; `fitbod/Fatigue/FatigueSurfaceView.swift:118`. |
| Round 1, line 241: stored dates | Correct: `fitbod/Models/Block.swift:58`; `fitbod/Models/Split.swift:25`; `fitbod/Models/SessionTemplate.swift:47`. |
| Round 1, line 242: lifecycle gates, calls and alert | Correct: `fitbod/Periodization/BlockLifecycleService.swift:149`; `fitbod/Periodization/BlockOverviewScreen.swift:301`; `fitbod/Periodization/BlockOverviewScreen.swift:339`; `fitbod/Periodization/BlockOverviewScreen.swift:1367`; `fitbod/Periodization/BlockOverviewScreen.swift:1401`; `fitbod/Models/SplitDeletionGuard.swift:42`. |
| Round 1, line 243: header signal defaults | Correct: `fitbod/Design/BRUHeaderBar.swift:56`; `fitbod/Design/BRUHeaderBar.swift:370`. |
| Round 1, line 244: seed uniqueness | A global absence cannot be inferred from BlockStatesSeed alone; all launchable fixtures are checked in the seed checkpoint. |
| Round 1, line 245: singular counts, plan end, date, volume and capture | Correct with positive MEV qualification: `fitbod/Design/BRUCountLabel.swift:18`; `fitbod/Views/TodayView.swift:591`; `fitbod/Views/TodayView.swift:456`; `fitbod/Fatigue/FatigueSurfaceView.swift:109`; the previously inspected default Today capture. |
| Round 1, line 246: logger exit/discard | Correct: `fitbod/Sessions/SessionLoggerView.swift:250`; `fitbod/Sessions/SessionLoggerView.swift:262`; `fitbod/Sessions/SessionLoggerView.swift:174`. |
| Round 1, line 247: route registration | Correct: `fitbod/Views/TodayView.swift:248`; `fitbod/Progress/ProgressHomeView.swift:125`. |
| Round 1, line 248: next-day helper | Correct: `fitbod/Periodization/BlockOverviewScreen.swift:463`; its existing tests are `fitbodTests/BlockOverviewStatesTests.swift:65`. |
| Round 1, line 249: legacy block callers | Correct for production code: `fitbod/Routines/RoutinesListView.swift:315`; `fitbod/Periodization/BlockPickerMenu.swift:64`; no production BlockCard construction was found. |
| Round 1, line 250: source-reader counts and CREATE BLOCK | Correct with the inline four-reader correction: `fitbodTests/NewBlockBuilderFidelityTests.swift:62`; `fitbodTests/NewBlockBuilderFidelityTests.swift:68`; `fitbodTests/ProgramViewFidelityTests.swift:233`; `fitbodTests/AdaptiveColorSourceTests.swift:29`. |
| Round 1, line 251: legacy list and duplicator | Incorrect as written for SessionTemplate and the unqualified no-caller assertion; see V4-F2. |
| Round 1, line 252: test-inventory claim | Incomplete and overinclusive; see V4-F1, including the resolved ExerciseHistoryRows question. |

The new round-3 list at `review-log.md:87` through `review-log.md:100` agrees with the same source checks, except that Plan custom is at `fitbod/Periodization/BlockReviewView.swift:349`, not the cited line 393, and only production callers should be inferred from the WeekTickerCells statement.
The round-3 date and seed claims are covered by the next checkpoint, and its five-versus-seven visible accent counts agree with the already inspected default and scheduled captures (`review-log.md:99`, `review-log.md:100`).
The historical review-log wording two live blocks cannot exist should mean two active blocks: draft and ready blocks are also called live by the actual deletion guard (`review-log.md:81`, `fitbod/Models/SplitDeletionGuard.swift:38`).

### Completed item: seed uniqueness and reuse

Scope assumption: each documented seed flag runs alone on a fresh store after successful catalog seeding, as the existing fixture comments require (`fitbod/App/RootView.swift:294`, `fitbod/App/RootView.swift:316`, `fitbod/App/PowerbuildingSeed.swift:24`, `fitbod/App/ActiveBlockSeed.swift:26`).
All eight launch-hook seed files in App and their branches were checked; the three requested states are not already deterministic standalone fixtures.

| Seed family | Relevant coverage and exclusion | Evidence |
|---|---|---|
| DemoWorkoutSeed | Normal mode leaves an open workout; empty-workout mode logs without a block; recap-with-plan creates its block after the old workout; the templates are populated when the catalog is available. | `fitbod/App/DemoWorkoutSeed.swift:70`; `fitbod/App/DemoWorkoutSeed.swift:80`; `fitbod/App/DemoWorkoutSeed.swift:119`; `fitbod/App/DemoWorkoutSeed.swift:234`; `fitbod/App/DemoWorkoutSeed.swift:251` |
| StalledExerciseSeed | Populated template, past completed workouts and an open workout, without a block. | `fitbod/App/StalledExerciseSeed.swift:57`; `fitbod/App/StalledExerciseSeed.swift:74`; `fitbod/App/StalledExerciseSeed.swift:103` |
| ProgressHistorySeed | Populated template and weekly history ending a week ago, without a block. | `fitbod/App/ProgressHistorySeed.swift:81`; `fitbod/App/ProgressHistorySeed.swift:96` |
| ActiveBlockSeed | Active mode starts immediately; the ended modes leave completed blocks and old workouts, with no waiting ready block. | `fitbod/App/ActiveBlockSeed.swift:45`; `fitbod/App/ActiveBlockSeed.swift:69`; `fitbod/App/ActiveBlockSeed.swift:85`; `fitbod/App/ActiveBlockSeed.swift:103` |
| BlockStatesSeed | Includes a ready block, but also an active block; its nonempty workout is two days old, and Upper B is an empty workout of a populated template, not a session template without exercises. | `fitbod/App/BlockStatesSeed.swift:93`; `fitbod/App/BlockStatesSeed.swift:122`; `fitbod/App/BlockStatesSeed.swift:129`; `fitbod/App/BlockStatesSeed.swift:148`; `fitbod/App/BlockStatesSeed.swift:155` |
| CalibratingSetSeed | Populated template, a week-old workout and an open workout, without a block. | `fitbod/App/CalibratingSetSeed.swift:60`; `fitbod/App/CalibratingSetSeed.swift:76`; `fitbod/App/CalibratingSetSeed.swift:105` |
| WeeklyTonnageSeed | Directly creates finished history, possibly today on Sunday, but creates neither a block nor an empty session template. | `fitbod/App/WeeklyTonnageSeed.swift:68`; `fitbod/App/WeeklyTonnageSeed.swift:90`; `fitbod/App/WeeklyTonnageSeed.swift:104` |
| PowerbuildingSeed | Active plus draft, populated routine, no workout, and recap suppressed. | `fitbod/App/PowerbuildingSeed.swift:81`; `fitbod/App/PowerbuildingSeed.swift:104`; `fitbod/App/PowerbuildingSeed.swift:106`; `fitbod/App/PowerbuildingSeed.swift:109` |

The new ready-with-none-active, empty-template and finished-today-under-a-block seeds are therefore justified (`plan.md:19`).
An exercise-import failure can incidentally leave DemoWorkoutSeed's template empty because missing catalog entries are skipped, but that is not a deterministic replacement for the proposed empty-template fixture (`fitbod/App/DemoWorkoutSeed.swift:245`, `fitbod/App/DemoWorkoutSeed.swift:252`).

| Reused fixture | Verdict |
|---|---|
| powerbuilding | Correct data for a long-name scenario in the existing large hero, with the literal name Powerbuilding; unverified as a truncation fixture for the new compact plan line, whose rendered fit was not measured (`fitbod/App/PowerbuildingSeed.swift:5`, `fitbod/App/PowerbuildingSeed.swift:46`, `plan.md:17`). |
| empty-workout | Correct nonempty finished workout without a block plus a later empty workout; the midnight-start problem is addressed in v4, but V4-F3 covers the remaining timestamp problem (`fitbod/App/DemoWorkoutSeed.swift:70`, `fitbod/App/DemoWorkoutSeed.swift:282`, `plan.md:19`). |
| ended-block-recap | Correct live routine without an active block, with a review and recap intentionally due; for a reproducible capture use its documented start-Program argument, then dismiss the recap before evaluating the underlying T-PICK and notice (`fitbod/App/ActiveBlockSeed.swift:21`, `fitbod/App/ActiveBlockSeed.swift:27`, `fitbod/App/ActiveBlockSeed.swift:103`, `plan.md:33`). |

Two source-list qualifications follow from the audit: the long-name claim establishes a fixture string rather than new-layout overflow, and DemoWorkoutSeed line 113 belongs to normal demo mode rather than one of the recap-with-* branches (`review-log.md:154`, `review-log.md:99`, `fitbod/App/DemoWorkoutSeed.swift:67`, `fitbod/App/DemoWorkoutSeed.swift:77`, `fitbod/App/DemoWorkoutSeed.swift:113`).
The normal demo clamp also has an explicit previous-week fallback when there is not enough elapsed time, so copying only its max expression is not a complete same-day fixture policy (`fitbod/App/DemoWorkoutSeed.swift:112`).

### Completed item: layout defaults and decision coverage

Scope assumption: product defaults include state selection, action availability, navigation, confirmation and capability scope; type size, tokens and rendered row geometry are implementation acceptance requirements rather than new approval questions.
Both layout leaves and all fourteen O-rows were compared, without reopening the experience review's accepted choices.
Missing entries below need an index or cross-reference, not renewed user permission.

| Decision | Coverage result | Evidence |
|---|---|---|
| O-1 | The removal and History replacement are recorded; the claim about what most splits display is not established by a source audit. | `open-decisions.md:9`; `hierarchy.md:26`; `fitbod/Views/TodayView.swift:472` |
| O-2 | The slot, NEXT, wrapping and skipped-session rules are recorded; routine selection and the sheet's differing tap behaviors remain separate choices below. | `open-decisions.md:10`; `today-layouts.md:364`; `today-layouts.md:365`; `today-layouts.md:367` |
| O-3 | DONE eligibility and multiple workouts are recorded; add its priority over READY as an explicit cross-reference. | `open-decisions.md:11`; `today-layouts.md:165`; `hierarchy.md:60` |
| O-4 | Recap presentation is recorded, but its Progress destination conflicts with the explicit exclusion, covered by V4-F4. | `open-decisions.md:12`; `plan.md:54`; `evaluation.md:58` |
| O-5 | Active-block suppression and loss of the notice on start are recorded; acknowledgement on any dismissal and review priority over advice are separate defaults below. | `open-decisions.md:13`; `today-layouts.md:212`; `today-layouts.md:224`; `hierarchy.md:71` |
| O-6 | Oldest-created ready ordering, ties and visible creation caption match the leaves; it does not record the drafts-only rule. | `open-decisions.md:14`; `today-layouts.md:209`; `program-layouts.md:121`; `program-layouts.md:130` |
| O-7 | Folder scope is recorded; executable-caller wording needs V4-F2's qualification. | `open-decisions.md:15`; `plan.md:45` |
| O-8 | Presets inside the creation flow match the empty-Program leaf. | `open-decisions.md:16`; `program-layouts.md:188` |
| O-9 | Logged-workout navigation and both start controls' shared state gate match the leaves. | `open-decisions.md:17`; `program-layouts.md:58`; `program-layouts.md:93`; `program-layouts.md:95` |
| O-10 | Explicit ending through overview matches the plan-complete layout. | `open-decisions.md:18`; `today-layouts.md:103`; `today-layouts.md:104` |
| O-11 | Noninteractive exercise rows and the hero's detail entry match. | `open-decisions.md:19`; `today-layouts.md:45`; `today-layouts.md:46` |
| O-12 | Today creation scope, including the review's exception, matches. | `open-decisions.md:20`; `today-layouts.md:226`; `today-layouts.md:254` |
| O-13 | Omitting Now-slab week cells matches the leaf. | `open-decisions.md:21`; `program-layouts.md:57` |
| O-14 | Creation-date semantics match source; qualify its every-ready-block wording with the DONE and open-workout precedence already specified elsewhere. | `open-decisions.md:22`; `hierarchy.md:44`; `hierarchy.md:60`; `program-layouts.md:125`; `fitbod/Periodization/BlockDraft.swift:80` |

| Default without a complete O-row | Existing leaf or accepted decision to index |
|---|---|
| No-block hero selection, standalone-session fallback, fresh-store versus repair distinction, and the routine selected for repair | `today-layouts.md:248`; `today-layouts.md:249`; `today-layouts.md:250`; `today-layouts.md:272`; `today-layouts.md:320`; `tradeoffs.md:31` |
| Newest-created draft leads with Continue, and drafts do not affect Today | `program-layouts.md:129`; `program-layouts.md:130`; `program-layouts.md:150`; `tradeoffs.md:46`; V4-F5 |
| Routine-sheet rows start immediately, Other sessions rows preview, and empty routine sessions are repaired through Program | `today-layouts.md:353`; `today-layouts.md:354`; `today-layouts.md:369`; `today-layouts.md:372` |
| Review becomes an opt-in notice, every dismissal acknowledges it, and review outranks fatigue advice | `today-layouts.md:221`; `today-layouts.md:224`; `hierarchy.md:71`; `plan.md:33` |
| Advice remains available without a block but is suppressed during an open workout or a deload phase | `hierarchy.md:68`; `today-layouts.md:72`; `today-layouts.md:127`; `plan.md:17` |
| Empty-workout discard is immediate on both tabs, replacing Program's always-confirm flow | `today-layouts.md:125`; `program-layouts.md:206`; `tradeoffs.md:53` |
| Volume moves behind navigation from both tabs, untrained muscles collapse, and no-block T-FIX has no volume row | `today-layouts.md:321`; `today-layouts.md:378`; `today-layouts.md:381`; `today-layouts.md:382`; `plan.md:37` |
| Completed blocks move behind Past, the review reopens from overview, and its original acknowledgement date is kept | `program-layouts.md:62`; `program-layouts.md:227`; `program-layouts.md:229`; `tradeoffs.md:43` |
| Empty Program leads with routine creation while block creation remains enabled and supplies a routine-creation escape | `program-layouts.md:189`; `tradeoffs.md:49`; `plan.md:38` |

Existing tradeoffs document several of these choices, so V4-F4 concerns register coverage and consistency rather than a claim that the choices lack rationale.
The v4 fixes did not add the empty-routine and standalone-session data to the explicit TodayState contract, yielding V4-B1, and the remaining summary discrepancies are isolated in V4-F6.

### Checked and correct in this pass

- Seven today.sessions consumers
- Two LIVE BLOCK consumers
- Seven Program card-label consumers
- Four BlockBuilderView source readers
- Three distinct new fixture states
- Ready-block creation-date semantics
- O-2 slot forwarding
- O-9 shared start-control gate
- O-10 explicit block ending
- O-12 review-builder exception
