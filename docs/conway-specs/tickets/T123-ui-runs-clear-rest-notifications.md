---
id: T123
title: UI test runs stay free of leftover rest notifications, and the journey suite reads cheaply
phase: 4
items: []
depends_on: [T101]
size: M
sim: both
owns: [fitbod/App/DebugLaunchReset.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, fitbodUITests/UITestHelpersSelfTests.swift, fitbodUITests/EditorSwipeDismissUITests.swift, fitbodUITests/CopySweepUITests.swift, fitbodUITests/WeeklyRecapUITests.swift, fitbodUITests/SwipeBackUITests.swift, fitbodUITests/TodayPolishUITests.swift, fitbodUITests/NewRoutineFlowUITests.swift, fitbodUITests/PlateScreensFitUITests.swift, fitbodUITests/PlateCalculatorSheetBRUUITests.swift, fitbodUITests/LibraryPolishUITests.swift, fitbodUITests/ProgramDarkModeUITests.swift, fitbodUITests/ExerciseHistoryRowsUITests.swift, new:fitbodUITests/SharedScreenHelpers.swift]
---

# T123: UI test runs stay free of leftover rest notifications, and the journey suite reads cheaply

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F266, F267 and F270, which T101's worker found.

- "Rest complete" notification banners appear during UI runs, from rest timers that earlier tests or launches started.
  In one of T101's runs a banner slid over the top of the screen just as a test swiped a sheet down, so the swipe pulled down Notification Center instead, and the test failed.
- `UITestHelpersSelfTests.testSheetSwipeDownFromTheTopEdgeClosesSettings` and the comments above two `EditorSwipeDismissUITests` tests still say the sheet swipe starts at the sheet's top edge; since T101 it starts in the sheet's header.
- `MilestoneOneJourneyUITests.tearDownWithError` attaches a `keepAlways` screenshot and the whole accessibility tree after every test, which a reader needs only after a failure.
- The suite's private `reveal` scrolls a page at a time, up to 14 swipes.
- Most `@MainActor` marks in `MilestoneOneJourneyUITests` and `UITestHelpersSelfTests` have no reason beside them, which guide section 2.10 asks for.
- `CopySweepUITests` carries its own copies of private helpers from `WeeklyRecapUITests` and `SwipeBackUITests` (`openToday(afterSeeding:)`, `open(_:in:)`, `waitUntilHittable`, `button(beginningWith:)`), so a change to one must be made twice (finding F280, from T34's review).

## Target

- The DEBUG launch reset in `fitbod/App/DebugLaunchReset.swift`.
- `fitbodUITests/MilestoneOneJourneyUITests.swift`, `fitbodUITests/UITestHelpersSelfTests.swift` and `fitbodUITests/EditorSwipeDismissUITests.swift`.

## Change

1. A launch with the reset flag removes the app's pending and delivered rest notifications, so no banner from an earlier test or launch shows during a run.
2. The sheet-swipe self-test's name and message, and the two comments, say the swipe starts in the sheet's header.
3. `tearDownWithError` attaches its screenshot and accessibility tree only when the test failed.
4. `reveal` scrolls in long drags and waits with `UITestNavigation.waitUntilStill`, instead of a page at a time.
5. Each `@MainActor` in the two suites has its reason beside it, or goes where it is not needed.
6. The helpers `CopySweepUITests` copies move into `fitbodUITests/SharedScreenHelpers.swift`, and all three suites use that one copy.
   So does `pixelCount`, which `TodayPolishUITests` and `NewRoutineFlowUITests` each keep a private copy of (finding F283, from T35's review), and the ink-column reader that `PlateCalculatorSheetBRUUITests.drawnHeight(of:)` and `PlateScreensFitUITests.column(atX:from:to:in:)` with `isInk` each implement (finding F288, from T107's review), and the `TextContrast`, `tapWhenReady` and `tabBarTop` that `LibraryPolishUITests` copies from `ProgramDarkModeUITests` and `ExerciseHistoryRowsUITests` (finding F291, from T37's review).

## Constraints

- Change only DEBUG launch behavior in the app; a release build, and a launch without the reset flag, behave as today.
- Keep every test that checks rest notifications passing, and keep every journey assertion.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else, such as the rest timer's scheduler.

## Repro first

- On the small phone, start a rest timer in one launch, end the app before it completes, relaunch with the reset flag after its time is up, and assert that no "Rest complete" banner or delivered notification remains.
  It remains today.
- Run `MilestoneOneJourneyUITests` three times on the large phone and record each case's durations in `notes.md` as the "before" numbers.

## Observable acceptance

- The repro test passes on the small phone.
- `MilestoneOneJourneyUITests`, `UITestHelpersSelfTests` and `EditorSwipeDismissUITests` pass three runs on each phone, with durations before and after in `notes.md`.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T101's notes in the main checkout's `docs/conway-specs/evidence/T101/notes.md` describe the banner, with screenshots of it and of the Notification Center it opened.
- `RestTimerNotificationScheduler.swift` wraps `UNUserNotificationCenter`; `removeAllPendingNotificationRequests()` and `removeAllDeliveredNotifications()` clear both kinds.
- `DebugLaunchReset.swift` already handles `-fitbod-reset-store` and the `debug.resetSignal` element that `UITestNavigation.launch` waits for.
