# Exercise catalog

## What ships

The app bundles a snapshot of [free-exercise-db](https://github.com/yuhonas/free-exercise-db)
(public domain / Unlicense): `fitbod/Resources/ExerciseSeed/exercises.json`,
900 entries (873 upstream + 27 local Panatta machine additions). On first
launch `ExerciseLibraryImporter` keeps the strength categories
(`strength`, `powerlifting`, `olympic weightlifting`, `strongman`) — **702
exercises** — plus the 17 canonical muscle groups and the primary (100 %) /
secondary (50 %) stimulus rows. Provenance and the exact upstream commit are
in `fitbod/Resources/ExerciseSeed/SOURCE.md`.

Images are referenced by path (`imagePaths`) but not bundled; the detail
screen shows instructions and muscles. Your own exercises (Library → **+**,
or "Create “…”" from an empty search, or "Copy as custom exercise") live
alongside the catalog and can carry a photo.

## Importing a larger or newer library

The importer is an **in-place upsert** (milestone 1): a refresh updates
built-in exercises matched by `externalID`, adds new ones, rebuilds their
muscle-stimulus rows, and never deletes anything — so routines, logged
workouts, per-exercise tweaks (increment, bar weight, unit), muscle volume
targets and custom exercises all survive. (Before milestone 1 a refresh
deleted every exercise first, which would have orphaned routines and
history; see `SeedTests.reseedPreservesUserData`.)

### Newer free-exercise-db snapshot

1. Download `dist/exercises.json` from the commit you want:
   ```bash
   curl -sSL "https://raw.githubusercontent.com/yuhonas/free-exercise-db/<SHA>/dist/exercises.json" \
     -o fitbod/Resources/ExerciseSeed/exercises.json
   ```
   (Re-apply the 27 local Panatta entries if you want to keep them — they
   are the entries whose `id` starts with `Panatta_`.)
2. Update `SOURCE.md` (commit SHA, dates, counts).
3. Bump `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` (e.g. `1` → `2`).
   The next launch sees the bundled version above the stored stamp
   (`UserDefaults["exercise_seed_version"]`) and re-runs the import.
4. Run the decoding and seed tests:
   ```bash
   xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:fitbodTests/DTODecodingTests -only-testing:fitbodTests/SeedTests
   ```

### Including more categories

`EquipmentMapper.acceptedCategories` decides what is imported. Adding
`"stretching"`, `"plyometrics"` or `"cardio"` brings in the rest of the
900 entries (they log fine as sets × reps; the progression engine treats
them like any other lift). Bump `SEED_VERSION.txt` afterwards.

### Another dataset (e.g. exercemus/exercises, ~1,100 entries)

Convert it to the free-exercise-db schema — one JSON array of objects with
`id` (stable, unique), `name`, `force`, `level`, `mechanic`, `equipment`,
`primaryMuscles`, `secondaryMuscles` (using the 17 slugs: abdominals,
abductors, adductors, biceps, calves, chest, forearms, glutes, hamstrings,
lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps),
`instructions`, `category`, `images` — and either replace `exercises.json`
or append to it, then bump `SEED_VERSION.txt`. Keep `id`s stable across
refreshes: they are how the upsert recognises an exercise you have already
logged. Check per-entry licenses (exercemus requires attribution per
exercise; free-exercise-db does not).

Equipment strings are normalised by `EquipmentMapper.map(_:)` (e.g. `body
only` → bodyweight, `e-z curl bar` → barbell); unknown values become
`other`. Muscle slugs outside the 17 are skipped with a debug log.
