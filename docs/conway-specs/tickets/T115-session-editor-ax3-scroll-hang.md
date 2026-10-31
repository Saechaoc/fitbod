---
id: T115
title: The session editor scrolls at AX3 without hanging
phase: 2
items: []
depends_on: [T101, T110]
size: M
sim: small
owns: [fitbod/Routines/PrescriptionEditorRow.swift, fitbodUITests/SessionEditorPolishUITests.swift]
---

# T115: The session editor scrolls at AX3 without hanging

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F-ext-1, which T110-ext's worker found on 2026-10-31 on Chriss-Mac-mini.

- `SessionEditorPolishUITests/testEditorAtAX3` fails on the small phone.
- At AX3, after the test drags the session editor's EDIT PRESCRIPTION past the Rest stepper, the app's main thread never goes idle.
  The test stops with "process main thread busy for 30.0s" and then "Timed out while evaluating UI query", near `SessionEditorPolishUITests.swift:444`.
- It fails the same way on `3428ffea`, before T110, so T110 did not cause it.
- It was seen on the iOS 26.5 runtime only, and it may be the same busy main thread that T101 fixes for typing.

## Target

- The session editor's EDIT PRESCRIPTION section at accessibility text sizes, in `fitbod/Routines/PrescriptionEditorRow.swift`.

## Change

1. First run `testEditorAtAX3` on the small phone of your lane, on the newest `main`.
   If it passes three times in a row, change no code, and finish with "not reproduced" as the worker rules say.
2. Otherwise, find what keeps the main thread busy after the drag, such as a layout that never settles, an animation that repeats, or a view that updates its own state on every layout pass.
3. Fix it at its source, so the editor scrolls at AX3 and the main thread goes idle.

## Constraints

- Keep T29's and T110's session editor changes and the AX3 layout as they are.
- Do not add sleeps, longer timeouts or retries to the test to hide the hang.
- No schema change.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else, such as a BRU component in `fitbod/Design/` that turns out to cause the hang.

## Repro first

- Run `SessionEditorPolishUITests/testEditorAtAX3` on the small phone and save the failure, with its result bundle, to `repro-fail.txt`.
- Record in `notes.md` whether it also fails on the large phone.

## Observable acceptance

- `testEditorAtAX3` passes three runs in a row on the small phone.
- All of `SessionEditorPolishUITests`, `PrescriptionEditorUITests` and `RoutineBuilderBRUUITests` pass on the small phone.
- `fitbodTests` passes on the large phone.
- A screenshot of EDIT PRESCRIPTION at AX3, scrolled past the Rest stepper, is in `screens/`.

## Hints

- T110-ext's bundles `T110-ui-ax3-2.xcresult` and `T110-base-ax3-1.xcresult` show the hang; the coordinator on Chriss-Mac-mini holds them.
- The AX3 layout uses `dynamicTypeSize.isAccessibilitySize` near `PrescriptionEditorRow.swift:195`.
- Instruments' Time Profiler or a main-thread sample taken during the hang names the busy code.
