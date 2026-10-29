# Milestone 1 verification — 2026-10-05

**Acceptance is still open.** The full unit suite passed apart from one known
SwiftData issue. The latest complete UI run has four failures; source fixes
are prepared but have not been rerun. The full authored journey at large text
has not passed on both required phones. Nothing has been committed or pushed
by this continuation.

See [the closeout report](MILESTONE-1-CLOSEOUT.md) for all product/release flags,
[the requirement audit](MILESTONE-1-AUDIT.md) for coverage, and
[the historical baseline](verification/BASELINE-20261003.md) for October 3 results.
Historical passes do not establish that the latest source passes.

## Environment and acceptance results

Xcode 26.5 (17F42), iOS 26.5 Simulator (23F77), macOS 26.4.1; scheme `fitbod`,
Debug, signing disabled. The minimum deployment target remains iOS 26.4.

| Dedicated phone | Size | UUID |
| --- | --- | --- |
| iPhone 17e | 390 × 844pt | `777198FC-2973-4310-9F3B-831A92847600` |
| iPhone 17 Pro Max | 440 × 956pt | `130E99EC-D1D1-4D2E-839D-CE58AF3FA629` |

Bundles and logs below are under `/private/tmp/`. JSON summaries copied into
[`verification/closeout/`](verification/closeout/) retain exact counts.

| Check | Evidence | Observed result |
| --- | --- | --- |
| Full unit and UI suite, 17 Pro Max, default text/light | `fitbod-m1-closeout-full-02.xcresult` | **973 unit identifiers passed, 1 expected failure. UI: 48 identifiers passed, 4 failed.** Repeated launch configurations produce 51 passing UI invocations out of 55. App and widget built. |
| Earlier unit + six logger journeys | `fitbod-m1-closeout-units-logger-01.xcresult` | **976 passed, 1 expected failure, 0 unexpected failures:** 970 unit cases plus six logger cases, before later additions. |
| 17e, AX3/light, History/Today + gallery + logger layout | `fitbod-m1-closeout-17e-ax3-06.xcresult` | **4 passed, 1 failed.** Both History/Today tests, gallery and logger layout passed; authored journey failed. |
| 17e, AX3/light, swap | `fitbod-m1-closeout-17e-ax3-04.xcresult` | Swap passed; the other case, authored journey, failed. |
| Latest 17e AX3 authored attempt | `fitbod-m1-closeout-17e-ax3-08.log` and `.xcresult` | Failed: max-reps input became `106` instead of `10`. It reached prescription editing after the scroll-layout fix. Summary regeneration is blocked by the current sandbox's TestReport cache restriction; the saved log establishes the failure. |
| 17 Pro Max AX3 full authored journey | No current passing run | **Pending.** Older AX3 logger/gallery captures cover only those surfaces. |
| Final Swift syntax / documentation | `swiftc -frontend -parse` for the three final Swift edits; link and asset checks | Syntax passes; 106 relative Markdown links and all report assets resolve. This is not a compile or simulator pass. |
| Contrast and whitespace | `tokens_check.py`; `git diff --check`, rerun October 5 | All **19 token pairs** pass in light and dark; whitespace check passes. Token checks are not a pixel audit of every screen. |
| GitNexus `detect_changes(scope: all)` | [Scope report](verification/closeout/gitnexus-detect-changes.json) | **667 changed symbols, 75 affected flows, 128 changed files, CRITICAL** in the shared worktree. Includes excluded paths; not a staged-commit check. |

The full bundle's top-level summary is **1,021 passed, 4 failed, 1 expected
failure, 0 skipped**, across 1,026 test identifiers. The device-level count
also expands parameterized cases; it must not be added to the top-level count.
`xcresulttool get test-results tests` identifies the unit/UI split above.

## Four UI failures and prepared corrections

1. `MilestoneOneJourneyUITests.testAuthorRoutineLogRelaunchFinishAndHistory`:
   double-tapping did not select a numeric value, leaving `106` instead of `10`.
   The helper now places the caret at the end and sends deletion plus replacement
   in one typing call. Weight assertions account for the accessible unit suffix.
2. `SessionLoggerBRUUITests.testBRUHeaderBarMenuActionsAccessibleInActiveSession`:
   menu actions were present, but its presentation exposed no Cancel button.
   The test now selects Workout notes and requires its editor to appear.
3. `WhyThisWeightSheetBRUUITests.testWhyThisWeightHeroSlabAppearsAfterLongPress`.
4. `WhyThisWeightSheetBRUUITests.testWhyThisWeightSectionHeadVisible`.
   Both explanation tests focused the numeric editor without opening the sheet.
   The weight cell now observes a simultaneous long press, clears field focus,
   and offers a named accessibility action. Both real sheet assertions remain.

**These corrections are unverified.** The sandboxed rerun
`fitbod-m1-closeout-sandbox-01.log` exited 70 before executing tests because
CoreSimulator was unavailable. A generic build also failed when the sandbox
prevented the Swift macro plugin server from running. Its diagnostics include
`sandbox-exec: sandbox_apply: Operation not permitted`; this is not a passing
build or evidence of a new source-level compile failure.

