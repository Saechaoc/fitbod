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
| Xcode | 26.6 (17F113), Swift 6 language mode, strict concurrency |
| Simulator runtime | iOS 26.5 |
| Small iPhone | iPhone SE (3rd generation) — 375 × 667 pt |
| Large iPhone | iPhone 17 Pro Max — 440 × 956 pt |
| Build | `xcodebuild build-for-testing` (Debug, simulator, arm64) |

Local syntax checks used `scripts/dev/swift_syntax_check.py` (tree-sitter);
they are not a substitute for the compiler and were only used between CI
runs.

## Results

_Filled in from the CI run recorded in `verification/ci/RUN_URL`._

<!-- RESULTS -->

## What each check proves

| Requirement | Evidence |
|---|---|
| Native build | `Build for testing` step: app, widget extension, unit and UI test bundles compile with Swift 6 strict concurrency. |
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
