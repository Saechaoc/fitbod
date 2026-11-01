---
id: T128
title: Re-seeding the exercise library keeps the lifter's exercises, history and targets
phase: 3
items: []
depends_on: []
size: M
sim: both
owns: [fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift, fitbodTests/SeedTests.swift, fitbodTests/IndexedQueryTests.swift]
---

# T128: Re-seeding the exercise library keeps the lifter's exercises, history and targets

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F296, which T98's worker found.
It is a data-loss defect.

- `ExerciseLibraryImporter.seedIfNeeded` deletes every `Exercise` and every `MuscleGroup` before it inserts the catalog again (`fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift:146-147`).
  It does this whenever the `exercise_seed_version` stamp in `UserDefaults` is below the bundled `SEED_VERSION.txt`.
- That deletes custom exercises (`isCustom`).
  It also cascades to every `ExerciseMuscleStimulus` and every `MuscleVolumeTarget`, so stimulus weights and volume targets the lifter edited are lost.
  The `userEditedWeight` and `userEdited` guards in `StimulusWeightSeeder` and `MuscleVolumeTargetSeeder` never get a chance.
- Logged `SessionExercise` rows and `SessionExerciseTemplate` rows lose their exercise, so history and sessions point at nothing.
- A real bump of `SEED_VERSION.txt` would do all of this on the lifter's phone.
- The seed runs at launch while Today and Progress already show those models.
  On T98's large phone, the next launch died with "This model instance was invalidated because its backing data could no longer be found the store" in `FatigueSurfaceView` (`ExerciseMuscleStimulus.muscle`).
  The launch after that died in `ProgressHomeView.recentStats` (`Exercise.id`).
  The crash reports are `fitbod-2026-11-01-021016.ips` and `fitbod-2026-11-01-021115.ips`.
- In the lanes, `SeedTests` and `IndexedQueryTests` set it off.
  They remove the stamp from `UserDefaults.standard`, which the hosted unit tests share with the app on that phone, and leave it removed.
  The next launch without `-fitbod-reset-store`, such as the next `-test-iterations` run, re-seeds over the store that UI tests left.

## Target

- `ExerciseLibraryImporter.seedIfNeeded`, and how `SeedTests` and `IndexedQueryTests` reset the stamp.

## Change

1. A re-seed updates the catalog in place.
   It finds each seeded exercise by `externalID` and each muscle by `slug`, updates the fields the dataset supplies, and inserts what is missing.
2. A re-seed deletes nothing the lifter made or logged.
   Custom exercises, the exercise links of logged workouts and of sessions, edited stimulus weights, edited volume targets and an exercise's own settings, such as its unit override or archived flag, all stay.
3. A seeded exercise that the bundled dataset no longer lists stays as it is.
4. A seed that failed partway can still be retried without breaking the `#Unique` rules on `externalID` and `slug`, as review WR-01 requires today.
5. A launch that re-seeds while the app shows Today and Progress does not crash.
6. A full `fitbodTests` run leaves the phone's seed stamp as it found it.

## Constraints

- No schema change: SchemaV7 stays the only schema.
- Do not change `SEED_VERSION.txt` or `exercises.json`.
- The seed stays off the main thread, in the model actor.
- The first seed into an empty store stays within its cold-launch bar.
  Record its time before and after in `notes.md`.

## Ownership

You may edit the files in `owns`, plus seed and persistence tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `SeedTests`, on an in-memory store, seed first.
  Then add a custom exercise, a finished workout and a session that use a seeded exercise, an edited stimulus weight and an edited volume target.
  Clear the stamp, and seed again.
  Assert that all of them survive with their links and values, and that the number of seeded exercises did not change.
  These assertions fail today.
- On the large phone, run `fitbodTests`, then read the stamp with `xcrun simctl spawn <phone> defaults read <bundle id> exercise_seed_version`.
  It is missing today.
- On the small phone, launch once with `-fitbod-reset-store -fitbod-seed-demo-workout` and quit.
  Set the stamp to 0 with `xcrun simctl spawn <phone> defaults write <bundle id> exercise_seed_version -int 0`, then launch twice without flags.
  It crashes today; record the crash, or the log line "Seeding library from version 0".

## Observable acceptance

- The repro test passes.
- The relaunch repro launches twice without a crash, and the demo workout is still in History with its exercise; a screenshot is in `screens/`.
- After a full `fitbodTests` run, the stamp reads the bundled version.
- `SeedTests`, `IndexedQueryTests`, `IncompatibleStoreRecoveryTests` and `DebugLaunchResetTests` pass.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- The store reset clears the stamp on purpose (`fitbod/Persistence/FitbodModelContainer.swift:98`), and `IncompatibleStoreRecoveryTests` and `DebugLaunchResetTests` pin that; keep it.
- If the importer takes the `UserDefaults` it reads, with `.standard` as the default, tests can pass their own suite and never touch the phone's stamp.
- Until this ticket merges, a host app that crashes at launch after a unit run recovers after one launch with `-fitbod-reset-store`.
