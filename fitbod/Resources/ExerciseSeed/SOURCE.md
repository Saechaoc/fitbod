# Exercise Seed Source

- **Repository:** https://github.com/yuhonas/free-exercise-db
- **Commit SHA:** `acd61f751fe15d618862ee3084f27e839222a28f`
- **Upstream commit date:** 2025-04-21T02:13:04Z
- **Upstream commit message:** "keep exercise photos top aligned on desktop (#18)"
- **Vendored on:** 2026-05-10
- **License:** The Unlicense (public domain) — no attribution required.
- **File:** `dist/exercises.json` → bundled at `fitbod/Resources/ExerciseSeed/exercises.json`
- **Total exercises (raw):** 900 (873 upstream + 27 local Panatta machine additions)
- **After strength filter (`category ∈ {strength, powerlifting, olympic weightlifting, strongman}`):** 702
- **Local additions:** 27 Panatta machine exercises added 2026-05-11. These use the upstream
  JSON schema, `equipment: "machine"`, empty `images` arrays, and the existing 17-muscle taxonomy.
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
6. Future phases may add a delta-migration; Phase 1 only handles empty-to-full.

## Schema notes (as of 2026-05-10 vendoring)

- Raw fields per row: `id`, `name`, `force?`, `level`, `mechanic?`, `equipment?`,
  `primaryMuscles`, `secondaryMuscles`, `instructions`, `category`, `images`.
- 17 distinct muscle slugs across `primaryMuscles` + `secondaryMuscles`:
  `abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes,`
  `hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps`.
- 12 distinct raw `equipment` values (post-filter to strength only): `bands, barbell, body only,`
  `cable, dumbbell, e-z curl bar, exercise ball, kettlebells, machine, medicine ball, other`,
  plus `null` (no equipment field). `EquipmentMapper.swift` is the single canonical translation table.
- 7 categories total; v1 retains only the 4 listed above (cardio/stretching/plyometrics dropped).
