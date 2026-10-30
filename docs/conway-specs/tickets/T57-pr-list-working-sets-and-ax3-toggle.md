---
id: T57
title: PR list ranks working sets only, and its intent toggle fits AX3
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Progress/ExercisePRsView.swift, fitbodTests/Phase6/ExercisePRsRankingTests.swift]
---

# T57: PR list ranks working sets only, and its intent toggle fits AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F27 and F28, which the T13 worker found in the PR list.
The list reads every completed set that is not a warm-up, including drop, failure and rest-pause sets and sets with zero weight.
`PRDetector.isWorkingSet` excludes those, so the list can rank a set that PR detection never counts.
At AX3 on the small phone, the STRENGTH, HYPERTROPHY and ALL toggle breaks words in the middle, such as "STRENG/TH" and "HYPERT/ROPHY".

## Target

- The set query and `intentToggle` in `fitbod/Progress/ExercisePRsView.swift`.

## Change

1. The PR list ranks only the sets that `PRDetector.isWorkingSet` accepts.
2. At AX3 on the small phone, every toggle label is whole: no word breaks in the middle.
3. Nothing else about the list changes: its buckets, ranking, names and three-per-exercise cap stay as T13 made them.

## Constraints

- PR detection itself does not change.
- Follow the `#Predicate` rule in `CLAUDE.md`: keep the predicate simple and filter in Swift afterwards.

## Ownership

You may edit the files in `owns`, plus Progress tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/Phase6/ExercisePRsRankingTests.swift`, add a heavier drop set and a zero-weight set to a ranked exercise, and assert that neither appears in the ranking.
- On the small phone at AX3, open the PR list and save a screenshot that shows the toggle; today it breaks words.

## Observable acceptance

- The repro unit test passes.
- The AX3 screenshot on the small phone shows every toggle label whole.
- `PRListAndSeriesUITests` and `PRsAndComparisonCopyTests` pass.
- `fitbodTests` passes.

## Hints

- `PRDetector.isWorkingSet` is near line 262 of `fitbod/Progress/PRDetector.swift`.
- The list's query is near line 183, and `intentToggle` near line 123.
