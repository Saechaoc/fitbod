# Plan: finish and deliver Milestone 1

## Context

The /goal is the first usable native iOS workout app: SwiftUI and SwiftData, the BRU design system, and a persisted workout flow.
Every visible action must work on small and large iPhones and at larger text sizes.
The milestone also needs docs, a component gallery, screenshots and a roadmap.

What read-only checks on 2026-10-28 show:

- HEAD is `2bb5a91` (Oct 4).
  All milestone work is uncommitted: 172 paths (130 modified, 42 untracked).
  No app source has changed since Oct 5.
- Codex's closeout (`docs/MILESTONE-1-CLOSEOUT.md`, `docs/VERIFICATION.md`) says acceptance is still open.
  Its last full run had 1,021 passed, 4 failed and 1 expected failure.
  Its fixes for those 4 failures were never run, because its sandbox blocked CoreSimulator and `.git`.
  It prepared seven commit groups listing exact paths (303 in total) in `docs/verification/closeout/`, but committed none of them.
- My Oct 5 review found 46 defects plus one possible defect.
  All of them still apply, because no source has changed since.
  Examples: Copy/Edit opens a blank sheet.
  Skip warm-ups does nothing.
  "Use" in Why-this-weight does nothing, because no caller passes `onUseSuggested`.
  Typing a target rep of 1 can turn 6 into 16.
  Program is unreadable in dark mode.
  Program's template rows build different blocks from the ones they describe.
  Export needs two taps.
- Another Claude terminal is copying a refreshed design export from the claude.ai design project ("Fitbod Session.html").
  Nothing new has landed yet in the repo, Desktop, Downloads or Documents.

Intended outcome:

- Every visible action works.
- The full authored journey passes on iPhone 17e and iPhone 17 Pro Max, at default text and AX3, in light and dark mode.
- Data survives relaunch.
- Docs and evidence match the build.
- The work is committed in reviewable groups and pushed to main.

**Role change.**
Approving this plan ends the "Codex finishes, Claude reviews" arrangement.
A coordinator and its Orca workers implement, verify and commit, and the coordinator pushes.
No other agent, Codex included, edits this repo or its worktrees while the run works.

## Ground rules

- **Process.** The phases below run as the Orca tickets in `docs/conway-specs/`, which cover Phases 1-7.
  Its `dispatch.md` is the coordinator's playbook, and its `worker-rules.md` binds every worker.
  Workers skip GSD for this run, which the user approved on 2026-10-29.
  The quick-task run finishes only its live tasks, `261028-uhg` Task 3 and `261029-a9s`, and starts none of its queued plans, `261029-d6u` to `261029-di1`.
  Their commits map onto tickets before the first dispatch.
- **Parallel lanes.** Up to three workers run at once, and each ticket gets its own git worktree and branch from the newest `main`.
  Each lane has its own two simulators and its own DerivedData folder, so no two workers ever share a simulator.
  Two tickets never edit the same file at the same time, and a worker asks before it edits a file outside its ticket's list.
  The tickets that touch many files or run the full suite (T42-T48) run alone.
  Phases still run in order, and a phase starts only after the previous phase's gate passes.
  Each worker rebases onto `main` before its final runs.
  The coordinator merges each accepted branch as a fast-forward, after another rebase and a build if `main` moved.
- **Bug fixes.** I reproduce each bug first, with a UI test that drives the app the way a user would, and I watch it fail.
  For a visual defect, the reproduction is a screenshot test on the right phone, text size and appearance.
  Then I fix the bug, rerun the test, and keep it as a regression test.
- **GitNexus.** The index is refreshed first, where GitNexus works.
  Impact analysis runs before each symbol edit, and any HIGH or CRITICAL rating is reported.
  In a worktree, `detect_changes` cannot see the staged files, so each worker saves `git diff --cached --stat` and its changed symbols before every commit, and the coordinator compares the whole run with its base before the push.
  Where the index has no Swift symbols, as on csaechao4's Mac, workers check callers with `rg` instead, and nobody runs `gitnexus analyze`.
- **Commits.** I stage exact paths only and never use `git add -A`, because the other terminal may be writing design files.
  Every commit builds, and its tests pass.
  Workers commit on their own ticket branches, and only the coordinator moves `main`.
  Commits get no Co-Authored-By trailer, because your CLAUDE.md rule overrides the system reminder.
  Each message ends with the Claude-Session line.
  Nothing is pushed before Phase 8, and nothing is ever force-pushed.
