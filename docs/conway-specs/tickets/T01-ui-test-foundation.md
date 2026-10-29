---
id: T01
title: UI test foundation
phase: 1
items: []
depends_on: []
size: M
sim: both
owns: [fitbodUITests/UITestNavigation.swift, fitbodUITests/WorkoutUITestNavigation.swift, fitbod/App/DebugLaunchReset.swift, new:fitbodUITests/UITestHelpersSelfTests.swift]
---

# T01: UI test foundation

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Almost every later ticket needs the same test tools, and today each suite builds its own.
The reset flag can be lost on the first launch of a test process while the app reinstalls, so a test can start on old data.
No helper launches a single test at AX3, saves a named screenshot that survives a passing run, or checks frames for overlap and stacked letters.

## Target

- The shared UI test helpers in `fitbodUITests/UITestNavigation.swift` and `fitbodUITests/WorkoutUITestNavigation.swift`.
- The DEBUG reset path in `fitbod/App/DebugLaunchReset.swift`.

## Change

1. Fresh store: the first launch in each test process launches the app with the reset flag, terminates it, and launches it again with the reset flag.
2. Every launch that asks for a reset confirms the store is fresh before the test goes on, and fails with a clear message if it is not.
3. Add a DEBUG-only signal that tells a UI test whether the reset ran on this launch, for example an accessibility element or an echoed launch environment value.
4. AX3 launch: a launch option sets the text size to AX3 for that launch only, through the content size launch argument (`-UIPreferredContentSizeCategoryName` with `UICTContentSizeCategoryAccessibilityXL`).
   It must work whatever the simulator's own text size is.
5. Named screenshots: a helper attaches a full-screen screenshot with a given name and the keepAlways lifetime.
   Names follow `<ticket>-<screen>-<phone>-<text size>-<appearance>`, for example `T15-program-empty-small-ax3-light`.
6. Frame checks: helpers fail a test with a readable message when two elements overlap, when an element is not inside another, when an element is taller than it is wide, when a tap target is smaller than 44 by 44 points, or when an element is taller than a given height.
7. Pixel check: a helper reads the color at a point in a screenshot and compares it with an expected color within a tolerance.
8. Gestures: one helper swipes a sheet down from its top edge, and one edge-swipes back from the left edge of the screen.
9. Keep the names and behavior of the existing helpers: `launch`, `tab`, `selectTab`, `openSettings`, `reveal`, `openSeededWorkout`, `openWeightExplanation` and `openEmptySessionBuilder`.
10. Add a self-test suite, `UITestHelpersSelfTests`, that uses each new helper at least once.

## Constraints

- Release builds behave exactly as before.
  Every app-side addition sits inside a DEBUG-only block.
- Do not change how tests type text, because T39 owns typing.
- Do not fix item 5.
  The journey test keeps failing with "106" instead of "10" until T06.
- Do not move existing suites onto the new helpers, unless a suite fails because of the reset race.

## Ownership

You may edit the files in `owns`, plus existing UI suites that your change breaks.
Ask before you edit anything else.

## Repro first

- Write a self-test that seeds data, relaunches without the reset flag, and asserts that the freshness check reports "not fresh".
  This proves the check can fail.
- Write a self-test that launches twice in one process with the reset flag and asserts that both launches are fresh.

## Observable acceptance

- `UITestHelpersSelfTests` passes on both phones.
- Every existing UI suite has the baseline result: only the two known failures fail.
- The AX3 self-test shows that a known label is taller at AX3 than at default text, and its saved screenshot shows large text.
- The exported attachments of a passing run include every named screenshot.
- `notes.md` names the DEBUG-only blocks you added.
- `notes.md` lists every new helper with a one-line description, so the coordinator can copy the list into the run log.

## Hints

- The reset race is described in the review file, under "Codex's failing tests", in the second-pass notes.
- A terminate between the first two launches gives the reinstall time to finish.
- An `XCUIScreenshot` gives a `UIImage`.
  Its pixels are in device pixels, not points, so scale coordinates by the screen scale.
- `MilestoneOneJourneyUITests`, `WorkoutLoggerJourneyUITests` and `NewBlockModalUITests` already attach screenshots, so reuse their pattern.
