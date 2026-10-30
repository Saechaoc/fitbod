---
id: T53
title: Stall badge names the exercise's own window
phase: 1
items: []
depends_on: [T01]
size: S
sim: small
owns: [fitbod/Sessions/SessionExerciseCard.swift, new:fitbodUITests/StallBadgeWindowUITests.swift]
---

# T53: Stall badge names the exercise's own window

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F6, which the T51 worker read from the code and recorded in the run log.
When an exercise has stalled, the workout logger shows a STALLED badge.
VoiceOver reads it as "Stalled: <exercise> has been flat for <N> sessions."
`SessionExerciseCard` passes the global `UserSettings.plateauWindowSessions`, or 4 when there are no settings, as N.
`PlateauDetector.evaluate` uses the exercise's own `plateauWindowOverride` when it has one.
So for an exercise with an override, VoiceOver names the wrong number of sessions.

## Target

- The STALLED badge in the workout logger's exercise card, `fitbod/Sessions/SessionExerciseCard.swift`.

## Change

1. The badge's session count is the window the detector used: the exercise's `plateauWindowOverride` when it has one, otherwise the user's setting.
2. Nothing else about the badge changes: its look, its visible "STALLED" label and the wording of its VoiceOver label stay the same.

## Constraints

- No schema change.
- Do not change `StallBadge`'s public initializer, which `StallBadgeBRUTests` pins.
- Take the window from one place, so the badge and the detector cannot disagree again.
  If that needs a change in `fitbod/Fatigue/PlateauDetector.swift`, ask the coordinator first.

## Ownership

You may edit the files in `owns`, plus existing UI suites your change breaks.
The worker rules let you add a new DEBUG-only seed helper file next to `fitbod/App/DemoWorkoutSeed.swift`; editing `DemoWorkoutSeed.swift` itself needs the coordinator's yes.
Ask before you edit anything else.

## Repro first

On the small phone, with the T01 helpers:
- Seed an exercise whose finished history has stalled over its own window, with a `plateauWindowOverride` that differs from the user's setting.
- Open the workout, and assert that the badge's accessibility label names the override's number of sessions.
  Today it names the user's setting.

## Observable acceptance

- The repro test passes on the small phone.
- `StallBadgeBRUTests` and `fitbodTests` pass.
- A screenshot of the stalled card at default text is in `screens/`.

## Hints

- Worker rules allow a DEBUG-only seed helper next to `fitbod/App/DemoWorkoutSeed.swift` when a UI test would otherwise need many slow setup steps.
