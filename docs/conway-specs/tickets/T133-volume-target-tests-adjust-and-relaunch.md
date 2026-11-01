---
id: T133
title: A volume target edit and a started block survive a relaunch
phase: 4
items: []
depends_on: [T109, T143]
size: S
sim: large
owns: [new:fitbodTests/RelaunchPersistenceTests.swift, fitbod/Fatigue/MuscleVolumeTargetSeeder.swift]
---

# T133: A volume target edit and a started block survive a relaunch

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too.

## Problem

These are findings F311 and F370, which T109's and T143's workers found.
T133's other items went with the suites T143 deleted; F310, a VoiceOver test, stays deferred.

- No test edits a volume target, relaunches and checks that the edit stayed.
  `MuscleVolumeTargetSeeder` runs at every launch and must skip a target the lifter edited.
- No test now checks that a started block is still the active block after a relaunch.
  T143 deleted `BlockReviewAfterEndUITests.testStartingABlockStopsAReviewPutOff`, the only such check, and `BlockLifecycleServiceTests` reads the block back from the same in-memory context, so it passes even if start's save never reaches disk.

## Target

- `MuscleVolumeTargetSeeder` and `BlockLifecycleService.start`, through a new unit test file.

## Change

1. `RelaunchPersistenceTests` builds an on-disk store, edits a volume target, then opens a second container on the same file and runs the seeder as a launch does, and expects the edit to stay.
2. It also starts a block through `BlockLifecycleService` in an on-disk store, opens a second container on the same file, and expects exactly one active block, the one started.
3. If either test fails, fix the cause in the files in `owns`, and say what it was in `notes.md`.

## Constraints

- Unit tests only; commit no UI test (the user asked for fewer UI tests, T143).
- Each case runs in well under a second, and its store lives in a temporary directory that the test removes.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else, such as `BlockLifecycleService.swift`.

## Repro first

- Write both tests first and record in `notes.md` whether each passes today.

## Observable acceptance

- Both tests pass with `fitbodTests` on the large phone, three runs in a row.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T143's notes, `docs/conway-specs/evidence/T143/notes.md`, under its ponytail review's should-fix 1, sketch the block test.
- T128's `SeedTests` and `IndexedQueryTests` keep their state in per-test containers and suites; follow that pattern.