- **Simulators.** Each lane uses its own pair, "sw6-L<n> iPhone 17e" (390pt wide) and "sw6-L<n> iPhone 17 Pro Max" (440pt wide).
  The phase gates and T42-T48 use "sw6 iPhone 17e" and "sw6 iPhone 17 Pro Max".
  Simulator ids differ between Macs, so the run log records them, and workers pass them by id.
  Tests run serially within each worker, with `-parallel-testing-enabled NO`.
  No worker ever uses the personal iPhone 17 Pro or Codex's `fitbod-codex-*` devices.
- **Code.** I follow the CLAUDE.md conventions: `@Observable` view state, `@Query` directly in views, SchemaV7 only, and BRU tokens and components.
  Every New Block edit runs all five New Block guardrail suites:
  `BlockBuilderViewCopyTests`, `NewBlockProgressionChartTests`, `NewBlockBuilderFidelityTests`, `BRUPeriodizationAuditTests` and `BRUPeriodizationRegressionTests`.
- **Dead controls.** If a control's behavior is clear, I wire it up.
  If it is not, I remove the control and add a roadmap entry.
  No visible control is left dead.

## Phase 0 - Protect the work and set a baseline

1. Back up the whole working tree to the local branch `backup/m1-worktree-20261028`.
   The backup covers tracked and untracked files and respects .gitignore.
   I build it with a temporary index (`GIT_INDEX_FILE`, `write-tree`, `commit-tree`, `update-ref`), so the working tree and the real index stay untouched.
2. Restore `parallelizable = "NO"` on `fitbodUITests` in `fitbod.xcscheme`.
   Xcode dropped it today, and CLAUDE.md requires serial simulator runs.
3. Refresh GitNexus with `npx gitnexus analyze`.
4. Build the app and the widget.
   Run the full suite serially on the large phone at default text and record the exact counts.
   This is also the first real run of Codex's four unverified fixes.
5. Check Codex's seven path lists against `git status` and `docs/verification/closeout/source-hashes.json` to catch drift since Oct 5.
   Commit the seven groups in order, using the messages in `commit-plan.md`.
   Run `detect_changes(scope: staged)` before each commit.
   Paths that Codex left out of the groups stay uncommitted.
   After group 07, the tip must build and match the results from step 4.
6. Add items 26-47 to `docs/review-docs/fitbod-m1-review.md`, so the review record is complete again.

## Phase 1 - P0 and P1 defects

This phase covers items 1-9 and 26-34 (see Appendix A).
I fix them in this order:

1. Data loss and dead actions: 1, 2, 3, 5, 6, 33, 34 and 4.
2. Wrong results: 26, 27, 28, 29, 31 and 32.
3. Display: 7, 8, 9 and 30.

## Phase 2 - P2 defects

This phase covers items 10-21 and 35-47.

- **Swipe-back audit.** 35 files hide the navigation bar, and nothing restores the edge-swipe back gesture.
  I add one edge-swipe UI test for each pushed screen.
  Then I fix the gesture once, for the whole app, and verify each screen, including the block overview after item 35.
- **Item 47** (the block name may lose its first typed character): I reproduce it with real key taps before changing any code.
- **Items 20 and 42** (the custom exercise editor, the muscle picker and the Pinned Note sheet): before I rebuild them, I run the design-export check from Phase 5 and build from the newest export.

## Phase 3 - P3 polish and copy

This phase covers items 22-25 and the copy additions under item 25.

- Count labels use one shared plural helper.
  It follows the existing `count == 1 ?` pattern in `ProgressHomeView.swift:314`.
- Copy that names a tab or a program entity follows the glossary: the Program tab, Routine and Session.
  The code names `Split` and `SessionTemplate` never appear on screen.

## Phase 4 - Test health

- **Journey reset race.** Each test process launches and terminates the app once, then checks that the store is fresh.
- **Number entry.** After item 5 is fixed, the test helper types the way a user does (tap, then type), so the test would catch the original bug again.
- **Why-this-weight tests.** These tests open the sheet with the new visible WHY control, and they check that Use writes the weight.
- **Known issue in `ProgramGraphDeleteRuleBehaviorTests`.** I check whether any UI path can hard-delete a session that is still slotted in a routine.
  If one can, I add a guard in app code and test it.
  Either way, the CLOSEOUT flag will say exactly what is proven.
