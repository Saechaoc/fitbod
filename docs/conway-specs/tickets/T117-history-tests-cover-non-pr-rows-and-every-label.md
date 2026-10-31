---
id: T117
title: Exercise history's tests cover a row without a PR and every label
phase: 4
items: []
depends_on: [T112]
size: S
sim: both
owns: [fitbodUITests/ExerciseHistoryRowsUITests.swift, fitbod/App/ProgressHistorySeed.swift]
---

# T117: Exercise history's tests cover a row without a PR and every label

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F-ext-5 and F-ext-6, which T112-ext's worker and the coordinator's review of T112-ext found.

- Every workout in the progress-history seed sets a PR, so `ExerciseHistoryRowsUITests` shows "★ PR" on a row but never checks that a row without a PR has no chip.
  A chip shown on every row would pass.
- The word check covers only the STRENGTH chip and the "Sessions · 30d" label.
  The other intent chips, "Tonnage" and "PRs · 30d" are not checked.
- The word check passes when any one of three OCR crops reads the word whole, which is lenient.

## Target

- `fitbodUITests/ExerciseHistoryRowsUITests.swift`.
- The DEBUG progress-history seed in `fitbod/App/ProgressHistorySeed.swift`.

## Change

1. The seed gains one finished workout that sets no PR for the history's exercise, without changing what the other suites that use the seed check.
2. A test asserts that this workout's row shows no "★ PR", and that a workout that set a PR still shows it.
3. The word check covers every intent chip and every stat label, on both phones, at default text and at AX3.
4. The word check fails when any crop shows a word broken over two lines, rather than passing when one crop reads it whole.

## Constraints

- No app code change apart from the DEBUG seed.
- Keep the seed DEBUG-only.
- Do not add fixed sleeps.

## Ownership

You may edit the files in `owns`, plus tests that read the progress-history seed and break because of the new workout.
Ask before you edit anything else.

## Repro first

- Before you change the seed, write the "no ★ PR" test and run it: it fails, because the seed has no workout without a PR.
- Run the stricter word check on `3428ffea`'s app code: it fails on the small phone, where "STRENGTH" broke.

## Observable acceptance

- `ExerciseHistoryRowsUITests` passes on both phones.
- Every suite that uses the progress-history seed passes on the phones it runs on.
- `fitbodTests` passes on the large phone.
- A screenshot showing a row without "★ PR" next to a row with one is in `screens/`.

## Hints

- T112-ext's notes say Vision OCR misreads widely spaced capitals in some crops, such as "HARAS 9" for a whole "STRENGTH · 6"; compare the word's pieces across crops rather than requiring one perfect read.
- `UITestNavigation.readText(in:of:)` is the shared OCR helper.
- Find the suites that use the seed with `rg -l "progress-history|ProgressHistorySeed" fitbodUITests fitbodTests`.
