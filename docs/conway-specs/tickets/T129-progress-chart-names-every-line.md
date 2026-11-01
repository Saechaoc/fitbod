---
id: T129
title: The progress chart names every line it draws
phase: 3
items: []
depends_on: [T98]
size: M
sim: small
owns: [fitbod/Progress/ExerciseProgressView.swift, fitbodUITests/Phase6/ProgressChartBRUUITests.swift, fitbodTests/ProgressChartDescriptorTests.swift]
---

# T129: The progress chart names every line it draws

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F297, which T98's worker found.
Finding F298, the small phone's x axis labels, and the legend's AX3 wrapping are deferred under `docs/DEVELOPMENT.md` as polish and AX3 layout.

- On VOLUME and AVG RPE, the chart draws one line per intent, but its legend names only HYPERTROPHY and STRENGTH.
  A POWER, ENDURANCE or TECHNIQUE line is drawn dashed in `bruSignal`, exactly like STRENGTH, so it reads as part of STRENGTH or as nothing.
  The style comes from `isPrimary` alone, in the `LineMark` and `PointMark` near `ExerciseProgressView.swift:411`, and `legendKeys(hypCount:strCount:)` fixes the legend's two keys.

## Target

- `ProgressChartHost` in `fitbod/Progress/ExerciseProgressView.swift`: its line styles and its legend.

## Change

1. On VOLUME and AVG RPE, every intent the chart draws has a style of its own, and the legend names it with a matching swatch, as "POWER · 1 SESSION".
   A key for POWER, ENDURANCE or TECHNIQUE appears only when the chart draws that line.
   HYPERTROPHY and STRENGTH keep their keys and their look.
2. T98's audio graph keeps naming each line as the legend does.

## Constraints

- Keep the e1RM and TOP SET charts as they are.
- New line styles use existing BRU color tokens, and each line reaches 3:1 contrast against `bruBg` in light and dark (WCAG 1.4.11).
- Keep T82's per-point VoiceOver elements and T98's audio graph.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

- With an exercise logged in hypertrophy, strength and power workouts, assert on VOLUME that the legend names POWER.
  It does not today.
  Use the cheapest test that proves it, such as the hosted view that `ProgressChartDescriptorTests` uses.

## Observable acceptance

- The repro tests pass on the phones they name.
- `ProgressChartFitUITests`, `ProgressChartBRUUITests`, `PRListAndSeriesUITests` and `ProgressChartDescriptorTests` pass on the small phone.
- `screens/` holds VOLUME with three intents on the small phone at default text, in light mode.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T98's notes in `docs/conway-specs/evidence/T98/notes.md` describe the unnamed lines and the axis.
- `ChartPoint.intent` already carries each point's intent.
