# Roadmap after milestone 1

Milestone 1 shipped the Chalkline design system and the core loop (library →
routine → workout → summary → history) with persistence, snapshots and
relaunch-safe rest timing. This is the prioritized plan for what comes next.
Priorities weigh value to a single serious lifter against risk to the data
already being logged.

## P0 — data safety debt (do before the next schema change)

1. **Freeze versioned schemas.** `SchemaV1/V2/V3.models` all list the *live*
   model classes, so the "V1" schema already contains V2/V3 fields (and the
   V1 test container reaches 13 entities). The next migration should
   introduce real frozen model snapshots per version (nested `@Model` types
   inside each `VersionedSchema`) and a test that migrates an actual V3 store
   file — before adding any field. Milestone 1 deliberately made **no**
   schema changes for this reason.
2. **Inverse for `Exercise` ↔ `SessionExercise` / `RoutineExercise`.** Today
   deleting an exercise relies on `ExerciseStore.delete` to nullify
   references explicitly. Once schemas are frozen, add the inverse with a
   `.nullify` rule and keep the store method as the single entry point.
3. **Snapshot the exercise name on `SessionExercise`.** History currently
   shows "Removed exercise" after a custom exercise is deleted; storing the
   name at log time keeps it readable forever.
4. **Unit canonicalisation.** Weights are stored as entered with a global
   lb/kg label (+ per-exercise override). Store a canonical unit per set so
   switching units converts history instead of relabelling it.
5. **Backup / export** (already Phase 6 in `.planning/ROADMAP.md`): JSON +
   CSV export and a restorable archive, so a lost phone or a bad migration
   never costs training history.

## P1 — training value

1. **Block-based programs** (Phase 4 plan): blocks with phases, scheduled
   deloads, week-by-week targets, block timeline on Today, block-periodized
   and hybrid progression (the progression picker already shows them only
   for routines that use them).
2. **Larger catalog + images.** Bundle (or lazily cache) the free-exercise-db
   images, add the non-strength categories behind a filter, and curate
   stimulus weights for the top 100 lifts (current defaults: 100 % primary,
   50 % secondary). The importer is already an in-place upsert, so refreshes
   are safe — see [exercise-library.md](exercise-library.md).
3. **Richer analytics** (Phase 5–6): per-exercise e1RM and best-set charts
   split by intent, weekly stimulus-weighted volume per muscle vs MEV/MAV/MRV,
   plateau detection, PR feed, weekly recap. Swift Charts; the data model
   already carries intent, RPE and stimulus weights.
4. **Workout ergonomics:** supersets in the logger (grouped cards, rest
   after the round), per-exercise rest overrides from the dock, set-type
   badges inline, a plate-loading view under the active set, "repeat last
   workout" from History.

## P2 — platform

1. **Live Activities / Dynamic Island polish.** The rest-timer Live
   Activity exists (widget extension); next: start/stop it from the
   persisted deadline on relaunch, show the next set ("Set 3 · 225 × 5"),
   and add an App Intent to complete the set or add 15 s from the Lock
   Screen.
2. **Apple Watch companion** for set completion and rest (out of scope for
   v1 by decision; revisit after the iPhone loop is mature).
3. **Sync.** iCloud (CloudKit) sync is technically within reach — models are
   already all-optional/defaulted — but requires the P0 schema work,
   conflict rules for in-progress workouts, and on-device migration testing.
   Keep local-only until backup/export exists.
4. **Widgets:** Today widget (next routine, this week's sets).

## P3 — polish

- Localization-ready strings (String Catalog) and number formatting per
  locale.
- Snapshot tests for Chalkline components across light/dark/AX sizes (the
  XCUITest screenshot tour covers screens today).
- Haptics and sound settings; Reduce Transparency audit.
- iPad layout (sidebar + detail) if ever wanted.
