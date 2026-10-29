# Handoff: Milestone 1 (usable workout app)

Written 2026-10-03 at the end of a session that hit its usage limit.
Start a new session by reading this file, then `.planning/quick/milestone-1-journey-audit.md` (full issue list and decisions).

## Goal (from the user's request)

Deliver the first usable version of the iOS workout app:
- a small, documented BRU design system;
- a working, persisted journey: library (search, filter by muscle and equipment, detail, custom exercise) → routine with ordered exercises and targets → start workout → log weight and reps, add and remove sets, complete sets, adjustable rest timer based on an absolute deadline → resume after relaunch → finish, summary, history, previous performance.

Workouts are stored as snapshots.
Every visible action must work.
Verify on a small and a large iPhone and at large text sizes.
Deliver docs, a component gallery, screenshots, setup steps, and a roadmap.

## Decisions already made (do not re-litigate)

- **Schema history reset (user decision):** keep only the baseline schema (SchemaV7), pass no migration plan, and move incompatible stores aside into `Application Support/IncompatibleStores/<timestamp>/` instead of crashing or deleting.
- **Navigation:** tabs are TODAY · PROGRAM · PROGRESS · LIBRARY (from the Claude Design reference). Settings opens as a sheet from the Today header. This reverses commit 3b0a2fa, so flag it to the user as an easy-to-revert assumption.
- **Terms:** UI "Routine" = `Split` (ordered sessions) and UI "Session" = `SessionTemplate` (exercises with targets). The builder now says "New session".
- **Pattern filter:** hidden, because the seeded catalog has no pattern data.
- **Commits:** never add a Co-Authored-By trailer. Stage exact paths only, because other sessions leave unrelated files in the tree. Use `/gsd-quick` or `/gsd-fast` for edits.

## Three work trees (merge them in this order)

### 1. `main` in `/Users/chrissaechao/Desktop/fitbod` (persistence agent)

- Committed: f850413, 49344db and 1fd385a. These freeze SchemaV1-V6 and were made BEFORE the user chose the reset.
- Uncommitted: the reset itself, which deletes SchemaV1-6 and FitbodSchemaMigrationPlan, adds `FitbodModelContainer`, and updates about 40 test files. Its state is unknown, because the agent stopped on a rate limit mid-task.
- It also touched three UI files that conflict with branch m1-journey: `Periodization/BlockOverviewScreen.swift`, `Routines/RoutineBuilderView.swift` and `Routines/SupersetAssignmentSheet.swift` (probably preview container fixes).

TODO:
- [ ] Finish the reset plan in `.planning/debug/pre-v7-store-launch-crash.md` (Current Focus, steps 1-7 plus the addendum). The build must pass and the move-aside recovery needs a test.
- [ ] Decide whether to keep or squash the three frozen-schema commits. They are superseded by the reset, so revert or squash them so history reads clearly.
- [ ] E2E: install over the V6 backup (it must move aside and launch) and over a V7 backup (data intact). Backups are in `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/store-backups/`. That folder is temporary, so copy anything you need into the repo or another durable place first.
- [ ] Remove the historical-build git worktrees that agent registered (`git worktree list`).

### 2. Branch `m1-journey` in `/Users/chrissaechao/Desktop/fitbod-m1` (orchestrator; latest commit 92bc370)

Done (builds; verified in the simulator unless noted):
- **Design system:** fa3d307 makes BRU fonts scale with Dynamic Type and adds condensed Bebas roles; `Font.bru(_:size:)` replaces every ad-hoc `Font.custom`. BRUButton has pressed and disabled states and full hit areas (sm is now 36pt). `bruHitArea()` covers small text buttons, and BRUDashedSlot, tab cells and header actions now take taps across their whole area.
- **Bar fix:** 4f991f1 (on main) stopped BottomActionBar from covering the routine builder.
- **Journey routing (92bc370):**
  - **Routines:** "+ New routine" creates a routine and opens it. The routine screen has an editable name, an Edit mode (move up/down, remove), Archive, and an empty state. New sessions are attached automatically.
  - **Starting a workout:** `SessionTemplateDetailView` has Start workout and Edit. `WorkoutStarter` reports in-progress conflicts and errors instead of hiding them. Today shows a "Start a workout" picker (`TodaySessionPicker`) whenever nothing is scheduled.
  - **Builder:** no Day tabs, a real duration chip, a wrapping name field, specific validation messages, and working Duplicate and Archive.
  - **Library and Settings:** a BRU library tab (search, muscle/equipment/mechanic chips, pinned letter sections, logged counts, "+ New" custom exercise). The BRU exercise detail has recent performance, muscle bars, instructions and settings, plus Edit for custom exercises and Copy for built-in ones. Settings now opens as a sheet from the Today header.
  - **Platform fixes:** tabs stay alive across switches. Two `#Predicate` crashes (multi-level optional chains) are fixed in ExercisePRsView and ExerciseDetailView.
  - **New components:** BRUFlowLayout, BRUStepper, BRUToggleStyle.
  - **Not checked in the simulator yet:** the new exercise detail screen and the Settings sheet were not viewed after the last build.

