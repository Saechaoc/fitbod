---
id: T18
title: Swipe-back on every pushed screen
phase: 2
items: [35, 43]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Periodization/BlockOverviewScreen.swift, new:fitbod/App/EdgeSwipeBack.swift, new:fitbodUITests/SwipeBackUITests.swift]
---

# T18: Swipe-back on every pushed screen

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The app hides the system navigation bar in 36 files so it can draw BRU headers, and nothing restores the edge-swipe back gesture.
On Plate Inventory, an edge swipe does nothing.
Other pushed screens may have lost swipe-back too, because only Plate Inventory was tested.
The block overview has the opposite problem: it never hides the system bar, so the system back button and the BRU "‹ BACK" both show.

## Target

- The edge-swipe back gesture for every navigation stack in the app, including the Settings sheet.
- The main body of the block overview in `fitbod/Periodization/BlockOverviewScreen.swift`.

## Change

1. On every pushed screen, an edge swipe from the left goes back one screen, the same as the screen's own back control (see "Swipe-back everywhere" in [../tradeoffs.md](../tradeoffs.md)).
2. The swipe works whether or not the screen hides the system bar.
3. On the root screen of a stack, the swipe does nothing and leaves no stuck or half-drawn state.
4. A pushed screen that asks before leaving turns the swipe off while it has unsaved changes.
   Once its changes are saved or discarded, the swipe works again.
5. The block overview shows only its BRU "‹ BACK", and its header moves to the top.
6. One fix covers the whole app, with no gesture code added to each screen.

## Constraints

- Keep one `NavigationStack` per tab, as `CLAUDE.md` says.
- Do not show the system bar again on BRU screens.
- Swipe-down on sheets and the tab bar must keep working as they do today.
- If the fix needs UIKit, keep it in one small file, and keep Swift 6 strict concurrency clean.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
You may also edit a pushed screen that asks before leaving, but only to turn the swipe off while it has unsaved changes.
Ask before you edit anything else.

## Repro first

On both phones:

- List every pushed screen: each `navigationDestination` target and each `NavigationLink` destination, in every tab and in the Settings sheet.
  Save the list in `notes.md`, with the steps that open each screen.
- For each screen, write a UI test that pushes it, swipes back with the T01 helper, and asserts that the previous screen shows again.
  Record which ones fail today; Plate Inventory is one of them.
- Open a block overview, and assert that exactly one back control exists.
  Two exist today.

## Observable acceptance

- Every swipe test passes on both phones.
- A UI test proves that a pushed screen with unsaved changes ignores the swipe and keeps the changes.
  If no pushed screen asks before leaving, say so in `notes.md` instead.
- A UI test proves that a swipe on a root screen does nothing.
- `MilestoneOneJourneyUITests`, `HistoryAndTodayUITests` and `WorkoutSwapJourneyUITests` pass on both phones.
- Screenshots of the block overview header on both phones are in `screens/`.

## Hints

- Known destinations and their route types:
  - Library: exercise detail (`Exercise`).
  - Today: `SessionRoute`, `MuscleSlugRoute`, `BlockOverviewRoute` and `SplitDetailRoute`.
  - Program: `SessionRoute`, `BlockOverviewRoute` and `SplitDetailRoute`.
  - History: `SessionHistoryRoute`.
  - Progress: `ExerciseProgressRoute`, `ProgressHomeRoute` and `PRsRouteDestination`.
  - `RoutinesListView`: `SessionRoute`.
  - Settings: Plate Inventory and the muscle volume targets.
- Search for `navigationBarHidden(true)` and `.toolbar(.hidden` to find the screens that hide the bar.
- When the bar is hidden, UIKit's navigation controller keeps its interactive pop gesture but stops it from starting.
  The usual app-wide fix lets that gesture begin whenever the stack holds more than one screen.
- The block overview's main body is near lines 138-205.
  The review verified that hiding the system bar there leaves only "‹ BACK".
