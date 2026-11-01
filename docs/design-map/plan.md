# Plan: Fitbod design map (`docs/design-map/`)

Status: planned, not started.
Base commit: `61353088` (`origin/main` on 2026-10-31).
Branch: `design/workflow-map`.

## How to resume

1. `git switch design/workflow-map` in `/Users/chrissaechao/Desktop/fitbod` and read this file.
2. Load the `context-map` skill (the deliverable shape) and the `plain-english` skill (the writing rules) before writing any document.
3. Start at stage S0 in the work order below.
4. Captures run on one simulator at a time; writing stages can go to subagents as described under decision 3.

## Brief (from the task)

- Map Fitbod's user workflows and screens, find the missing screens, and audit the design.
  The output is docs, flow diagrams and mock-ups only.
  No app code, tests or project files change.
- Glossary: in the UI a Routine is `Split`, a Session is `SessionTemplate`, and a logged Workout is `Session`.
  Never use code names in anything a user would read.
- Work on `design/workflow-map`, made from the newest `main`, and commit there.
  Never push to `main`, merge, or rebase `main`.
  Ask before pushing the branch.
- A teammate on another Mac owns `docs/conway-specs/`.
  Read that folder, do not edit it.
  Also read-only: `CLAUDE.md`, `.claude/`, `.planning/`, every `CHANGELOG.md`, `fitbod.xcodeproj/`, `bru-screens/`, `fitbod/`, `fitbodTests/`, `fitbodUITests/` and `FitbodWidgets/`.
- Anything that looks like a bug goes into the audit.
  Do not fix it.
- Write in plain, simple English with full sentences, never the em dash, and one sentence per line in Markdown.
- The user approved skipping the GSD workflow for this docs-only task.
- Sources: `CLAUDE.md`, `docs/ROADMAP.md`, `docs/MILESTONE-1-CLOSEOUT.md`, `docs/VERIFICATION.md`, `docs/CORE-SCREENS.md`, `docs/design-system/` (start at `README.md`), `bru-screens/` (JSX mock-ups to compare with the build), the SwiftUI views from `fitbod/App/RootView.swift` following every `NavigationLink`, `navigationDestination`, `.sheet`, `.fullScreenCover`, `.confirmationDialog`, `.alert` and tab switch, `docs/conway-specs/tickets/` with its `index.md`, and `docs/review-docs/fitbod-m1-review.md` with its screenshots.
  The code is the truth.
  When a doc and the code disagree, the code wins and the disagreement is recorded.
- Simulators: iOS 26.5 on iPhone 17e (390pt) and iPhone 17 Pro Max, created as `design-iPhone 17e` and `design-iPhone 17 Pro Max`, with DerivedData at `~/Library/Developer/Xcode/DerivedData/fitbod-design`.
  Never use simulators whose names start with `sw6-`.
  Build the `fitbod` scheme, not `FitbodWidgetsExtension`.
  Launch with `xcrun simctl launch <device> bodybuilding.fitbod <args>` and the DEBUG arguments `-fitbod-reset-store`, `-fitbod-seed-demo-workout`, `-fitbod-seed-empty-today`, `-fitbod-seed-empty-workout`, `-fitbod-seed-empty-between`, `-fitbod-seed-empty-last-week`, `-fitbod-seed-recap-with-empty`, `-fitbod-seed-active-block`, `-fitbod-seed-ended-block-recap`, `-fitbod-seed-block-states`, `-fitbod-seed-block-states-past-plan`, `-fitbod-start-program`, `-fitbod-seed-progress-history`, `-fitbod-seed-weekly-tonnage`, `-fitbod-week-starts-sunday`, `-fitbod-seed-powerbuilding`, `-fitbod-seed-calibrating-set` and `-fitbod-seed-stalled-exercise`.
  Read each `fitbod/App/*Seed.swift` header; some seeds must not be combined.
  Screenshot every screen and state on both phones, and dark mode and AX3 text size wherever the layout changes.
- Deliverables: `screens/` (one file per screen, sheet and dialog), `navigation.md` (one Mermaid map of the whole app), `workflows/` (one file per lifter job with numbered steps and a flowchart), `missing-screens.md`, `mockups/` (standalone HTML on BRU tokens, 390pt and 440pt, light and dark, PNG beside each HTML, no SwiftUI), `audit.md` (rows `D-01..` sorted by severity, then a patterns section) and `README.md` (index with at most ten sentences of summary at the top).
- Finish with a small script that checks every screen in the map has a `screens/` file and vice versa, every Mermaid diagram renders, and every image path exists; its output goes into the final report.
  Commit with a clear message and no AI co-author line.
  Report the branch and commit, the counts of screens, workflows, missing screens and audit findings, the summary, and anything unreachable.

