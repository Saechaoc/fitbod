---
id: T64
title: The plateau footer stops pointing to a missing setting, and a test pins the stall window
phase: 1
items: []
depends_on: []
size: S
sim: large
owns: [fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbodTests/Fatigue/PlateauDetectorTests.swift, new:fitbodTests/ExerciseDetailPlateauCopyTests.swift]
---

# T64: The plateau footer stops pointing to a missing setting, and a test pins the stall window

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F39 and F40, which the T53 worker found.
An exercise's detail screen ends its Plateau Detection section with "Global defaults: 4 sessions, 2% tolerance. Set in Settings."
Settings has no control for either value, so the line sends the user to a setting that does not exist.
T53 (`6e66a37`) makes the STALLED badge count the e1RMs in `PlateauDetector`'s `.stalled` payload.
No unit test checks that the payload holds exactly one e1RM per session of the window the detector used.

## Target

- The footer text near line 512 of `fitbod/ExerciseLibrary/ExerciseDetailView.swift`.
- `fitbodTests/Fatigue/PlateauDetectorTests.swift`.

## Change

1. The footer still states the global defaults, but it no longer says "Set in Settings." or points to any setting.
2. A unit test checks that `.stalled` carries exactly the exercise's `plateauWindowOverride` number of e1RMs when it has one.
3. Another checks that it carries exactly the user's `plateauWindowSessions` number when the exercise has no override.
4. Nothing else on the screen changes.

## Constraints

- Do not add a Settings control; a global plateau control is not part of Milestone 1.
- `PlateauDetector` itself does not change.
- Leave the footer's count wording as it is; T34 moves every count label onto the plural helper later.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/ExerciseDetailPlateauCopyTests.swift`, read `ExerciseDetailView.swift` the way the existing copy tests read their sources, and assert that no string literal says "Set in Settings".
  It fails today.
- Add the two payload tests from changes 2 and 3 to `PlateauDetectorTests`; they pin today's behavior, so note in `notes.md` that they pass at base.

## Observable acceptance

- The repro test passes.
- `PlateauDetectorTests` passes, with the two new tests.
- `fitbodTests` passes on the large phone.

## Hints

- `PlateauDetector` returns `.stalled(e1RMs:rangeRatio:)` near line 147 of `fitbod/Fatigue/PlateauDetector.swift`.
- `fitbodTests/Phase6/ExerciseProgressViewCopyTests.swift` shows how a copy test reads its source.
