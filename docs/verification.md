# Verification — milestone 1

How milestone 1 was verified, what passed, and what could not be checked.
The raw evidence (test summary + screenshots) produced by CI lives in
[`verification/ci/`](verification/ci/).

## Environment

The development agent runs on Linux without Xcode, so every native check
ran on GitHub-hosted macOS runners via `.github/workflows/ios.yml`
(`scripts/ci/ios-ci.sh`):

| | |
|---|---|
| Xcode | 26.6 (17F113); app target in Swift 6 language mode with complete concurrency checking |
| Simulator runtime | iOS 26.5 |
| Small iPhone | iPhone SE (3rd generation) — 375 × 667 pt |
| Large iPhone | iPhone 17 Pro Max — 440 × 956 pt |
| Build | `xcodebuild build-for-testing` (Debug, simulator, arm64) |

Each test step boots its own simulator, shuts the other one down, waits
for the boot to finish and launches the app once outside XCTest (a freshly
created simulator's first launch can otherwise outlast XCUITest's launch
timeout) before `xcodebuild` runs. If no test starts at all
(the simulator was not found or was lost before the first test), the step
is retried once on a freshly booted simulator; a failing test is never
retried. Screenshots are committed to `verification/ci/` only from runs in
which the build and every test step passed.

Local syntax checks used `scripts/dev/swift_syntax_check.py` (tree-sitter);
they are not a substitute for the compiler and were only used between CI
runs.

## Results

From the CI run recorded in [`verification/ci/RUN_URL`](verification/ci/RUN_URL)
(app commit in [`verification/ci/COMMIT`](verification/ci/COMMIT); full list
of test cases in [`verification/ci/summary.md`](verification/ci/summary.md)):

| Check | Result |
|---|---|
| Native build (`xcodebuild build-for-testing`, Xcode 26.6, iOS 26.5 simulator SDK) | **Succeeded** |
| Unit + persistence tests (Swift Testing) | **275 / 275 passed** |
| UI tests on iPhone 17 Pro Max (journey + 3 layout tours) | **4 / 4 passed** |
| UI tests on iPhone SE 3rd gen (journey + 3 layout tours) | **4 / 4 passed** |

The end-to-end journey (`WorkoutJourneyUITests`) passed on both devices,
including the step that **terminates the app mid-workout and relaunches
it**: the workout reopened automatically with both completed sets, the
typed weight and the running rest timer (J14).

Before milestone 1 the base branch had 8 failing unit tests out of 244
(stale schema assertions, tests running V2 entities on a V1 container, a
copy test pointing at removed views, an order-dependent seed check, and a
test mirror that had drifted from production). All were fixed at the root;
none were skipped or disabled.

### Issues the screenshots caught (fixed before the final run)

| Found in | Problem | Fix |
|---|---|---|
| iPhone SE | Set rows stacked even at default text (row needed 320 pt, got 311) | Tighter set-table row insets |
| iPhone SE | "PREVIOUS" column label truncated | Falls back to "PREV" |
| iPhone SE | Rest dock covered the row being typed into | Dock steps aside while a field is focused |
| Both | Builder/editor labels and banners clipped by iOS 26's rounded section mask | `chalkBareListRow()` insets |
| Both | Library large title hidden by the sticky header's background | Header background limited to its own frame |
| Both | Equipment chips truncated in the custom-exercise editor | Two-column grid, chips may shrink slightly |
| Both | Logging set 2 meant retyping the weight | Logged weight carries into later empty sets |

## Screenshots

Exported from the XCUITest runs (`ui-small` = iPhone SE 3rd gen, `ui-large`
= iPhone 17 Pro Max). `J…` = the end-to-end journey on a fresh install;
`A…` = demo-data tour at default text; `B-ax…` = Accessibility L text;
`C-dark…` = dark mode at XXXL text.

