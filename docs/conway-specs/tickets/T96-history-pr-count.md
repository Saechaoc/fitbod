---
id: T96
title: Exercise history counts its real PRs and stops writing state while it draws
phase: 2
items: []
depends_on: [T94]
size: M
sim: both
owns: [fitbod/ExerciseLibrary/ExerciseHistoryView.swift, fitbodUITests/SwipeBackUITests.swift, new:fitbodTests/HistoryPRCountTests.swift]
---

# T96: Exercise history counts its real PRs and stops writing state while it draws

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F129 and F131, which the T94 worker found by reading the code; nobody has reproduced them yet.

- Exercise history's stat strip shows "PRs · 30d", but `prs30d` always returns 0, a placeholder left from Phase 6.
- `FilteredHistoryContent` calls `onHistoryChanged` inside `body`, which sets the parent's `hasHistory` state while SwiftUI draws the view.
  SwiftUI warns that a state change during a view update causes undefined behavior, and it can draw the view again.
- Library > an exercise > VIEW ALL HISTORY returns to the Library list instead of opening the history, on both phones (finding F181, from T18's worker).
  `ExerciseHistoryView` wraps itself in its own `NavigationStack` inside Library's stack, against the one-stack-per-tab rule, and pushes its PROGRESS chart inside that stack.

## Target

- `prs30d` and the `onHistoryChanged` call in `fitbod/ExerciseLibrary/ExerciseHistoryView.swift`.
- Its nested `NavigationStack` and the PROGRESS push in the same file.

## Change

1. "PRs · 30d" counts the working sets from the last 30 days that set a PR, by the same check as the in-workout PR banner.
   Replay the sets the history shows, oldest first, through `PRDetector.check(set:against:)` from an empty table, and count the sets in the window that return any PR kind.
   It reads the same sets as Tonnage, so it follows the intent filter.
2. The history count reaches the parent through a modifier that runs after the view draws, such as `.onChange(of:initial:)`, never from `body`.
3. Everything else stays as it is, including the strip's look and the PROGRESS link that shows once the exercise has history.
4. VIEW ALL HISTORY opens the exercise's history on Library's own stack, and PROGRESS pushes its chart on that stack, so `ExerciseHistoryView` holds no `NavigationStack` of its own.
5. `SwipeBackUITests` gains a swipe back from the history and from its chart, which T18 could not reach.

## Constraints

- Keep `PRDetector` as it is; read it, do not change it.
- No schema change.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/HistoryPRCountTests.swift`, log three finished workouts of one exercise: 100 lb × 5 forty days ago, 105 lb × 5 ten days ago and 100 lb × 5 five days ago.
  Assert that the PR count is 1; move the count into a static function the test can call.
  It fails today, because the count is always 0.

Change 2 follows SwiftUI's rule against changing state during a view update; no repro is needed for it.

- On both phones, with the progress-history seed, open Library > an exercise with history > VIEW ALL HISTORY, and assert that the history shows.
  It returns to the Library list today.
- Tap PROGRESS and assert that the chart shows, then go back twice and assert that the exercise's detail shows.

## Observable acceptance

- The repro tests pass, the UI tests on both phones.
- `SwipeBackUITests` passes on both phones.
- `ExerciseRowsPerWorkoutTests`, `ExerciseHistoryIntentSplitTests`, `ExerciseHistoryViewCopyTests` and `HistoryBRUCopyTests` pass.
- `fitbodTests` passes on the large phone.
- With the T13 progress-history seed, a screenshot of an exercise's history on the small phone shows its PR count and the PROGRESS link, in `screens/`.

## Hints

- `prs30d` is near `ExerciseHistoryView.swift:251`, and `onHistoryChanged` is called in `body` near line 141.
- `PRDetector.buildTable(from:)` and `check(set:against:)` are in `fitbod/Progress/PRDetector.swift`; the in-workout banner builds its table at `SessionFactory.start`.
- The progress-history seed is `fitbod/App/ProgressHistorySeed.swift`; use the T01 launch helpers.