## Context

Milestone 1 is closing through one-screen-at-a-time tickets in `docs/conway-specs/`, and nobody has written down the whole product.
This task produces that record as the input to the Milestone 2 design: every screen, the navigation between them, every lifter workflow with its dead ends, the screens that should exist but do not, BRU mock-ups for the must-have missing screens, and a strict design audit.
Bugs found are recorded in the audit, never fixed.

## Decisions confirmed by the user

1. Committed screenshots are downsized to 2x scale: `sips -s format png -Z 1700` (about 75-150 KB each, about 30-50 MB total).
   Full-size originals stay in the scratchpad; audit findings that need pixel detail get a small full-size crop under `audit/evidence/`.
2. The capture tooling is committed under `docs/design-map/tools/`.
   None of it is compiled or part of a target.
3. The plan runs on Opus 5.5 Max with medium-effort subagents.
   Captures stay serial, because one `xcodebuild` job owns the simulator at a time, and they run in the background while documents are written.
   Writing splits by leaf: one subagent per tab for `screens/` (Today, Program, Progress, Library, Settings with system UI and dialogs), one per two or three `workflows/` files once the screen files exist, and one per mock-up.
   The audit is written by one agent after everything else, so the `D-NN` numbering and the severity sort stay consistent.
   Every subagent gets the template for its leaf, the glossary, the writing rules, and runs `python3 -I tools/check_map.py` before it reports.
4. Coverage: every screen and state in light/default on both phones; the main state of every screen at AX3 on both phones and in dark mode on the small phone (about 350 images).
5. Multiple commits land on `design/workflow-map`, one per stage; the branch is pushed only after asking the user.

Defaults chosen without user input: dialogs and alerts get a `dialog-` file prefix; severity maps to the ticket scale (blocker = P0, major = P1, minor = P2, polish = P3); the DEBUG component gallery is included and marked debug-only; mock-ups reference the bundled fonts by relative path; the private worktree lives in the scratchpad and the runner recreates it if missing.

## What exploration established

- The app has 4 tabs with their own stacks, a custom BRU tab bar, Settings as a sheet from Today only, about 25 pushed or root screens, about 37 sheets and covers (3 are system: share sheet, file importer, photo picker) and about 25 confirmation dialogs and alerts.
  Tab roots: `TodayView` (`fitbod/Views/TodayView.swift`), `ProgramView` (`fitbod/Periodization/ProgramView.swift`), `ProgressHomeView` (`fitbod/Progress/ProgressHomeView.swift`), `ExerciseLibraryView` (`fitbod/ExerciseLibrary/ExerciseLibraryView.swift`); `enum Tab` is nested in `RootView.swift`.
  Route enums: `SessionRoute`, `SessionHistoryRoute`, `MuscleSlugRoute`, `BlockOverviewRoute`, `SplitDetailRoute`, `ArchivedRoutinesRoute`, `NewRoutineRoute`, `ExerciseProgressRoute` (its `.prs` case is never appended), `ProgressHomeRoute`, `PRsRouteDestination`.
- No deep links or URL scheme exist, so every screen is reached by tapping through the UI.
  The only navigating launch argument is `-fitbod-start-program`.
  The Live Activity emits `fitbod://session/active`, which nothing handles.