- **Warnings.** I fix the build warnings and deprecations, including the text-concatenation deprecations that Codex noted.

## Phase 5 - Design refresh

- **Detect the export.** The coordinator runs `git status --porcelain bru-screens/` in the main checkout, and lists files under `bru-screens/` that a commit after 2026-10-28 changed.
  File dates in a checkout only show when it was checked out, so they do not count.
  The June copy landed in `bru-screens/Fitbod-Session/`.
- **If the export is there:**
  - I compare it with the Oct 2 snapshot.
  - I list what changed on the milestone screens: Library, exercise detail, custom exercise, routine builder, workout logger, rest timer, summary, history and Today.
  - I build those changes with BRU tokens and components.
  - I update the component gallery and the design-system docs.
- **If it is still missing when Phase 6 starts:** I keep the Oct 2 snapshot, which the build already follows, and I say so in the final report.

## Phase 6 - Full verification

- Run the full unit and UI suite serially on both phones, at default text in light mode.
- Run `MilestoneOneJourneyUITests`, `HistoryAndTodayUITests` and `WorkoutSwapJourneyUITests` on both phones at AX3 (`accessibility-extra-large`) in light mode.
  Then run the journey again in dark mode.
- Check relaunch persistence:
  - Log a workout.
  - Terminate the app.
  - Relaunch without the reset flag.
  - Confirm the sets, the rest deadline and the history.
- Do a hands-on walkthrough on both phones at default text and AX3, in light and dark mode.
  Screenshot every milestone screen, and fix anything that looks off.
- Run `python3 docs/design-system/tokens_check.py` and `git diff --check`, and confirm there are no new build warnings.

Command template (phone ids from the run log in `docs/conway-specs/run-log.md`):

```sh
xcrun simctl ui "$SIM" content_size large   # or accessibility-extra-large
xcrun simctl ui "$SIM" appearance light     # or dark
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath "$SCRATCH/dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SCRATCH/m1-$RUN.xcresult" \
  test CODE_SIGNING_ALLOWED=NO
```

The milestone is done when all of these are true:

- The app and the widget build.
- Both phones have zero unexpected test failures.
- The authored journey passes on both phones at default text and AX3, and in dark mode.
- Relaunch persistence is shown.
- Every item in Appendix A is fixed with a regression test or screenshot evidence, or is removed or deferred with a stated reason.

## Phase 7 - Docs and evidence

- Update these docs with the new runs, device names and ids, counts and screenshots:
  `VERIFICATION.md`, `MILESTONE-1-CLOSEOUT.md`, `MILESTONE-1-AUDIT.md`, `CORE-SCREENS.md`, `SETUP.md`, `ROADMAP.md`, the design-system docs and the component gallery.
- Fix these known doc errors:
  - The large-text limitation at `VERIFICATION.md:138-141`.
  - `iphone-pro-max-ax3-dark-workout.png` is listed as passing, but it shows the item 10 defect.
  - There are no dark-mode Program screenshots.
- Mark acceptance only where evidence exists.
  Keep the remaining flags open, each with its next action.
- Refresh the local review page `.lavish/milestone-1-closeout.html`.
  I do not publish anything.
- In docs I substantially edit, each sentence goes on its own line, and I use "-" instead of em dashes.

## Phase 8 - Commit, push, report

- Fix commits land during Phases 1-5.
  Each one is a single change, builds, and has passing tests.
  Docs and evidence go in a final commit.
- Check that no ticket worktree or branch is left.
- If T48 or a late finding changed app or test code after the last full verification run, run T44 again on the final code, and T45 too when a journey screen changed.
  Then update the verification docs and the review page to cite those runs, before the push.
- Compare the run with its base using `detect_changes`, or `git diff --stat` where the index has no Swift symbols, then run `git push origin main`.
  You authorized this push earlier, and approving this plan confirms it.
  CI does not run on pushes to main, so the local evidence is the record.
- Report back in plain English: what changed, the evidence, the open flags and the roadmap.

## Product decisions I will make (change any of them before approving)

1. Program's template rows are generated from `BlockTemplates.swift`.
   That file becomes the one preset catalog for both Program and New Block.
   I add a real 5/3/1 template: 4 weeks, with one week each of accumulation, intensification, realization and deload.