| Step | iPhone SE | iPhone 17 Pro Max |
|---|---|---|
| Library search | [J01](verification/ci/ui-small/J01-library-search.png) | [J01](verification/ci/ui-large/J01-library-search.png) |
| Library filtered (Chest · Barbell) | [J02](verification/ci/ui-small/J02-library-filtered.png) | [J02](verification/ci/ui-large/J02-library-filtered.png) |
| Exercise detail | [J03](verification/ci/ui-small/J03-exercise-detail.png) | [J03](verification/ci/ui-large/J03-exercise-detail.png) |
| No match → create | [J04](verification/ci/ui-small/J04-library-no-match.png) | [J04](verification/ci/ui-large/J04-library-no-match.png) |
| Custom exercise validation error | [J05](verification/ci/ui-small/J05-custom-exercise-validation.png) | [J05](verification/ci/ui-large/J05-custom-exercise-validation.png) |
| Routines empty | [J07](verification/ci/ui-small/J07-routines-empty.png) | [J07](verification/ci/ui-large/J07-routines-empty.png) |
| Routine builder validation error | [J08](verification/ci/ui-small/J08-routine-validation.png) | [J08](verification/ci/ui-large/J08-routine-validation.png) |
| Routine builder editing | [J09](verification/ci/ui-small/J09-routine-builder.png) | [J09](verification/ci/ui-large/J09-routine-builder.png) |
| Workout started | [J11](verification/ci/ui-small/J11-workout-start.png) | [J11](verification/ci/ui-large/J11-workout-start.png) |
| Set logged + rest timer | [J12](verification/ci/ui-small/J12-set-logged-rest-timer.png) | [J12](verification/ci/ui-large/J12-set-logged-rest-timer.png) |
| Set validation error | [J13](verification/ci/ui-small/J13-set-validation-error.png) | [J13](verification/ci/ui-large/J13-set-validation-error.png) |
| **After terminate + relaunch** | [J14](verification/ci/ui-small/J14-relaunch-resumed.png) | [J14](verification/ci/ui-large/J14-relaunch-resumed.png) |
| Summary | [J15](verification/ci/ui-small/J15-summary.png) | [J15](verification/ci/ui-large/J15-summary.png) |
| History | [J16](verification/ci/ui-small/J16-history.png) | [J16](verification/ci/ui-large/J16-history.png) |
| History after routine rename | [J18](verification/ci/ui-small/J18-history-after-rename.png) | [J18](verification/ci/ui-large/J18-history-after-rename.png) |
| Previous performance offered | [J19](verification/ci/ui-small/J19-previous-performance.png) | [J19](verification/ci/ui-large/J19-previous-performance.png) |
| Today with history | [A01](verification/ci/ui-small/A01-today.png) | [A01](verification/ci/ui-large/A01-today.png) |
| Workout set row (default text) | [A11](verification/ci/ui-small/A11-set-row-ready.png) | [A11](verification/ci/ui-large/A11-set-row-ready.png) |
| Rest dock / rest sheet | [A12](verification/ci/ui-small/A12-rest-dock.png) · [A13](verification/ci/ui-small/A13-rest-sheet.png) | [A12](verification/ci/ui-large/A12-rest-dock.png) · [A13](verification/ci/ui-large/A13-rest-sheet.png) |
| Workout at Accessibility L | [B-ax11](verification/ci/ui-small/B-ax11-set-row-ready.png) | [B-ax11](verification/ci/ui-large/B-ax11-set-row-ready.png) |
| Today at Accessibility L | [B-ax01](verification/ci/ui-small/B-ax01-today.png) | [B-ax01](verification/ci/ui-large/B-ax01-today.png) |
| Dark mode, XXXL text | [C-dark10](verification/ci/ui-small/C-dark10-workout.png) | [C-dark10](verification/ci/ui-large/C-dark10-workout.png) |
| Component gallery | [A09](verification/ci/ui-small/A09-gallery-1.png) | [A09](verification/ci/ui-large/A09-gallery-1.png) |

Every screenshot is in `verification/ci/ui-small/` and
`verification/ci/ui-large/`; `verification/ci/summary.md` lists every test
case and its result.

## What each check proves

| Requirement | Evidence |
|---|---|
| Native build | `Build for testing` step: the app (Swift 6 language mode, complete concurrency checking), the widget extension, and the unit and UI test bundles (Swift 5 mode, as configured in the project) all compile. |
| Library search / filter by muscle & equipment / detail | Journey steps J01–J03 (screenshots). |
| Custom exercise with validation | J04–J06: empty search → "Create “…”", Save with no muscle shows the error summary, then saves. |
| Routine create with ordered exercises + targets, validation | J07–J10. Prescription defaults and draft validation also unit-tested (`RoutineBuilderCopyTests.draftIssues`, `RoutineDraftValidationTests`). |
| Start workout, record weight/reps, validation, add/remove sets | J11–J13; `WorkoutLogicTests` (validation, add/delete, unplanned exercise). |
| Adjustable rest timer | J12 (+15), layout audit (dock + sheet); `RestTimerPersistenceTests` (presets, ±15 keep the original start). |
| **Resume after close/reopen** | J14: the test **terminates the app and relaunches it**; the workout reopens with both completed sets, the typed weight and the rest dock. `WorkoutPersistenceTests.workoutSurvivesRelaunch` reopens the on-disk store with a new container. |
| Rest timing from an absolute deadline | `RestTimerPersistenceTests`: relaunch 70 s later shows 110 s; past the deadline it shows overtime, not a reset; stale timers are dropped. |
| Finish → summary → history | J15–J17. |
| Snapshots (routine edits don't rewrite history) | J18 renames the routine; History keeps "Upper A". `WorkoutPersistenceTests.routineEditsNeverRewriteHistory` edits every prescription field and deletes the routine. |
| Previous performance | J19: next workout offers "225 × 5" and copies it. `WorkoutLogicTests.previousExcludesCurrentWorkout`. |
| Small & large iPhone, larger text, dark mode | `LayoutAuditUITests` on both devices: default text, Accessibility L, dark + XXXL; asserts set-row and rest controls are on screen and hittable. |
| Catalog refresh can't destroy data | `SeedTests.reseedPreservesUserData`. |

## Not verified here

- **Physical device:** haptics, the lock-screen notification and the Live
  Activity only fire on device; they were not exercised. The simulator runs
  use `-ui-testing`, which swaps in no-op notification/activity
  controllers.
- **VoiceOver end to end:** labels, values, traits and announcements are
  implemented and exercised indirectly by XCUITest queries (which use the
  same accessibility tree), but no manual VoiceOver pass was done.
- **Migration of an existing on-device store:** milestone 1 makes no schema
  changes, so the developer's current store opens unchanged; this was not
  tested against a copy of that store.
