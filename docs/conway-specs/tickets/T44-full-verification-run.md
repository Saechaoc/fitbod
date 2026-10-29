---
id: T44
title: Full verification run
phase: 6
items: []
depends_on: [T43]
size: L
sim: both
owns: []
---

# T44: Full verification run

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Each ticket ran only its own UI suites, and the phase gates ran only on the large phone.
Done criteria 1 and 2 in [../requirements.md](../requirements.md) need one full run on both phones against the final code.

## Target

The app, the widget, `fitbodTests` and `fitbodUITests` at the current `HEAD`.

## Change

1. Record `git rev-parse --short HEAD` in `report.md`, next to the run base from your task header.
2. Set both phones to default text and light mode.
3. Build the app and the widget for each phone from an empty DerivedData folder, and count the warnings.
4. Run `fitbodTests` on the large phone.
5. Run all of `fitbodUITests` on the small phone, then on the large phone, one phone at a time.
6. Run `python3 docs/design-system/tokens_check.py` and `git diff --check <run base>..HEAD`.
7. Rerun each failing test alone three times on the same phone.
   It is a failure if it fails all three times, and flaky if it passes at least once.
8. Write `report.md`.

## Constraints

- Change no app or test code.
  This ticket only runs and reports.
  The coordinator turns each failure and each flaky test into a new ticket, T49 or later.
- Never skip or disable a test, and never rerun a whole suite to get a green result.
- The one known issue in `fitbodTests` is expected.

## Ownership

You write evidence only.
You change no file in the repo.

## Repro first

There is no bug to reproduce.
The runs are the evidence.
This ticket changes no code, so it skips `repro-fail.txt`, `impact.txt` and `detect-changes.txt`.

## Observable acceptance

- `report.md` gives the pass, fail and skip counts and the duration of each run: `fitbodTests` on the large phone, and `fitbodUITests` on each phone.
- It gives the warning count of each build, and the output of the token check and of `git diff --check`.
- It lists each failing or flaky test with its phone, its first error line, its three rerun results and its result bundle path.
- `git status --porcelain` still matches `status-before.txt`.
- You finish with outcome `succeeded` when the report is complete, even if tests failed.
  Use `failed` only when a run could not finish.

## Hints

- The Phase 0 baseline ran the whole scheme on the large phone in about 16 minutes, so each full run takes longer than one shell call allows.
  Start it in the background and keep sending heartbeats while you wait.
- When this bundle was written, the UI target had 25 suites with 55 tests, and the Phase 0 baseline counted 1,026 tests in all (see [../assumptions.md](../assumptions.md)).
- To rerun one UI test, use `-only-testing:fitbodUITests/<suite>/<test>`.
  For a Swift Testing unit test, copy its identifier from `xcrun xcresulttool get test-results tests`.
- Put the clean DerivedData folders in your scratchpad, so cached results do not hide warnings.
