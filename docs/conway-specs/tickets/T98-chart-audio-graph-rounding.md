---
id: T98
title: The progress chart's audio graph reads rounded values
phase: 3
items: []
depends_on: [T82]
size: S
sim: both
owns: [fitbod/Progress/ExerciseProgressView.swift, new:fitbodTests/ProgressChartDescriptorTests.swift]
---

# T98: The progress chart's audio graph reads rounded values

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F140, which the T82 worker found.
Since T82, VoiceOver reads each chart point by itself with its rounded value, such as "113 lb".
The chart's automatic audio graph still describes values unrounded: its y axis reads 112.5 as "112.5", with no unit.

## Target

- The progress chart in `fitbod/Progress/ExerciseProgressView.swift`.

## Change

1. The chart gets its own `accessibilityChartDescriptor`, with one data series per drawn line, named as the legend names it.
2. The x axis reads dates, and the y axis reads values the way each point does, through `spokenValue`, such as "113 lb", "2,140 lb" or "RPE 7.6".
3. Everything else stays as it is, including T82's per-point elements, the marks and the legend.

## Constraints

- Keep the chart's look; this ticket changes only what assistive technology reads.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/ProgressChartDescriptorTests.swift`, build the descriptor for an E1RM chart with a 112.5 lb point, and assert that the y axis reads it as "113 lb" and that the series are named TOP SET and ALL-SET AVG.
  Move the descriptor into a function the test can call.
  It fails today, because the chart has no descriptor of its own.

## Observable acceptance

- The repro test passes with `fitbodTests` on the large phone.
- `ProgressChartFitUITests`, `ProgressChartBRUUITests` and `PRListAndSeriesUITests` pass on the small phone.

## Hints

- `spokenValue` is near `ExerciseProgressView.swift:272`, and T82's `pointElements` builds the per-point elements.
- SwiftUI's `View.accessibilityChartDescriptor(_:)` takes an `AXChartDescriptorRepresentable`, whose `makeChartDescriptor()` returns an `AXChartDescriptor` with `AXNumericDataAxisDescriptor` and its `valueDescriptionProvider`.
