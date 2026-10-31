---
id: T101
title: UI tests stop waiting a minute per step after typing
phase: 2
items: []
depends_on: []
size: L
sim: both
owns: [fitbodUITests/UITestNavigation.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, new:fitbodTests/EdgeSwipeBackGuardTests.swift]
---

# T101: UI tests stop waiting a minute per step after typing

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F144, from the second run of Gate 1.
After a UI test types into or taps a text field, the app sometimes never tells XCUITest that its animations have finished.
From then on, every step waits 60 seconds and logs "App animations complete notification not received, will attempt to continue." until the screen is popped or the app relaunches.
The tests still pass, but slowly.
In that gate run, `CustomExerciseEntryUITests` took 1006 seconds instead of 48 for testEditCancelsReopensAndSavesOverTheSameExercise.
`MilestoneOneJourneyUITests` took 2792 seconds instead of 161 for testAuthorRoutineLogRelaunchFinishAndHistory.
Phase 1 workers' logs show the same stall in 22 tests on both phones, most often in `NewBlockSavesUITests` testBottomActionNamesEachMissingPieceThenSavesAsReady.
During a stall the app uses no CPU, and its XCTest agent logs "Received request to notify when animations are idle" with no reply.
So some animation keeps running without the app's code drawing each frame.
In T24's runs, `BlockNameTypingUITests` testKeyTapsTypeTheWholeName took 1481 seconds instead of about 45, because each of its key taps waited a minute before and after.

T24's worker also found that `UITestNavigation.topSheet(in:)` returns nil for half-height sheets, which float 8pt above the bottom of the screen on iOS 26 and later.
So `swipeSheetDown(in:)` cannot find them either, which may explain the flaky sheet swipes of finding F135.

T18's review left two more test gaps:

- `EdgeSwipeBack.swift` overrides `viewDidLoad` in an extension of `UINavigationController`, which is safe only while UIKit's class has no `viewDidLoad` of its own, and no test checks that (finding F184).
- After `MilestoneOneJourneyUITests` swipes the logger's S3 set fully away, it checks for the row at once and then waits for a Delete button that a full swipe never leaves, so it fails when the check lands during the delete animation (finding F185).

## Target

- Whatever keeps an animation running after a text field edit, which change 1 finds.
- The shared launch helpers in `fitbodUITests/UITestNavigation.swift`, if the fix belongs in the UI test launches.

## Change

1. Find the animation that never ends.
   Add a temporary DEBUG-only probe, turned on by a launch flag, that logs every two seconds each layer in the app's windows that has animations.
   For each such layer, log its animation keys, its view's class, and each animation's duration and repeat count.
   Include the keyboard's windows and the text effects window.
   Run the stalling tests again and again until a stall happens, and keep the probe's lines from that stall.
2. Stop that animation from holding up UI tests, with the smallest change that works.
   If the app's own code starts it, fix that code, so the animation ends, or stops when its view is not on screen.
   If the system starts it, turn it off for UI test launches through the shared launch helpers, without changing what a user sees.
3. Remove the probe and its launch flag before your final commit.
4. In `notes.md`, name what kept animating, quote the probe lines that show it, and say why your change stops it.
5. `UITestNavigation.topSheet(in:)` also finds half-height sheets, which float 8pt above the bottom of the screen on iOS 26 and later, so `swipeSheetDown(in:)` can close them too (finding F171, from T24's worker).
6. `EdgeSwipeBackGuardTests` fails if `UINavigationController` ever gets a `viewDidLoad` of its own, which the extension's override would replace.
7. `MilestoneOneJourneyUITests` waits for a fully swiped set to disappear before it looks for a Delete button.

## Constraints

- No change that a user can see, unless the coordinator agrees.
- Every UI test keeps its assertions.
- If nothing you can change stops the animation, stop and report what the probe found, so the coordinator can decide.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.
The probe and its hook never reach your commit, so they need no grant.
If the fix needs an app file, ask for it, and name the cause the probe found.

## Repro first

- With the probe on, run `NewBlockSavesUITests` on the large phone again and again until a step logs "App animations complete notification not received", and save that run's log.
  If ten runs bring no stall, try `BlockNameTypingUITests`, `CustomExerciseEntryUITests` and `EditorSwipeDismissUITests`, which also stalled.
- In `UITestHelpersSelfTests`, open New Block's Edit Block Duration sheet and assert that `topSheet(in:)` finds it.
  It returns nil today.

## Observable acceptance

- `notes.md` names the animation that never ended and quotes the probe lines.
- After the fix, `NewBlockSavesUITests`, `CustomExerciseEntryUITests` and `EditorSwipeDismissUITests` run five times on each phone and pass each time.
- No log from those runs holds "App animations complete notification not received".
- `fitbodTests` passes on the large phone with only the known issue, and the app and the widget build.
- `UITestHelpersSelfTests` passes on both phones, including the half-height sheet case.
- `EdgeSwipeBackGuardTests` passes with `fitbodTests`, and `MilestoneOneJourneyUITests` passes on both phones.

## Hints

- XCUITest waits for the app to go idle before and after each step, and the 60-second message means the app's XCTest agent still saw an animation running.
- `fitbod/App/DebugLaunchReset.swift` shows how the app reads a launch flag, and the DEBUG launch helpers sit next to `fitbod/App/DemoWorkoutSeed.swift`.
- `UITestNavigation.launch` builds the launch arguments for most UI tests, and `topSheet(in:)` is near `UITestNavigation.swift:484`.
- Read the app's log with `xcrun simctl spawn <phone id> log show --last 5m --predicate 'process == "fitbod"'`.
- `class_copyMethodList` lists a category's method and the class's own under the same selector, so two `viewDidLoad` entries on `UINavigationController` mean UIKit added its own.
- The journey's delete check is near `MilestoneOneJourneyUITests.swift:157-161`; T18's notes suggest `if !added.waitForNonExistence(timeout: 2) { tap("Delete") }`.
