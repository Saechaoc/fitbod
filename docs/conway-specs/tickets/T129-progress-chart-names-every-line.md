---
id: T129
title: The progress chart names every line it draws, and labels its first and last dates
phase: 3
items: []
depends_on: [T98]
size: M
sim: both
owns: [fitbod/Progress/ExerciseProgressView.swift, fitbodUITests/Phase6/ProgressChartBRUUITests.swift, fitbodTests/ProgressChartDescriptorTests.swift]
---

# T129: The progress chart names every line it draws, and labels its first and last dates

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F297 and F298, which T98's worker found.

- On VOLUME and AVG RPE, the chart draws one line per intent, but its legend names only HYPERTROPHY and STRENGTH.
  A POWER, ENDURANCE or TECHNIQUE line is drawn dashed in `bruSignal`, exactly like STRENGTH, so it reads as part of STRENGTH or as nothing.
  The style comes from `isPrimary` alone, in the `LineMark` and `PointMark` near `ExerciseProgressView.swift:411`, and `legendKeys(hypCount:strCount:)` fixes the legend's two keys.
- On the small phone, an e1RM chart of four weekly workouts labels only the middle two dates on its x axis, so the first and last workouts have no date.
  The axis uses `AxisMarks(values: .automatic(desiredCount: 6))`.

## Target

- `ProgressChartHost` in `fitbod/Progress/ExerciseProgressView.swift`: its line styles, its legend and its x axis.

## Change

1. On VOLUME and AVG RPE, every intent the chart draws has a style of its own, and the legend names it with a matching swatch, as "POWER · 1 SESSION".
   A key for POWER, ENDURANCE or TECHNIQUE appears only when the chart draws that line.
   HYPERTROPHY and STRENGTH keep their keys and their look.
2. The legend wraps onto more lines rather than clipping or squeezing, at default text and at AX3, on both phones.
3. The x axis labels the first and the last workout dates on both phones.
   It labels dates between them only where they fit without clipping or overlapping.
4. T98's audio graph keeps naming each line as the legend does.

## Constraints

- Keep the e1RM and TOP SET charts' lines, points, PR rule and legend as they are; only their x axis labels change.
- New line styles use existing BRU color tokens, and each line reaches 3:1 contrast against `bruBg` in light and dark (WCAG 1.4.11).
- Keep T82's per-point VoiceOver elements and T98's audio graph.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

- With an exercise logged in hypertrophy, strength and power workouts, assert on VOLUME that the legend names POWER.
  It does not today.
  Use the cheapest test that proves it, such as the hosted view that `ProgressChartDescriptorTests` uses.
- On the small phone, with four weekly workouts, assert that the e1RM chart's x axis labels the first and the last dates.
  It labels only the middle two today.

## Observable acceptance

- The repro tests pass on the phones they name.
- `ProgressChartFitUITests`, `ProgressChartBRUUITests`, `PRListAndSeriesUITests` and `ProgressChartDescriptorTests` pass on the small phone.
- `screens/` holds VOLUME with three intents on both phones, at default text and at AX3, in light and dark, and e1RM with four weekly workouts on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T98's notes in the main checkout's `docs/conway-specs/evidence/T98/notes.md` describe the unnamed lines and the axis.
- `ChartPoint.intent` already carries each point's intent.
