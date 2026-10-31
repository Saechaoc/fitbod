---
id: T109
title: The muscle screen uses BRU steppers, keeps a stable order and is always tested
phase: 3
items: []
depends_on: [T30]
size: S
sim: small
owns: [fitbod/Fatigue/MuscleVolumeTargetStepper.swift, fitbod/Fatigue/PerMuscleDetailView.swift, fitbodUITests/PerMuscleDetailUITests.swift, fitbodUITests/Phase5BRUSmokeUITests.swift]
---

# T109: The muscle screen uses BRU steppers, keeps a stable order and is always tested

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F209 to F211, from T30's run and screenshots.

- The MV, MEV, MAV and MRV targets use the stock iOS stepper, a gray capsule with "−" and "+".
  It is the app's last stock stepper, and it shows on a muscle's screen and in Settings → Volume Targets.
- CONTRIBUTING EXERCISES has no stable order for ties.
  Two exercises with the same set count swap places between renders, as Barbell Bench Press and Incline Dumbbell Press did in T30's screenshots.
- `PerMuscleDetailUITests` and `Phase5BRUSmokeUITests` launch with a plain `app.launch()`, so they run on whatever store the phone holds.
  On an empty store they skip their volume bar tap, so they can pass without opening a muscle's screen.

## Target

- The four steppers in `fitbod/Fatigue/MuscleVolumeTargetStepper.swift`.
- The CONTRIBUTING EXERCISES order in `fitbod/Fatigue/PerMuscleDetailView.swift`.
- The launches in `fitbodUITests/PerMuscleDetailUITests.swift` and the muscle tests in `fitbodUITests/Phase5BRUSmokeUITests.swift`.

## Change

1. The four target steppers use the BRU stepper look other screens use, with touch targets of at least 44pt.
2. They keep their range of 1 to 30 sets, their step of one, their VoiceOver labels and values, the order check and the "user edited" flag.
3. Rows in CONTRIBUTING EXERCISES with the same count sort by exercise name, so the order never changes between renders.
4. `PerMuscleDetailUITests` and the muscle tests in `Phase5BRUSmokeUITests` launch through `UITestNavigation.launch` with the demo seed, and always tap a volume bar and reach the muscle's screen.

## Constraints

- Keep the pinned copy that `MuscleVolumeTargetStepperBRUTests` checks, and RESET TO RP DEFAULTS as it is.
- Keep T30's "Edit volume targets" row and its ▾/▴ marker.
- Every UI test keeps its assertions, and none may skip them.

## Ownership

You may edit the files in `owns`, plus tests your change breaks, such as `MuscleVolumeTargetEditorUITests`.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open Chest from Today with the demo seed, open "Edit volume targets", and assert that no element of the stock stepper type exists on the screen.
- Render the muscle screen twice with two contributing exercises of equal count, and assert that their order matches.
- Run `PerMuscleDetailUITests` on a store you just reset, and record in `notes.md` that it skips its tap today.

## Observable acceptance

- The repro checks pass on the small phone.
- `PerMuscleDetailUITests`, `Phase5BRUSmokeUITests` and `MuscleVolumeTargetEditorUITests` pass on the small phone after a store reset, without skipping.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of a muscle's open targets and of Settings → Volume Targets, before and after, are in `screens/`.

## Hints

- The stock `Stepper` is near `MuscleVolumeTargetStepper.swift:146`, and `BRUStepper` in `fitbod/Design/BRUStepper.swift` is the BRU one.
- The contributing rows sort near `PerMuscleDetailView.swift:338`.
- The volume bar tap is near `PerMuscleDetailUITests.swift:40`, and the muscle tests are near `Phase5BRUSmokeUITests.swift:145` and 208.
- T30's notes and screenshots are in the main checkout's `docs/conway-specs/evidence/T30/`.