## Persistence, snapshots and timers

The completed full unit run includes:

- `MilestoneOnePersistenceTests`: release disk-backed containers and reopen
  SQLite, retaining completed **80 × 8** and unfinished **82.5 × 6** sets. After
  finishing and changing source names/targets, historical **3 × 5–8 / 180s**
  prescriptions and **640** working volume stay frozen.
- `PreviousPerformanceExclusionTests`: current and other unfinished workouts
  cannot replace previous completed performance (C9).
- `SessionSnapshotFidelityTests` and `SessionBlockSnapshotTests`: names,
  prescriptions and block configuration are workout snapshots (C10).
- `RestTimerEngineTests` and `RestTimerPersistenceTests`: absolute deadlines,
  adjustment, restoration, expiry and session isolation.
- Bodyweight/loaded-set completion validation, session summary, export and
  store recovery suites.

The one expected failure is
`ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement`.
It deliberately records a known issue without executing a SwiftData delete
that can abort the process. Schema metadata is checked separately. **Runtime
hard-delete refusal is not proven.**

## Screenshots inspected

These are native simulator captures, not mockups. The October 5 AX3 crop shows
Chest **8 sets** and Forearms **0 sets** on a common axis, readable ADD A SET and
NOT TRAINED labels, and full threshold captions without collisions.

| Capture | Evidence |
| --- | --- |
| Trained/untrained volume crop, 17e AX3/light | [Volume rows](verification/closeout/iphone-17e-ax3-volume-rows-crop.png) |
| Settings header, complete tab names and stacked Today statistics | [Today](verification/closeout/iphone-17e-ax3-today.png) |
| Stacked inputs and completed target checks | [Logger](verification/closeout/iphone-17e-ax3-logger.png) |
| Expanded timer | [Rest timer](verification/closeout/iphone-17e-ax3-expanded-rest.png) |
| Working gallery controls | [Gallery](verification/closeout/iphone-17e-ax3-gallery-actions.png) |
| Native 1024px icon | [Icon](../fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png) |

The older default-text `iphone-17e-volume-rows-crop.png` predates the shared-axis
fix and is historical. Earlier screenshots in `verification/` retain their
October 3 baseline provenance.

## Reproduce the remaining checks

Use the dedicated devices. UI tests reset their initial store; relaunch checks
intentionally omit reset. Do not use a personal-data simulator.

```sh
# Full suite, default text on the large phone.
xcrun simctl ui 130E99EC-D1D1-4D2E-839D-CE58AF3FA629 content_size large
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,id=130E99EC-D1D1-4D2E-839D-CE58AF3FA629' \
  -derivedDataPath /private/tmp/fitbod-m1-closeout-full \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/fitbod-m1-closeout-full-03.xcresult \
  test CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO

# Repeat this block with each required phone UUID.
xcrun simctl ui SIMULATOR_ID content_size accessibility-extra-large
xcrun simctl ui SIMULATOR_ID appearance light
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -derivedDataPath /private/tmp/fitbod-m1-closeout \
  -parallel-testing-enabled NO \
  -only-testing:fitbodUITests/MilestoneOneJourneyUITests \
  -only-testing:fitbodUITests/HistoryAndTodayUITests \
  -only-testing:fitbodUITests/WorkoutSwapJourneyUITests \
  -resultBundlePath /private/tmp/fitbod-m1-DEVICE-ax3-final.xcresult \
  test CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO

python3 docs/design-system/tokens_check.py
git diff --check
npx gitnexus analyze
# Then run GitNexus detect_changes for each exact staged commit group.
```

`accessibility-extra-large` is SwiftUI `.accessibility3`. Full authored journey
means library filters/custom exercise → routine/session authoring and editing
→ reordered exercises → logging/add/delete → rest/relaunch → finish/history
→ Previous on the next workout. Passing only logger/gallery is insufficient.

## Environment restrictions and repository state

The current session permits workspace writes but makes `.git` read-only and
blocks simulator services; approval escalation is unavailable. GitNexus refresh
`fitbod-m1-closeout-index-06.log` reached a denied write to
`~/.gitnexus/registry.json`. Index 05 is the last completed refresh. The subsequent
MCP change scan returned the scope above; refresh and staged scans must be
repeated before committing.

Seven commit groups are prepared as exact-path manifests (303 task-owned paths,
847 excluded paths). The first exact-path staging attempt failed with
`Unable to create .git/index.lock: Operation not permitted`; the index remains
empty. No commits or push were made. Finish in a session with normal Xcode/CoreSimulator, Git registry and
repository metadata access, rerun the checks above, inspect each staged diff,
run GitNexus `detect_changes(scope: staged)`, and push the already-authorized
`main` only after the results are recorded. Preserve excluded worktree changes.

The portable [BRU closeout review](../.lavish/milestone-1-closeout.html) contains
the screenshots and all 18 product/release flags. Its JavaScript syntax and
local assets pass static checks. Lavish open and poll returned `SERVER_ERROR`;
no live review URL or browser layout validation is claimed.
