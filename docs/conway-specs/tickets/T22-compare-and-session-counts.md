---
id: T22
title: Compare and session counts skip empty workouts
phase: 2
items: [39, 40]
depends_on: [T01, T02]
size: M
sim: small
owns: [fitbod/Progress/ProgressHomeView.swift, fitbod/Progress/SessionComparisonView.swift, fitbod/Views/TodayView.swift, fitbod/Sessions/SessionHistoryView.swift, fitbod/App/DemoWorkoutSeed.swift, new:fitbodTests/EmptyWorkoutCountTests.swift, new:fitbodUITests/EmptyWorkoutCountsUITests.swift]
---

# T22: Compare and session counts skip empty workouts

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Compare on Progress shows "OCT 5 Δ OCT 5" when the latest finished workout has no sets, because it always compares the latest two finished workouts.
Compare also centers its exercise names, so they look ragged.
An empty finished workout counts as a session.
After one real workout and one empty one, Progress says "2 sessions", and the chart below it still asks for 2 sessions to unlock.
Today's stat strip and the History stat strip count every finished workout too.

## Target

- Compare in `fitbod/Progress/ProgressHomeView.swift` and `fitbod/Progress/SessionComparisonView.swift`.
- The session counts on Progress, on Today and in History.

## Change

1. Compare uses the latest finished workout that has logged work sets, and the previous finished workout that also has them (see "Compare" in [../tradeoffs.md](../tradeoffs.md)).
2. With fewer than two such workouts, Compare shows its existing locked state.
3. Compare left-aligns its exercise names.
4. Every session count leaves empty workouts out (decision 6):
   - Progress's session count and the chart's unlock text
   - Today's total and this-week counts
   - the History stat strip
5. Empty workouts still show in the History list.
6. Use T02's empty-workout rule and plural helper, and never write a second rule.

## Constraints

- Keep `@Query` in the views.
  Where the rule needs relationships, query broadly and filter in Swift, as `CLAUDE.md` says.
- Update `PRsAndComparisonCopyTests` only where you change pinned copy on purpose.

## Ownership

You may edit the files in `owns`, plus Progress, Today and History tests your change breaks.
Ask before you edit anything else.

## Repro first

Add a DEBUG seed with one real finished workout and one empty finished workout.
Then, on the small phone:

- Assert that Progress's count reads "1 session".
  It reads "2 sessions" today.
- Assert that Compare shows its locked state.
- Assert that Today's total session count is 1.
- Assert that the History stat strip counts 1 session.
- With a seed of two real workouts and an empty one between them, assert that Compare shows the dates of the two real workouts.
- Assert that all Compare exercise names share one left edge.

## Observable acceptance

- Every repro test passes on the small phone.
- A unit test covers the count rule with real, empty and unfinished workouts.
- `ProgressHomeBRUUITests`, `SessionHistoryBRUUITests` and `HistoryAndTodayUITests` pass on the small phone.
- `SessionComparatorTests` and `PRsAndComparisonCopyTests` pass with `fitbodTests`.
- Screenshots of Compare, locked and with two workouts, and of each count, are in `screens/`.

## Hints

- Compare picks its two workouts near `ProgressHomeView.swift:178-195`, and the count is near 308-320.
- `SessionComparisonView.swift` centers names near lines 91-125 and 130-179.
- Today counts finished workouts near `TodayView.swift:107`, and `sessionsThisWeek` is near line 472.
- `SessionHistoryView.swift` builds the History strip near line 50.