2. Picking a New Block preset sets the name and the phases.
   It asks before replacing phases you have edited, and it leaves days per week alone.
   I remove presets that have no real definition.
3. New Block has two saves.
   The top action saves a draft, and the bottom action saves a ready block.
   Both need a name, and their labels say which is which.
4. The workout, set and pinned note sheets each edit a local copy.
   SAVE writes the copy.
   CANCEL and swipe-down throw it away.
5. "Logged sets" means completed working sets, and skipped warm-ups never count.
   One shared count drives the resume slab, the resume banner and the logger.
6. Finishing a workout with no completed sets offers Discard instead of saving.
   Empty workouts already saved stay in history, but they are left out of session counts and Compare.
7. Archiving a routine asks for confirmation first.
   Archived routines move to an Archived list on Program, where they can be restored.
   Every other routine list leaves them out.
8. A visible WHY control opens Why-this-weight and dismisses the keyboard.
   Use writes the suggested weight.
   Override closes the sheet and focuses the weight field.
9. Whether a first log counts as a PR stays a roadmap decision.

## Risks

- GitNexus rates shared SwiftUI edits CRITICAL, because of how widely the modules import each other.
  I report these ratings and check the named flows instead of stopping.
- If the design export reworks a screen heavily, the rebuild could grow large.
  I limit it to milestone screens and put the rest on the roadmap.
- Some checks stay open flags, because a simulator cannot prove them: physical-device VoiceOver, haptics, notification permissions, and a fully offline journey.
- Three lanes share one Mac, so UI tests can time out under load.
  The coordinator drops to two lanes when that happens, and gates and T42-T48 run with no other worker.
- Two tickets can pass alone and break each other once both are merged.
  A rebase and a build before each merge, and the full suite at each phase gate, catch it.

## Appendix A - Defect checklist

Items 1-25 are described in full, with fixes, in `docs/review-docs/fitbod-m1-review.md`.
Phase 0 added items 26-47 to the same file, under "Second pass", so the table below is a summary.

