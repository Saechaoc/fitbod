# Exercise Seed Source

- **Repository:** https://github.com/yuhonas/free-exercise-db
- **Commit SHA:** `acd61f751fe15d618862ee3084f27e839222a28f`
- **Upstream commit date:** 2025-04-21T02:13:04Z
- **Upstream commit message:** "keep exercise photos top aligned on desktop (#18)"
- **Vendored on:** 2026-05-10
- **License:** The Unlicense (public domain) — no attribution required.
- **File:** `dist/exercises.json` → bundled at `fitbod/Resources/ExerciseSeed/exercises.json`, byte
  for byte. It holds no local row, so a refresh overwrites it safely.
- **Total exercises (raw):** 873 upstream, plus 28 local rows in `additions.json`.
- **Catalog:** 712 rows. 703 are in the strength categories
  (`category ∈ {strength, powerlifting, olympic weightlifting, strongman}`: 675 upstream and the 28
  local rows) and 9 are cardio rows that `curation.json` imports.
  `ExerciseCatalog` resolves the three files into the rows the importer writes.
- **Local additions (`additions.json`):** 27 Panatta machine exercises added 2026-05-11. These use
  the upstream JSON schema, `equipment: "machine"`, empty `images` arrays, and the existing
  17-muscle taxonomy. `Single-Leg_Kneeling_Leg_Curl` (hamstrings, machine) added 2026-11-08 for
  playtest finding FT-05; the seed went to version 3 so an installed library picks it up in place.
  Seed version 6 (2026-11-10) moved these rows out of `exercises.json` with their IDs unchanged.
- **Curation overlay:** `curation.json` maps a row's `id` to local corrections: `equipment`
  (a canonical `Equipment` raw value), `tracking` (a `Tracking` raw value), `name` (shown in place
  of the upstream name), `aliases` (other names people use) and `import` (brings in a row outside
  the strength categories). Seed version 4
  (2026-11-10) retagged 45 bodyweight moves that upstream left without equipment. Seed version 5
  (2026-11-10) tags 9 holds and carries as `duration` and the band-assisted pull-up as
  `assisted_reps`, retags the 20 Smith machine rows as `smith_machine` and Bodyweight Flyes as
  `bodyweight`, and maps upstream `e-z curl bar` and `medicine ball` to their own equipment cases.
  Seed version 6 (2026-11-10) imports cardio rows under the names people use, with no
  muscles, so cardio adds no muscle volume: Stair Climber, Stepmill and Elliptical log a time and a
  level; Treadmill Run, Treadmill Walk, Stationary Bike, Recumbent Bike and Rowing Machine log a
  time and a distance; Jump Rope logs a time. Stretching, plyometrics and the other cardio rows
  stay out.
  A refresh keeps the overlay; `ExerciseCatalogTests` fails if an overlay ID, equipment or tracking
  value no longer exists.
- **SEED_VERSION.txt:** Local stamp; bump to trigger re-seed via
  `UserDefaults["exercise_seed_version"]` (plan `02-02`).

## Refresh procedure

1. Look up the new upstream commit SHA:
   ```bash
   curl -sSL "https://api.github.com/repos/yuhonas/free-exercise-db/commits/main" | jq -r .sha
   ```
2. Download the new `dist/exercises.json` from that SHA:
   ```bash
   curl -sSL "https://raw.githubusercontent.com/yuhonas/free-exercise-db/<NEW_SHA>/dist/exercises.json" \
     -o fitbod/Resources/ExerciseSeed/exercises.json
   ```
3. Update the **Commit SHA** + **Upstream commit date** + **Vendored on** lines in this file.
4. Bump `SEED_VERSION.txt` from N to N+1.
5. Run `xcodebuild test -only-testing:fitbodTests/DTODecodingTests` to confirm the schema still parses.
6. A bump re-seeds in place: the importer finds each seeded exercise by `externalID` and each
   muscle by `slug`, updates the fields the dataset supplies, inserts what is missing and deletes
   nothing. It never changes or removes an existing stimulus row, so a dataset that moves a muscle
   between primary and secondary, or drops it, needs handling in that bump.

## Schema notes (as of 2026-05-10 vendoring)

- Raw fields per row: `id`, `name`, `force?`, `level`, `mechanic?`, `equipment?`,
  `primaryMuscles`, `secondaryMuscles`, `instructions`, `category`, `images`.
- 17 distinct muscle slugs across `primaryMuscles` + `secondaryMuscles`:
  `abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes,`
  `hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps`.
- 12 distinct raw `equipment` values (post-filter to strength only): `bands, barbell, body only,`
  `cable, dumbbell, e-z curl bar, exercise ball, kettlebells, machine, medicine ball, other`,
  plus `null` (no equipment field). `EquipmentMapper.swift` is the single canonical translation table.
- 7 categories total; the catalog keeps the 4 listed above, plus any row `curation.json` imports.