- The DEBUG reset runs in `fitbodApp.init` (`DebugLaunchReset.runIfRequested()`); seeds run in `RootView.runSeed()` after the catalog import (702 exercises, 3-5 s), so a seed can finish after the tab bar appears and a tour must wait for an element the seed creates.
  One seed per launch, always with `-fitbod-reset-store`; the demo, stalled and calibrating seeds clash (each leaves one workout in progress); the block seeds clash; the recap seeds (`-empty-last-week`, `-recap-with-empty`, `-ended-block-recap`) need `-fitbod-start-program`; `-fitbod-seed-weekly-tonnage N` takes its count right after the flag.
  Text size is per launch (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL` for AX3); appearance is per device (`xcrun simctl ui <udid> appearance dark`).
- `idb` is not installed, and Orca computer-use on the Simulator window is unverified for iOS elements.
  The repo precedent is XCUITest: the Milestone 1 review screenshots came from "review-only XCUITests in a private copy of the project" with `app.debugDescription` tree dumps; CI exports attachments with `xcrun xcresulttool export attachments` and downsizes with `sips` (`scripts/ci/collect_evidence.py`); ticket T46 (todo, not started) specifies a 33-screen tour named `<phone>-<size>-<appearance>-<screen>.png`.
- `fitbod.xcodeproj` uses `PBXFileSystemSynchronizedRootGroup` with no exceptions for `fitbodUITests`, so a Swift file dropped into `fitbodUITests/` of a private copy compiles into the UI test target with no project edit.
- Helpers to reuse from the copy (`fitbodUITests/UITestNavigation.swift` and siblings): `launch(_:textSize:)` (throwaway launch and terminate first, waits 90 s for the Today tab, asserts a fresh store), `relaunch`, `selectTab`, `openSettings`, `saveScreenshot`, `waitUntilStill`, `hittable`, `type` (the first typed character can drop), `swipeSheetDown`, `XCUIElementQuery.labeled(_:)`, `dragSheetDown`, `WorkoutUITestNavigation.openSeededWorkout` (taps `resumeSlab.resume`, waits for `set.reps.1.S1`), `openWeightExplanation` (`set.why.1.S1`).
  `fitbodUITestsLaunchTests` leaves the phone in landscape, so exclude it.
  iOS 26 confirmation dialogs hide the `.cancel` button.
  `SessionEditorPolishUITests/testEditorAtAX3` hangs on the 17e (T115).
- Code-level dead ends to verify on device: a PR row opens a placeholder with no back button (`ExercisePRsView.swift`); Week Detail rows draw "›" but do nothing (`WeekDetailView.swift`); Try Variation ignores the pick (`SessionLoggerView.swift`); Block Review opens only automatically from Today and cannot be reopened, its EXPORT is a label, and Plan custom dismisses without acknowledging; the "End block?" alert names a non-existent Routines tab (`BlockOverviewScreen.swift`); New Block is a sheet from Today but a full-screen cover from Program; the logger's Add Exercise sheet likely shows two headers; `RoutinesListView` with its New folder and Move routine sheets is unreachable; the settings model has `weekStartsMonday` and `deloadAlertEnabled` with no toggles.
- Copy near-misses to check: "Slot N", "Save Routine First", backticks in `SettingsView.swift`, "CREATE TARGET ROW", "No persisted target row".
- Mock colours in `bru-screens/*.jsx` differ from the shipped tokens; code wins (`fitbod/Design/Color+BRU.swift` with 16 `bru*` tokens, `BRUFont.swift`, `BRUMetrics.swift`, `fitbod/Assets.xcassets/bru*.colorset`).
  The May mocks use old names: mock "Routine" is today's "Session", mock "Routines" tab is Program.
  Fonts are bundled TTFs in `fitbod/Resources/Fonts/` (BebasNeue-Regular, SpaceGrotesk-Bold and SemiBold, JetBrainsMono-Regular and Bold, Geist-Regular), mapped in `BRUFont.swift` and listed in `fitbod/Info.plist`.
  The seven BRU rules are in `docs/design-system/principles.md`; `docs/design-system/tokens_check.py` checks contrast.
- Tooling: node 24 and npx (mermaid-cli via `npx -y`, not installed yet), Google Chrome 156 (headless render), Playwright 1.58.2 cached at `~/.npm/_npx/e41f203b7505f1fb/node_modules/playwright/cli.js` with chromium-1208 as a fallback, `sips`, `ffmpeg`, `jq`, python3 3.14 (no PIL), no ImageMagick, no git-lfs.
- Tickets to cite rather than repeat: T34, T35, T36, T37, T38, T39, T85, T98, T106, T107, T108, T109, T110, T111, T113, T114, T115, T116, T118, T120, T121, T122; T43, T46 and T48 overlap the design map itself.
  T105 and T112 merged on `61353088`, so their screens (New Block swipe to delete, exercise history rows) are captured in their fixed state; T110 is still open and will change the session editor after merge.
  The review `docs/review-docs/fitbod-m1-review.md` has 47 numbered findings.
  `docs/ROADMAP.md` lists the Milestone 1 removals (Off-Season and Pre-Meet presets, EDIT BLOCK top SAVE, Plate Inventory SAVE INVENTORY, the plate calculator's "•••", Save and Done, the weekly recap's ALL RECAPS) and the decisions awaiting product direction (first logs as records, deload misses, the Today "muscle sets" wording, the History "per week" range).

## Deliverable layout (context-map shape)

```
docs/design-map/
  README.md              index: as-of line, pointer table (one line per file/folder), summary of at most ten sentences; nothing a leaf elaborates
  plan.md                this file
  assumptions.md         what we took as given: code wins over docs, base commit, capture dates, phones, seeds, states no seed shows, overlapping tickets
  navigation.md          Mermaid: tabs overview + Today, Program, Progress, Library, Settings diagrams + a dialogs diagram
  screens/<id>.md        one per screen, sheet, cover, dialog, alert, system sheet (about 87 files); dialogs prefixed dialog-
  screens/img/*.png      <phone>-<size>-<appearance>-<screen>[--<state>].png
  screens/tree/*.txt     trimmed accessibility trees, one per screen (17e, light, default)
  workflows/<job>.md     11 files, one per lifter job (list below)
  missing-screens.md     one table
  mockups/<id>.html      one per must-have missing screen; mockups/bru-tokens.css generated from code; mockups/<id>-<390|440>-<light|dark>.png beside each HTML
  audit.md               rows D-01.. sorted by severity + Patterns section; audit/evidence/ holds full-size crops
  tools/                 DesignTourUITests.swift.txt, tour_run.sh, tour_export.py, tokens_to_css.py, render_mockups.sh, check_map.py, check.sh, puppeteer.json
  changelog.md           newest first, one entry per iteration
```

The context-map "capacity as code" has no analogue here; the runnable artefacts are `tools/check_map.py` and `tools/check.sh`.

## Capture pipeline

### Setup (stage S0)

1. The branch exists; confirm `git status` is clean and `HEAD` is on `design/workflow-map`.
2. Private copy: `git worktree add --detach "$SCRATCH/fitbod-design-tour" <base sha>`; `tour_run.sh` copies `tools/DesignTourUITests.swift.txt` to `<copy>/fitbodUITests/DesignTourUITests.swift` on every run and recreates the worktree if it is missing.
   Nothing in the copy is ever committed; it is removed with `git worktree remove --force` at the end.
3. Simulators: `xcrun simctl create "design-iPhone 17e" com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-26-5` and the same for `iPhone-17-Pro-Max`; boot one at a time, `bootstatus -b`, status bar override (`--time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`), appearance light, default content size.
4. Build once: `xcodebuild build-for-testing -project <copy>/fitbod.xcodeproj -scheme fitbod -configuration Debug -derivedDataPath ~/Library/Developer/Xcode/DerivedData/fitbod-design -destination "generic/platform=iOS Simulator" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO`.
   Rebuild after every edit of the tour file.
5. Ten-minute smoke of the untested tools before writing the tour: mermaid-cli with `tools/puppeteer.json` (`{"executablePath": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}` and `PUPPETEER_SKIP_DOWNLOAD=1`; if Chrome refuses, let puppeteer download its Chromium once), Chrome headless rendering of a `file://...?theme=dark&w=390` page, and a first `test-without-building` run on the 17e.

### Tour test design (one file, two classes)

- `enum DesignTour` helpers: `textSize` from env `DESIGN_TEXTSIZE` (`default` | `ax3`), `appearance` from env `DESIGN_APPEARANCE` (`light` | `dark`, naming only), `phone` from the screenshot width (390 = `17e`, 440 = `17promax`); `launch(args, ready:)` wraps `UITestNavigation.launch` then waits up to 30 s for a seed-created element and samples a tab cell colour once to assert the device appearance matches the env; `shot(app, screen)` waits until still, attaches a keepAlways screenshot named `<phone>-<size>-<appearance>-<screen>` and, when env `DESIGN_TREES=1`, a text attachment `<same>.tree` holding `app.debugDescription`; `dismissDialog` taps the cancel-role alert button by label or, for confirmation dialogs (iOS 26 hides `.cancel`), the dimmed area.
  Env reaches the runner through xcodebuild's `TEST_RUNNER_` prefix.
- `DesignTourMainUITests`: the main state of every screen (the T46 33 plus the sheets and dialogs that have a main state), 7 tests by tab; runs in every configuration.
- `DesignTourStatesUITests`: one test per seed walk W01-W16 below; runs in light/default only.
- Both: `continueAfterFailure = true`, every capture inside `XCTContext.runActivity`, `-test-timeouts-enabled YES -default-test-execution-time-allowance 600` (300 for the AX3 session editor step so the known T115 hang costs one test, not the run); each test launches fresh so no test depends on another; the tour asserts only that each screen appeared and changes no behaviour.
- Dialogs stay until dismissed: wait for `app.alerts.firstMatch` or `app.sheets.firstMatch`, shoot, dismiss.
  Toasts and banners (phase-deleted undo, PR banner 5 s, bump banner): 2 s existence wait, immediate shot.
  System UI (share sheet, document picker, photo picker): shoot the whole screen, then `app.terminate()` to end the walk.
  Destructive confirmations (End block, Discard) are taken only at the end of a walk.
  The "Preparing library…" splash is shot right after a reset launch without waiting for the tab bar (best effort).

### State matrix (seed walk -> screens and states)

Every walk starts with `-fitbod-reset-store`.
Labels marked "verify" are confirmed from the first run's tree dumps.

| Walk | Extra args | Ready element | Captures |
|---|---|---|---|
| W01 fresh | none | tab `Today` | today--empty, program--empty + templates, progress--empty, history--empty, library, library--filtered, filter-picker (muscle, equipment, mechanic), library--no-matches, exercise-detail (not logged), exercise-history--empty, custom-exercise--new (prefilled from search), custom-exercise--validation-error, muscle-picker, equipment-picker, photos-picker, dialog-custom-exercise-discard, custom exercise detail, Edit, dialog-delete-exercise |
| W02 settings | none | tab `Today` | settings (all rows, kg relabel), plate-inventory, add-plate, dialog-reset-plate-inventory, plate-calculator (via "•••"), volume-targets, dialog-reset-volume-targets, component-gallery, share-sheet (export, backup), file-importer (restore); ends with terminate |
| W03 demo | `-fitbod-seed-demo-workout` | `resumeSlab.resume` | today--resume, dialog-discard-workout-slab (after one logged set), history, workout-summary (history), logger with PREVIOUS, warm-up ramp, warm-ups skipped + undo, set-type menu, weight cell + plate stack disclosure, why-this-weight, decimal-rpe-picker, per-set-note, pinned-note capsule + sheet, workout-notes, dialog-workout-menu, swap-exercise, library-picker (add exercise; two-header check), dialog-remove-exercise, logger--set-logged, rest-timer dock RESTING and REST COMPLETE (minus 15 s taps), rest-timer expanded, PR banner, dialog-finish-workout, workout-summary--after-finish, program--resume-banner + dialog-discard-active, dialog-workout-in-progress (start another from the picker), session-template-detail "Last done", progress Recent, exercise-progress, exercise-history + intent empty, exercise-detail recent performance, weekly-tonnage 1 week; relaunch without reset for the resume journey |
| W04 stalled | `-fitbod-seed-stalled-exercise` | STALLED badge | logger--stalled, suggested chip ADD VOLUME, logger--add-volume |
| W05 calibrating | `-fitbod-seed-calibrating-set` | calibrating range | logger--calibrating, why-this-weight--calibrating |
| W06 counts | `-fitbod-seed-empty-between` (and `-empty-today` if Compare needs it) | sessions count | today--streak, history--with-empty, workout-summary--empty, compare |
| W07 recap | `-fitbod-seed-recap-with-empty -fitbod-start-program` | Program tab selected | tap Today: weekly-recap, today--recap-seen |
| W08 active block | `-fitbod-seed-active-block` | "Live Block" | today--active-block (band, black slab, lift list, W1/4 strip), block-overview--active, routine-editor + session-editor with LiveEditBanner, program--active, EDIT from Today (sheet) and from Program (cover), new-block--edit, phase editor, dialog-end-block, block-overview--completed with archive, block-review (not-enough-sessions), Plan custom silent dismiss, Start next -> nested new-block |
| W09 ended block | `-fitbod-seed-ended-block-recap -fitbod-start-program` | Program tab selected | tap Today: block-review, then weekly-recap--after-review, program DONE card |
| W10 block states | `-fitbod-seed-block-states` | "States Routine" | program--states, block-overview--ready / --draft, swap-confirm ("Start Block?"), split-picker (attach routine), fixed-weekly training days, today scheduled session, dialog-cannot-archive-routine |
| W11 past plan | `-fitbod-seed-block-states-past-plan` | "PLAN COMPLETE" | today band, program card, block-overview--plan-complete |
| W12 powerbuilding | `-fitbod-seed-powerbuilding` | long block name | program--long-name, block-overview--long-name, routine screens, dialog-remove-session |
| W13 progress | `-fitbod-seed-progress-history` | `progress.history` | progress, exercise-progress with all metric chips and e1RM caption, prs + intent toggle, pr-session placeholder (dead end, swipe back), volume, per-muscle-detail (heatmap tap, edit targets), exercise-detail--with-history, exercise-history |
| W14 tonnage | `-fitbod-seed-weekly-tonnage 8` | `weeklyTonnage.chart` | weekly-tonnage + chips (block phase empty), week-detail (rows not tappable), history spark card |
| W15 routines | none | tab `Program` | new-routine, routine-editor--new, slot-picker, session-editor (validation states), library-picker--from-editor + search, prescription rows, warmup-config, superset-assignment, dialog-session-menu, dialog-archive-session, dialog-discard-changes-session, dialog-save-routine-first (verify), dialog-remove-session, dialog-archive-routine, archived-routines + Restore, session-template-detail empty and populated, Start workout -> logger with no previous data, dialog-finish at 0 sets, dialog-discard at 0 sets |
| W16 blocks | none | tab `Program` | start-choice, preset-picker, new-block--from-program (cover, NAME FIRST gate and each bottom-bar gate), new-block-template, new-block-duration, new-block-add-phase-type, new-block-phase-editor, new-block-split-picker, dialog-replace-phases, dialog-discard-block, phase delete + undo toast, SAVE DRAFT, SAVE AS READY, a block whose first phase is Deload started from the UI -> today--deload-week banner; from Today: new-block--from-today (sheet) |

States no seed shows and no cheap UI path reaches go into `assumptions.md` and the final report as "not captured": DeloadAdvisoryBanner and the Fatigue Signals sheet from Today (needs three finished sessions with a signal), the stalled chips DROP INTENSITY, TRY VARIATION and CONSIDER DELOAD (zone-dependent), "ALL HISTORY" expansion (four done blocks), Block Review with e1RM deltas, archive-unreadable state, seed-failure state, restore success and error alerts (need a `.fitbodbackup` on the simulator; attempted through Save to Files, else code-only), the Live Activity.

### Runs, export, naming

Per phone, in order: (1) light/default, Main + States, trees on for the 17e; (2) dark/default, Main (17e only); (3) AX3/light, Main.
`tour_run.sh <17e|17promax> <default|ax3> <light|dark> <class>` resolves the udid by name with `simctl list -j`, boots, sets appearance and the status bar (a `trap` restores light and clears the override), does a warm-up install + launch like CI, runs `xcodebuild test-without-building ... -destination "platform=iOS Simulator,id=<udid>" -resultBundlePath <new path> -parallel-testing-enabled NO -only-testing:fitbodUITests/<class>` with the `TEST_RUNNER_DESIGN_*` env, then calls `tour_export.py`.
`tour_export.py` (modelled on `scripts/ci/collect_evidence.py`) exports attachments, renames by `suggestedHumanReadableName` with the `_<n>_<UUID>` suffix stripped, writes PNGs through `sips -s format png -Z 1700` into `screens/img/`, keeps full-size copies in the scratchpad, and trims `.tree` text to the element subtree into `screens/tree/`.
Later exports overwrite earlier ones, so one method can be rerun with `-only-testing:fitbodUITests/DesignTourStatesUITests/testW15Routines`.
One simulator job runs at a time; the chain runs in the background while documents are written.

## Doc templates

### `screens/<id>.md`

Front matter (plain `key: value` and `[a, b]` lists, parsed without PyYAML): `id`, `kind` (screen | sheet | cover | dialog | alert | system), `title`, `view` (path:line), `tab`, `presents_from` (ids), `closes_with` (back | cancel | done | close | verb | none), `mock` (path or none), `seed`, `captured` (date and sha), `img` (list), `tree`.
Body: one sentence on what the lifter does here; `## Entry points` (From, Tap, Kind); `## Exits` (Control, Goes to, Kind, Closes with); `## States` (State, Reach it, Screenshot); `## Compared with the mock-up` (In the mock-up, In the app, Difference); `## VoiceOver order` (3-8 lines from the tree, then gaps); `## Findings` (links to audit rows).
AX3 and dark images are listed where the layout changes; otherwise one line says they were checked and only colour and size change.
Dialog files use the same front matter plus `message` and `buttons`, with sections Trigger, Buttons, Copy check, Screenshot, Findings.

### `workflows/<job>.md`

Front matter: `id`, `job`, `start`, `end`, `taps_min`, `screens` (ids).
Body: `## Steps` numbered from the lifter's point of view with the screen id per step; `## Flow` Mermaid flowchart reusing screen ids (`q_` prefix for decisions); `## Tap count` table; `## Dead ends`; `## Detours`; `## No clear way back`; `## Findings`.
The 11 files: first-launch-to-first-workout, build-a-session-and-its-prescription, build-a-routine, run-a-block (create, start, run, swap, end, every phase, deload), today (planned, ad-hoc, skip, resume), log-a-workout (warm-ups, sets, RPE, rest, swaps, notes, finish, stall and deload chips), review-a-workout-and-edit-history, check-progress (charts, PRs, tonnage, volume, heatmap, plateaus, weekly recap), find-and-create-exercises, plates-and-the-calculator, settings-units-backup-restore-export.

### `missing-screens.md`

One table: `id | Screen or state | Workflow that needs it | Must show | Entered from | Importance (must / should / nice) | Source`.
Rows: all-recaps (past recaps list), pr-session detail, block-review reopen and export target, plan-custom acknowledgment, week-detail row destination, try-variation result, live-activity resume target, deload advisory from Today, new-folder and move-routine (built but unreachable), the Milestone 1 removals (Off-Season and Pre-Meet presets, EDIT BLOCK top SAVE, Plate Inventory SAVE INVENTORY, plate calculator "•••" / Save / Done), the four open product decisions framed as the choice a screen must make (first-log PRs, deload misses, "muscle sets" wording, "per week" adherence), plus whatever the workflows surface (expected: history editing, a plate calculator reachable from the logger, week-start and deload-alert settings).
Must-haves get a mock-up; the final list is decided after the workflows are written.

### `audit.md`

`| ID | Screen | Problem | Evidence | Severity | Ticket |`, sorted blocker, major, minor, polish, then screen; evidence is a screenshot path plus file:line where known; open-ticket problems get one row that links the ticket and does not re-describe it.
`## Patterns` follows: `### P-n <rule broken>` with the design-system rule, the rows it groups and the one fix.

### `README.md`, `assumptions.md`, `changelog.md`

README: as-of line, pointer table, `## Summary` with at most ten sentences covering the biggest workflow problems, the most important missing screens and the top audit patterns.
`assumptions.md`: base commit, capture dates (DST ends 2026-11-01), phones and runtime, seeds per walk, states not captured, tickets whose merges will change screens (T110 and later), the glossary used.
`changelog.md`: newest first, one entry per stage.

## Mermaid conventions and the checks

- Node id = screens file stem with `-` replaced by `_`; never a Mermaid keyword.
- Shapes: screen `id["Title"]`, sheet or cover `id(["Title"])`, dialog or alert `id{{"Title?"}}`, system UI `id[["Share sheet"]]`.
- Edges: `-->` push, `-.->` sheet, cover, dialog or system presentation.
  Each tab is a `subgraph tab_<name>`; tab switches are not edges.
  Prefixes `tab_`, `q_` and `x_` (outside the app: launch argument, Live Activity) are exempt from the file check.
- `tools/check_map.py` (run with `python3 -I`, exit 1 on error): node ids across `navigation.md` must equal the `screens/*.md` stems and vice versa; edges must match the union of each file's `presents_from`; every id in `workflows/` diagrams and `screens:` lists must exist; every `img`, `tree`, `mock` path and every Markdown image link must resolve; unreferenced PNGs are warnings; audit rows are `D-NN` without gaps and sorted by severity; ticket links resolve under `docs/conway-specs/tickets/`; `--mmd-out DIR` extracts every Mermaid block.
- `tools/check.sh`: runs the script, then renders each extracted block with `PUPPETEER_SKIP_DOWNLOAD=1 npx -y @mermaid-js/mermaid-cli -p tools/puppeteer.json -i x.mmd -o x.svg`.
  SVGs are not committed.

## Mock-up pipeline

- `tools/tokens_to_css.py` reads `fitbod/Assets.xcassets/bru*.colorset/Contents.json` the way `docs/design-system/tokens_check.py` does, plus the type roles from `BRUFont.swift` and the metrics from `BRUMetrics.swift`, and writes `mockups/bru-tokens.css`: `:root` light tokens, dark tokens under both `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }` and `:root[data-theme="dark"]`, spacing 4/8/12/16/24/32, borders 1/1.5/2, radius 0, touch 44, primary action 52, `@font-face` for the six TTFs at `../../../fitbod/Resources/Fonts/`, one class per type role.
- Each `mockups/<id>.html` links the CSS, reads `theme` and `w` from the query string, sets `data-theme` and the phone width (390 or 440) and height (844 or 956), and draws the BRU header, content and tab bar with one signal accent, square corners and uppercase via CSS.
  Each is based on the nearest existing screen's screenshot.
- `tools/render_mockups.sh` renders four PNGs per HTML with Chrome headless (`--headless --disable-gpu --hide-scrollbars --user-data-dir=$(mktemp -d) --force-device-scale-factor=2 --window-size=390,844 --virtual-time-budget=2000 --screenshot=...`), looping over 390x844 and 440x956, light and dark; Playwright's cached CLI is the fallback.

## Audit method

- Visual: look at every committed screenshot at full size and measure from the full-size originals and tree frames (touch targets, alignment, truncation, mid-word breaks, clipping on the 17e); run `python3 docs/design-system/tokens_check.py` for contrast.
- Consistency: compare action names, placement and styles across the screen files (headers, empty states, confirmations, close controls per the design-system rules).
- Accessibility: AX3 captures, 44pt targets from tree frames, VoiceOver labels and order from the trees, Reduce Motion from code (`accessibilityReduceMotion`, `.animation`) with a spot check through the simulator Settings app if cheap.
- Copy: glossary rule, units, plurals, stale references.
- Flow: the dead ends and detours from the workflows.

## Work order, checkpoints and commits

| Stage | Work | Commit | Time |
|---|---|---|---|
| S0 | Worktree, simulators, build, tool smoke; scaffold README table, assumptions, changelog, `tools/` scripts, `screens/` front-matter skeletons for all ids (generated by a throwaway script) | 1 `docs(design-map): scaffold index, assumptions, checks and screen inventory` | 1-2 h |
| S1 | `DesignTourMainUITests` + helpers, `tour_run.sh`, `tour_export.py`; smoke on the 17e light/default until green; fix "verify" labels from the trees | 2 `docs(design-map): add the screenshot tour and export tools` | 4 h |
| S2 | `DesignTourStatesUITests` W01-W16 on the 17e light/default; fix flakes; note misses | 3 `docs(design-map): capture iPhone 17e light default` | 4 h |
| S3 | Background chain: 17e dark Main, 17e AX3 Main, Pro Max light Main + States, Pro Max AX3 Main. Foreground: `navigation.md`, Today and Program screen files | 4 `...capture 17e dark and AX3`, 5 `...capture iPhone 17 Pro Max`, 6 `...navigation map and Today screens`, 7 `...Program screens` | 1.5 h sim, 6 h writing |
| S4 | Progress, Library, Settings, system and dialog screen files; look at every PNG once and keep audit notes | 8 `...Progress and Library screens`, 9 `...Settings, system UI and dialogs` | 6 h |
| S5 | `workflows/` (11 files) | 10 `docs(design-map): workflows` | 4 h |
| S6 | `missing-screens.md`, decide must-haves, mock-ups, render | 11 `docs(design-map): missing screens and mock-ups` | 4 h |
| S7 | `audit.md` from the notes, trees and tickets; patterns | 12 `docs(design-map): audit` | 3-4 h |
| S8 | README summary, changelog, `tools/check.sh` green, simulators back to light and default size, worktree removed | 13 `docs(design-map): summary, changelog and final check` | 1 h |

About 33 hours of work, less with subagents on S3 to S6.
Every commit from 6 onward passes `tools/check.sh`.
Commit messages are conventional (`docs(design-map): ...`) with no co-author line.
If time runs short, the cheapest cut is S2's states class, keeping the main screens only; the user is told before any cut.

## Verification

- `python3 -I docs/design-map/tools/check_map.py` exits 0 and its output (ids vs files, image links) goes into the final report.
- `tools/check.sh` renders every Mermaid block with mermaid-cli without error.
- `git diff --stat origin/main..design/workflow-map` touches only `docs/design-map/`; `git status` is clean; `gitnexus_detect_changes()` runs before the final commit for form's sake.
- Both simulators report `appearance light` and default content size; the status bar override is cleared; the private worktree is removed.
- Final report: branch and commit, counts (screens, workflows, missing screens, audit findings), the summary, the check script output, the list of states no seed could show, and the screens that T110 will change after merge.
- Ask the user before pushing the branch.

## Risks and mitigations

- Seeds finish after the tab bar: every walk waits on a seed-created element, never sleeps.
- DST ends 2026-11-01 and seeds use `Date.now` with 24 h steps: run both phones on the same calendar day where possible, record capture dates, recapture W06 and W07 together if weekday-relative states shift, and treat shifts as seed arithmetic, not app defects.
- Transient dialogs and toasts: modal dialogs stay; toasts get a 2 s wait and an immediate shot; `continueAfterFailure` keeps the walk going.
- Flaky steps (first-character drop, animating sheets): reuse `type`, `waitUntilStill`, `hittable`, `swipeSheetDown`; rerun one method and let the export overwrite by name.
- AX3 editor hang (T115): 300 s allowance on that test; capture the editor top without scrolling at AX3.
- First launch on a fresh simulator times out: warm-up install and launch in `tour_run.sh`, as CI does.
- Repo size: 2x PNGs only, trimmed trees once per screen, no composites, no SVGs; full-size originals stay in the scratchpad.
- Teammate tickets change screens after merge: `captured: <date> <sha>` in every file; file names match T46 so the teammate's tour can replace images one for one.
- mermaid-cli cannot drive the installed Chrome: allow the one-time Chromium download.
- Orca computer-use is unverified for iOS elements: not relied on; `simctl io screenshot` is the manual fallback for anything the tour cannot drive.
- Subagents drift on copy or ids: each gets one leaf, the template, the glossary and the check script; the parent reviews every leaf against `check_map.py` output before committing.

## Out of scope

- Fixing anything found (recorded in the audit instead).
- Editing any ticket, CLAUDE.md, the design-system docs or `bru-screens/`.
- Widget and Live Activity screenshots beyond what the simulator shows.