| # | P | Defect | Fix | Key files |
|---|---|---|---|---|
| 1 | P0 | Copy/Edit opens a blank sheet on the first tap | `.sheet(item:)` | `ExerciseDetailView.swift:146-168` |
| 2 | P1 | Skip warm-ups does nothing | `.buttonStyle(.plain)` and `contentShape`; a done state; the shared logged-set count (decision 5) | `WarmupRampRows.swift:234-250`, `SessionExerciseCard.swift:252-258`, `SessionLoggerView.swift:271-275` |
| 3 | P1 | Swipe-down throws away unsaved edits | `.interactiveDismissDisabled(isDirty)` | Editor sheets (see review) |
| 4 | P1 | Why-this-weight is hidden behind a long press, the field stays focused, and Use does nothing | Decision 8; pass `onUseSuggested` | `WhyThisWeightSheet.swift:446-458`, `PrescriptionWeightCell.swift` |
| 5 | P1 | Target reps turn 6 into 16 | Select all on focus, or `BRUStepper` | `PrescriptionEditorRow.swift:150-192` |
| 6 | P1 | RPE "8 - 8" is two fields bound to one value | One control | `PrescriptionEditorRow.swift:205-232` |
| 7 | P1 | Heatmap muscles overlap, and taps hit the wrong muscle | `.position` at the exact rect, no hit padding, fixed VoiceOver labels | `BodySilhouetteView.swift:140-146` |
| 8 | P1 | Program's empty state at AX3; the Resume pill | AX3 layout (see review) | `ProgramView.swift`, `ResumeWorkoutBanner.swift:65-93` |
| 9 | P1 | Dark mode: Program rows are unreadable, CHOOSE ROUTINE is black on black, New Block stays light | Adaptive BRU colors only | `ProgramView.swift:813-817,844`, `BlockBuilderView.swift:296-305,2055-2099,2357`, `BlockNameField.swift:20-21` |
| 10 | P2 | Warm-up ramp at AX3 | Stack at accessibility sizes | `WarmupRampRows.swift:163-173` |
| 11 | P2 | Stat strips at AX3 | Stack at accessibility sizes | `SessionHistoryStatStrip.swift:44-72`, `SessionDetailView.swift:119-134` |
| 12 | P2 | Session editor at AX3 | Stack at accessibility sizes | `PrescriptionEditorRow.swift:299,353-365`, `SetRowsContainer.swift:94-105`, `PerSetOverrideRow.swift:39` |
| 13 | P2 | The exercise index shows "•••" | Fixed-width index that fits | `RoutineExerciseCard.swift:130-138` |
| 14 | P2 | The backup footer makes RESTORE look like the main action | CREATE is primary | `SettingsView.swift:386-467` |
| 15 | P2 | "+ New routine" then Back leaves an "Untitled" routine | Create the routine on first save | `ProgramView.swift:284-288`, `TodayView.swift:561-565` |
| 16 | P2 | BRUButton's fill bleeds into the home indicator area | Respect the safe area | `BRUButton.swift:172` |
| 17 | P2 | Toggles are stock green | `.toggleStyle(.bru)` | `PrescriptionEditorRow.swift:249,298,314` |
| 18 | P2 | The "M" badge spills into reps, and weight shows 0 | Layout and empty-value fix | `SetRow.swift:127`, `PrescriptionWeightCell.swift:83,105-112,139-150` |
| 19 | P2 | Creating a custom exercise ignores the search text | Prefill the name | `ExerciseLibraryView.swift:117` |
| 20 | P2 | The custom exercise editor and the muscle picker are stock iOS; the "Lower Back · Upper" label; muscle order | BRU rebuild, readable labels, primary muscles first | `CustomExerciseEditor.swift`, `MusclePickerSheet.swift` |
| 21 | P2 | Lowercase exercise names (`canonicalName` used as a display name); duplicate ADJUST TARGETS label | Use the display name everywhere | `LiftListRow.swift:39`, `ExerciseHistoryView.swift:67`, `PerMuscleDetailView.swift:309`, `WeeklyRecapSheet.swift:766,776`, `TryVariationSheet.swift:174` |
| 22 | P3 | Volume tick labels crowd the muscle name; a stepped divider | See review | Volume rows |
| 23 | P3 | The half-height rest sheet cuts off SKIP | Fit the detent to the content | `RestTimerOverlay.swift:60-62` |
| 24 | P3 | Small AX3 problems: Today header, "RESUME ▶" wraps, RPE chip "10", PERFORMANC/E, the legend | See review | Several |
| 25 | P3 | Copy nits (see review and the additions below) | Shared plural helper and glossary copy | Several |
| 26 | P1 | Program's template rows describe different blocks from the ones they build; "4W 5/3/1" builds a blank 0-week block | Decision 1 | `ProgramView.swift:291-324`, `BlockTemplates.swift:29-58` |
| 27 | P1 | The New Block preset picker only renames the block; it sets phases only for hypertrophy and forces 4 days | Decision 2 | `BlockBuilderView.swift:214-233,376-426` |
| 28 | P1 | A ready or draft block shows the active hero, "#41" (the ISO week number), and phase 1 as NOW | A ready hero; number blocks in order; no NOW before the start | `BlockOverviewScreen.swift:209-213,229-231,318-325,768-769,792` |
| 29 | P1 | A completed block claims every phase and session was completed, and still shows TODAY, NEXT and "1 LEFT" | Derive from the archive and the status | `BlockOverviewScreen.swift:265-295,900-960` |
| 30 | P1 | A stripe stretches the routine banner to about 360pt and the Plate Inventory tabs to about 330pt | `.fixedSize(horizontal: false, vertical: true)` (verified on a copy) | `LiveEditBanner.swift:49-51`, `PlateInventoryEditor.swift:136-139` |
| 31 | P1 | The PR list repeats one set, shows no exercise names, and has blank sections | Composite ids (verified on a copy), ranking per exercise, names | `ExercisePRsView.swift:277,294-328,354-376` |
| 32 | P1 | The E1RM and VOLUME chips do nothing, and AVG RPE shows the mean e1RM | Build the real series | `SeriesToggleChipRow.swift:44-57`, `SeriesBuilder.swift:110-122` |
| 33 | P1 | CANCEL keeps typed text in the workout, set and pinned notes | Decision 4 | `WorkoutNotesSheet`, `PerSetNoteSheet`, `PinnedNoteSheet` |
| 34 | P1 | Exporting CSV or JSON and creating a backup each need two taps | One `ShareLink` with a lazily rendered `Transferable` file | `SettingsView.swift:303-345,412-430,615-626` |
| 35 | P2 | The block overview shows two back buttons | Hide the system bar on the main body; keep swipe-back | `BlockOverviewScreen.swift:138-205` |
| 36 | P2 | The top SAVE makes a draft and the bottom one a ready block; the top one works with no name | Decision 3 | `BlockBuilderView.swift:432-470,2143-2185`, `BlockDraft.swift:86` |
| 37 | P2 | Mid-word line breaks on the 17e at default text (hero, legend, calculator, routine meta) | `lineLimit(1)` with `minimumScaleFactor`, or `ViewThatFits` | `BlockOverviewScreen.swift:346-349`, `BlockBuilderView.swift:909-953` |
| 38 | P2 | Weekly Tonnage: "KG" is hard-coded, "1 WEEKS", bars use Sunday weeks but the aggregator uses Monday weeks, one bar fills the chart | Unit from settings, plural helper, one week rule, a fixed week domain | `WeeklyTonnageView.swift:182,226,238,253,277`, `WeeklyTonnageAggregator.swift:112` |
| 39 | P2 | Compare shows "OCT 5 Δ OCT 5" against an empty workout; names are ragged and centered | Compare with the last finished workout that has sets; aligned names | `ProgressHomeView.swift:178-195`, `SessionComparisonView.swift:91-179` |
| 40 | P2 | An empty finished workout counts as a session | Decision 6 | `ProgressHomeView.swift:308-320` |
| 41 | P2 | The first set's note is titled "SET 5 NOTE" | `SessionSetActions.displayNumber(of:)` | `PerSetNoteSheet.swift:72`, `SetRow.swift:275-281` |
| 42 | P2 | The Pinned Note sheet is stock iOS | Rebuild it like `WorkoutNotesSheet` | `PinnedNoteSheet.swift` |
| 43 | P2 | Plate Inventory has no back button and no swipe-back; SAVE INVENTORY does nothing; the calculator's "•••" and Save do nothing | BRU back header; wire or remove each control | `PlateInventoryEditor.swift:58-61,86,325-328`, `PlateCalculatorSheet.swift:161,410-412` |
| 44 | P2 | Archive has no confirmation and no restore, and the other tab still shows the archived routine | Decision 7 | `SplitDetailView.swift:364-384` |
| 45 | P2 | VoiceOver reads "Phase 1: Accumulation" 12 times | `.accessibilityElement(children: .ignore)` plus a value for each row | `BlockBuilderView.swift:1372`, `BlockPhaseEditorRow.swift:61` |
| 46 | P2 | At AX3 on the 17e: the New Block top bar and "SAVE TE…" truncate, chart labels overlap; the hero, Today slab, index, chip, tag and routine edit break mid-word | Layouts that adapt to accessibility sizes | `BlockBuilderView.swift:432-470,1098-1110`, `BlackSlabCTA.swift:84-110`, `LiftListRow.swift:61-64`, `SplitDetailView.swift:518-521,574-579`, `ProgramView.swift:579-599` |
| 47 | P2? | The block name may lose its first typed character (seen with `typeText`) | Reproduce with real key taps; if it is real, replace the overlay placeholder and tap gesture with a native `TextField` prompt | `BlockNameField.swift:55-74` |

Additions to item 25:

- "1 sessions": `ProgramView.swift:585`; `BlockOverviewScreen.swift:727,792,1196`.
- "1 EXERCISES": `BlackSlabCTA.swift:85`.
- "Routines tab": `BlockOverviewScreen.swift:198`, `BlockCard.swift:61`.
- "define a block in Routines": `WeeklyTonnageFilterChips.swift:110`.
- "Remove from Session" in the logger.
- The phase text appears twice on Program's block row.
- The CHOOSE ROUTINE sheet has no close button.
- CANCEL has low contrast in New Block.
- Some back buttons are a bare "‹" (`MuscleVolumeTargetEditor.swift:49`, and the calculator).
- Volume target rows give no sign that they can be tapped.
- Today's third stat shows a dash (`TodayStatStrip.swift:86,160-176`).
- The week strip labels every future day NEXT.

These are not bugs, so they are left alone:

- The Developer section shows only in DEBUG builds.
- Volume target rows do expand.
- Units relabel numbers by design.
- "+ NEW" already has a 44pt tap area.
- Each tab keeps its own navigation stack on purpose.
- The rounded builder cards match the mockup.
- The DL badge clipping is only scroll clipping.
