# Exercise Seed Source

- **Repository:** https://github.com/yuhonas/free-exercise-db
- **Commit SHA:** `acd61f751fe15d618862ee3084f27e839222a28f`
- **Upstream commit date:** 2025-04-21T02:13:04Z
- **Upstream commit message:** "keep exercise photos top aligned on desktop (#18)"
- **Vendored on:** 2026-05-10
- **License:** The Unlicense (public domain) — no attribution required.
- **File:** `dist/exercises.json` → bundled at `fitbod/Resources/ExerciseSeed/exercises.json`, byte
  for byte. It holds no local row, so a refresh overwrites it safely.
- **Total exercises (raw):** 873 upstream, plus 141 local rows in `additions.json`.
- **Catalog:** 836 rows.
  809 are in the strength categories (`category ∈ {strength, powerlifting, olympic weightlifting, strongman}`: 675 upstream and 134 local), 7 are local cardio rows, and `curation.json` imports 11 upstream cardio rows and 9 plyometric moves.
  570 are listed; curation hides the other 266, and a hidden row stays listed while a routine or a logged workout uses it.
  `ExerciseCatalog` resolves the three files into the rows the importer writes.
- **Local additions (`additions.json`):** 27 Panatta machine exercises added 2026-05-11.
  These use the upstream JSON schema, `equipment: "machine"`, empty `images` arrays, and upstream's 17-muscle taxonomy.
  `Single-Leg_Kneeling_Leg_Curl` (hamstrings, machine) added 2026-11-08 for playtest finding FT-05; the seed went to version 3 so an installed library picks it up in place.
  Seed version 6 (2026-11-10) moved these rows out of `exercises.json` with their IDs unchanged.
  Seed version 7 (2026-11-10) adds 113 rows with `local:` IDs from the master table the user approved (RM-022), with no images or instructions; each takes its mechanic, force and level from the other rows of its family.
- **Curation overlay:** `curation.json` maps a row's `id` to local corrections: `name` (shown in place of the upstream name), `family` and `variant` (the Library groups variants under their family), `equipment` (a canonical `Equipment` raw value), `tracking` (a `Tracking` raw value), `brand` (a `MachineBrand` raw value), `loading` (`plate` or `stack`), `aliases` (other names people use), `hidden` (a duplicate or an oddity) and `import` (brings in a row outside the strength categories).
  Seed version 4 (2026-11-10) retagged 45 bodyweight moves that upstream left without equipment.
  Seed version 5 (2026-11-10) tags 9 holds and carries as `duration` and the band-assisted pull-up as `assisted_reps`, retags the 20 Smith machine rows as `smith_machine` and Bodyweight Flyes as `bodyweight`, and maps upstream `e-z curl bar` and `medicine ball` to their own equipment cases.
  Seed version 6 (2026-11-10) imports cardio rows under the names people use, with no muscles, so cardio adds no muscle volume.
  Seed version 7 (2026-11-10) curates every row from the approved master table: 388 rows get a new name, most in the family-and-variant form such as "Bench Press (Barbell)", and every listed row is in one of 172 families.
  It hides 266 duplicates and oddities.
  The name of a hidden duplicate and the earlier name of a renamed row are aliases of the row that stays, unless that name now belongs to another row or family.
  It gives 67 machines their loading (plate-loaded or stack) and the 27 Panatta rows their brand, tags 7 plate moves with the `plate` equipment, and imports 9 plyometric moves and 2 more cardio rows.
  Stretching stays out, and so do the cardio and plyometric rows the overlay does not import.
  A refresh keeps the overlay.
  `ExerciseCatalogTests` fails if an overlay ID or an equipment, tracking, brand or loading value does not exist, if two listed rows share a name, if a listed row has no family, if a listed row tracks a load on `other` equipment, or if an alias is in two families or names another family.
  A new upstream row has no family, so a refresh curates or hides it before that test passes.
- **Muscle credits (`muscles.json`):** seed version 8 (2026-11-11, RM-065) replaces upstream's muscle tags on every listed row.
  `families` gives each family its primary muscles and its secondary muscles with their weights; `exercises` gives a variant that trains the muscles differently its own, keyed by ID.
  A primary muscle gets 1.0 of a working set: the muscles the exercise is meant to train.
  A secondary muscle gets 0.5 when it moves the load through a real range, such as the triceps and front delts in a press or the biceps and rear delts in a row, and 0.25 for a smaller helper or a muscle that holds a heavy load still, such as the forearms in a deadlift.
  A stabilizer that only braces gets nothing, such as the abs in a squat.
  The app splits upstream's one "shoulders" muscle into front, side and rear delts, as the RP volume landmarks list them.
  A row the file does not cover, such as a hidden row a workout still uses, keeps the upstream tags at 1.0 and 0.5, with "shoulders" read as the front delts for a push, the rear delts for a pull and the side delts otherwise.
  Cardio rows get no muscles.
  `ExerciseCatalogTests` fails if a listed row other than cardio has no profile, if the file names a family, row or muscle that does not exist, or if a weight is outside its range.
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
   muscle by `slug`, updates the fields the dataset supplies and inserts what is missing. A
   catalog exercise's stimulus rows then match its muscle credits exactly; no exercise is deleted.
7. Curate each new upstream row in `curation.json`: a family and a name in the family-and-variant form, or `hidden`.
   `ExerciseCatalogTests.visibleRows` lists the rows that still need it.
   A row in a new family also needs that family's muscle credits in `muscles.json`.

## Schema notes (as of 2026-05-10 vendoring)

- Raw fields per row: `id`, `name`, `force?`, `level`, `mechanic?`, `equipment?`,
  `primaryMuscles`, `secondaryMuscles`, `instructions`, `category`, `images`.
- 17 distinct muscle slugs across `primaryMuscles` + `secondaryMuscles`:
  `abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes,`
  `hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps`.
  The app tracks 19: `shoulders` becomes `front delts`, `side delts` and `rear delts` (see Muscle credits).
- 12 distinct raw `equipment` values (post-filter to strength only): `bands, barbell, body only,`
  `cable, dumbbell, e-z curl bar, exercise ball, kettlebells, machine, medicine ball, other`,
  plus `null` (no equipment field). `EquipmentMapper.swift` is the single canonical translation table.
- 7 categories total; the catalog keeps the 4 listed above, plus any row `curation.json` imports.