TODO on this branch:
- [ ] View the exercise detail in the simulator (the last build was not viewed yet). Then test custom-exercise creation, the validation error for an empty name, and Edit.
- [ ] Move "Clear filters" to the front of the chip row (it is cut off at 390pt).
- [ ] Routine builder card: replace the stock Steppers and Toggles in `PrescriptionEditorRow` / `RoutineExerciseCard` with `BRUStepper` and `.toggleStyle(.bru)`. Fix the per-exercise "RPE autoreg" chip, which disagrees with the routine-level progression.
- [ ] Today: the third stat cell shows "W1 / 1 —" when there is no block (show this week's sessions instead). Fix the stray partial-width underline under the volume legend and the nearly invisible "NOT TRAINED" chip.
- [ ] BRUHeaderBar: the legacy `center:` is mixed case while `.slots` is uppercase. Unify them.
- [ ] Program empty state (NO PROGRAM hero): consider a "+ New routine" path next to Define block (copy is protected by the 3 BlockBuilder copy guardrail suites; see memory).
- [ ] History: make `SessionHistoryView` reachable (from the Progress tab and the Today stat strip), make rows tappable to open `SessionDetailView` (built on the logger branch), and restyle it in BRU.
- [ ] `ExerciseLibraryView(onSelect:showsPickerHeader:)`: pass `showsPickerHeader: false` from `SwapExerciseSheet` (logger area) to avoid a double header.
- [ ] Update the copy-introspection tests for the changed strings: "New session", "Save session ▸", "Lift list" count, and the BRUTab `.library` case (BRUCompositePrimitivesTests expects "settings"). Several UI tests use `app.tabBars.buttons["Settings"]`, which never matched the custom tab bar, so they need rewriting.

### 3. Branch `m1-logger` in `/Users/chrissaechao/Desktop/fitbod-logger` (logger agent; stopped on a rate limit)

Committed: 01b498b (rest deadline persisted per session plus bottom timer dock), ca47e9d (resume slab: counts completed sets, ticks, confirms discard), d684165 (DEBUG `-fitbod-seed-demo-workout` launch argument), aac66a6.
Uncommitted: `Sessions/PreviousColumn.swift`, `Sessions/RestTimer/RestTimerOverlay.swift` (its last note was "Now apply the UI fixes").
Its simulator: "fitbod-logger iPhone 17" D409C89C-DE67-4970-A801-AE3A71378E56.

Its brief (check each against its commits):
- [ ] **P0 crash:** the logger crashes on EVERY open. `SessionFactory.seedPRTable` uses `entry.sessionExercise?.exercise?.id` inside `#Predicate`, which throws "Unsupported function expression TERNARY". Check whether it is fixed (there was a new `SeedPRTableAndSummaryTests.swift`).
- [ ] Rest timer: verify the deadline restores after the app is killed and after backgrounding, and that ±15 s and Skip keep the notification and Live Activity consistent.
- [ ] Remove a set and un-complete a set (`SessionSetActions.swift` exists), with immediate persistence.
- [ ] Finish leads to a summary; `SessionDetailView(session:)` is reusable from history (`SessionSummary.swift` and `SessionDetailView.swift` exist).
- [ ] "Previous" excludes the current session and unfinished sessions (`PreviousPerformanceExclusionTests.swift` exists).
- [ ] Snapshot fidelity: add `SessionExercise.exerciseNameSnapshot` (default ""), write `Session.template` and `templateName`, and test that later template or exercise edits don't change history (`SessionSnapshotFidelityTests.swift` exists).
- [ ] Remove the decorative drag handle and save weight/reps edits promptly.
- [ ] Final E2E with screenshots in `/private/tmp/claude-501/shots/logger/`, plus a test run.

## After merging (still to do for the milestone)

- [ ] Merge main (reset), then m1-logger, then m1-journey. Resolve the conflicts listed above, rebuild, and run the full unit tests with `-parallel-testing-enabled NO`. 11 baseline failures were known before this work; report any new ones honestly.
- [ ] Full E2E journey on iPhone 17e (small) and iPhone 17 Pro Max (large): library filter → custom exercise → routine → session → start → log sets → rest timer → kill the app mid-rest → relaunch and resume → finish → summary → history → previous performance shown on the next workout. Capture screenshots.
- [ ] Repeat the key screens at AX large text sizes (`xcrun simctl ui <id> content_size accessibility-extra-large`) and fix clipping. Hero numbers need `.minimumScaleFactor`.
- [ ] Focused tests: persistence across container re-open, snapshot immutability, and rest-deadline recovery (some exist on m1-logger).
- [ ] Docs: `docs/design-system/README.md` covering tokens (colors with light and dark hex, type roles with sizes and Dynamic Type style, spacing, borders, radii (none), hit areas, states), usage rules, and the component catalog with a Swift mapping to the reference screens in `bru-screens/Fitbod-Session/screens/`.
- [ ] A component gallery screen: a DEBUG-only Settings → "Component gallery" listing every BRU component in all its states. Make sure each component has a `#Preview`.
- [ ] `docs/SETUP.md` (Xcode 26.5, simulator, fonts, catalog seed, and how to import the full free-exercise-db), `docs/VERIFICATION.md` (screenshots plus test evidence), and `docs/ROADMAP.md` (blocks and programs, larger catalog with pattern curation, analytics, Live Activities, sync).
- [ ] The app icon is still a placeholder "F".
- [ ] Update CLAUDE.md for the schema reset and the four-tab layout, and update memory (`project_program_graph_v7_run.md`; add one memory for the schema reset).

## Testing tips

- With the computer-use tools, the Simulator drops the `type` action. Use `key` presses, or `pbcopy` text and then cmd+V. Scroll by dragging.
- Several agent simulators share the screen. Bring yours forward with Window → device name, then Window → Stay On Top.
- SourceKit shows stale "cannot find type" errors. Trust `xcodebuild`.
- Build and install helper: the scratchpad `m1.sh` (temporary). It runs `xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination 'id=<sim>' -derivedDataPath /private/tmp/claude-501/dd-m1 build`, then `simctl install` and `simctl launch`.
