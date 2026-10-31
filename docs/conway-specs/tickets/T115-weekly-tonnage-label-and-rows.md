---
id: T115
title: Weekly Tonnage keeps its previous-best label whole, and its week rows open their workouts
phase: 3
items: []
depends_on: [T104]
size: S
sim: small
owns: [fitbod/Progress/WeeklyTonnageView.swift, fitbod/Progress/WeekDetailView.swift, fitbodUITests/WeeklyTonnageUITests.swift]
---

# T115: Weekly Tonnage keeps its previous-best label whole, and its week rows open their workouts

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are finding F249, which the coordinator saw in T23's and T104's screenshots, and finding F245, which T104's worker found.

- The chart's "PREVIOUS BEST" label is cut to "PREVIOU" at the chart's right edge on the small phone.
  It is a `RuleMark` annotation at `.topTrailing`, and Swift Charts clips it at the plot's edge.
  T56 fixed the same cut on the exercise chart's PR label (finding F25).
- Each row in a week's detail shows a "›" glyph, but a tap on it opens nothing.

## Target

- The previous-best rule's label in `fitbod/Progress/WeeklyTonnageView.swift`.
- The workout rows in `fitbod/Progress/WeekDetailView.swift`.

## Change

1. The previous-best label reads whole, "PREVIOUS BEST", inside the chart on both phones.
2. A tap on a week detail row opens that workout's summary, as a History row does.
3. A row with no workout behind it, which gathers sets that belong to none, shows no "›" and opens nothing.
4. VoiceOver reads each row that opens a workout as a button.

## Constraints

- Keep T104's weeks, totals, VoiceOver week elements and "‹ BACK".
- Keep the previous-best line where it is, with its dash and color.
- Units relabel the stored numbers and never convert them, as `CLAUDE.md` says.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, in `WeeklyTonnageUITests`:

- Read the chart's screenshot with `UITestNavigation.textLines(in:of:)`, and assert that it finds "PREVIOUS BEST" whole.
  It finds "PREVIOU" today.
- Open a week's detail, tap its workout row, and assert that the workout's summary opens and that "‹ BACK" returns to the week.
  Nothing opens today.

## Observable acceptance

- The repro tests pass on the small phone.
- `WeeklyTonnageUITests` and `ProgressHomeBRUUITests` pass on the small phone.
- `fitbodTests` passes, including the `WeeklyTonnage` suites.
- Screenshots of the chart with its whole label on both phones, and of a workout summary opened from a week row on the small phone, are in `screens/`.

## Hints

- The label is the `.annotation` with `Text("PREVIOUS BEST")` in `WeeklyTonnageChartHost`.
- T56's fix draws the exercise chart's PR label as a chart overlay just above its rule; see `fd4232b` and `ExerciseProgressView`.
- Progress's NavigationStack registers `.sessionHistoryDestinations()` near `ProgressHomeView.swift:125`, and `SessionHistoryView` rows push `SessionHistoryRoute.summary(sessionID:)` with a `NavigationLink(value:)`.
- `WeekDetailWorkout.id` is the workout's `Session.id`, and it is nil for sets with no workout.
