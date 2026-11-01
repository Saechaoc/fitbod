---
id: T121
title: New Block UI tests fit the test budgets
phase: 4
items: []
depends_on: [T105, T120]
size: M
sim: small
owns: [fitbodUITests/NewBlockLayoutUITests.swift, fitbodUITests/NewBlockModalUITests.swift]
---

# T121: New Block UI tests fit the test budgets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F262, which T105's worker found while timing New Block's tests.

- `NewBlockLayoutUITests.reveal(_:named:in:)` sleeps a fixed 0.5 s after each drag, with no comment, and makes short slow drags; one such drag beside a card once opened the card's editor.
- `NewBlockLayoutUITests` has two helpers that work out the page-scroll span between the top and bottom bars, `scroll(_:toDrag:in:)` and `reveal(_:named:in:)`, so a change to the bars needs both.
- Several cases run far over the guide's 30 s case budget: `testEveryWordStaysWholeAtAX3` about 92 s, `testEveryWordStaysWholeAtDefaultText` about 60 s, `testSheetsShowEveryWordWholeAtAX3` about 54 s, `testChartFallsBackToProgramsShortLabels` about 39 s and `testLegendAndBottomBarStayWholeAtAX3` about 36 s.
- `NewBlockModalUITests` launches with a bare `XCUIApplication()` instead of `UITestNavigation.launch`, and keeps a `keepAlways` screenshot that no test or person reads.

## Target

- `fitbodUITests/NewBlockLayoutUITests.swift`.
- `fitbodUITests/NewBlockModalUITests.swift`.

## Change

1. `reveal` waits for the page to stop moving with `UITestNavigation.waitUntilStill`, instead of a fixed sleep, and scrolls in long drags aimed at the middle of the page's span.
2. One helper works out the page-scroll span, and both `reveal` and the drag helper use it.
3. Each case named in Problem fits the 30 s case budget, or the 90 s journey budget if it is one, with the same assertions; where one cannot, `notes.md` says what the time is spent on.
4. `NewBlockModalUITests` launches through `UITestNavigation.launch`, and drops the screenshot no one reads, or names its reader.

## Constraints

- No assertion gets weaker, and no test is deleted, except where two tests become one that keeps every assertion.
- Keep the AX3 and default-text coverage on the small phone.

## Ownership

You may edit the files in `owns`, plus New Block tests your change breaks.
Ask before you edit anything else.

## Repro first

- Run `NewBlockLayoutUITests` and `NewBlockModalUITests` three times on the small phone with `-test-iterations 3`.
- Record each case's three durations in `notes.md` as the "before" numbers.

## Observable acceptance

- Three runs of both suites on the small phone, with each case's durations before and after in `notes.md`.
- Every case fits its budget, or `notes.md` explains the time it still takes.
- `PhaseRowsVoiceOverUITests` and `BlockTemplateCatalogUITests` pass on the small phone, and `fitbodTests` passes.

## Hints

- T105's per-case durations are under "Test performance" in the main checkout's `docs/conway-specs/evidence/T105/notes.md`, and its review's nice-to-have 2 describes the two scroll helpers.
- `UITestNavigation.launch` waits for the tab bar, so a test that launches through it needs no splash wait.
