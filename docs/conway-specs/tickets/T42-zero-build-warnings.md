---
id: T42
title: Zero build warnings
phase: 4
items: []
depends_on: [T39, T40, T41]
size: M
sim: large
owns: []
---

# T42: Zero build warnings

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The app builds with warnings, including deprecation warnings for joining `Text` values with `+`.
Warnings hide new problems, and the milestone requires a clean build.
The UI tests also log the runtime warning "Invalid frame dimension (negative or non-finite).", which the gate runs report many times and T28's worker saw in the logger's default-text tests (finding F188).

## Target

Every warning from building the app, the widget and both test targets.

## Change

1. Build the app, the widget, `fitbodTests` and `fitbodUITests` on the large phone, from a clean DerivedData folder.
2. Save every warning, with its file and line, to `warnings-before.txt`.
3. Fix each warning at its source.
   For the `Text` concatenation warnings, use the replacement that Apple's deprecation message names.
4. Build again from clean, and save the result to `warnings-after.txt`.
   It must list no warnings.
5. Find the view that asks for a negative or non-finite frame, and fix it at its source, so the logger's UI tests log no "Invalid frame dimension" warning.

## Constraints

- Never silence a warning with a build setting, a compiler flag, or an `@available` attribute added only to hide it.
- Keep every fix a plain like-for-like change: no behavior or layout change.
- If a warning comes from an Xcode or SDK issue you cannot fix in source, stop and ask the coordinator.
- If a test pins the text you change, the screen must still show exactly the pinned text.

## Ownership

You may edit any app or test file that has a warning, only to fix that warning, and the view behind the runtime warning in change 5.
Ask before you edit a file for any other reason.

## Repro first

There is no bug to reproduce.
`warnings-before.txt` is the starting evidence.
Count the warnings with a search for "warning:" in the saved build logs.

## Observable acceptance

- `warnings-after.txt` shows zero warnings for the app, the widget and both test targets.
- `SessionLoggerBRUUITests` on the large phone logs no "Invalid frame dimension" warning in its result bundle.
- `fitbodTests` passes on the large phone.
- The UI suites in every file you changed pass on the large phone.
- Screenshots of any screen whose `Text` you changed, before and after, are in `screens/` and look the same.

## Hints

- Use a fresh DerivedData folder inside your scratchpad for the clean builds, so cached results do not hide warnings.
- `xcodebuild` prints each warning as `<file>:<line>:<column>: warning: <message>`.
- Build the test targets with `build-for-testing`.
- At Phase 0 the build had one warning: a deprecated text concatenation in `BlockBuilderView.swift` near line 736 (see [../assumptions.md](../assumptions.md)).
  A fix there needs all six New Block guardrail suites.
