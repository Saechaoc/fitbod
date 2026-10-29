# Architecture

## Entity Map

| Entity | Role | Key Relationships |
|--------|------|-------------------|
| `Exercise` | Catalog item (seeded from free-exercise-db + user-added customs) | many-to-many `MuscleGroup` (via `ExerciseMuscleMapping`), many `RoutineExerciseTemplate`, many `SessionExercise` |
| `MuscleGroup` | 17 muscles from free-exercise-db, plus optional user-defined splits | many-to-many `Exercise` via join entity carrying `weight: Double` |
| `ExerciseMuscleMapping` | Join entity: stimulus weight per muscle (e.g., bench press → chest 1.0, triceps 0.4) | belongs-to `Exercise`, belongs-to `MuscleGroup`, `weight: Double`, `role: primary/secondary` |
| `Routine` | Template (the plan) | one-to-many `RoutineExerciseTemplate`, optional `Block` |
| `RoutineExerciseTemplate` | Per-exercise prescription within a routine | belongs-to `Routine`, belongs-to `Exercise`, holds `intent`, `targetReps`, `targetRPE`, `progressionModel`, `prescribedWeight` |
| `Session` | A logged instance of a routine on a date | belongs-to `Routine` (nullable — sessions can be freestanding), one-to-many `SessionExercise` |
| `SessionExercise` | Logged exercise within a session — carries the *evaluated* prescription at log time | belongs-to `Session`, belongs-to `Exercise`, one-to-many `SetLog` |
| `SetLog` | One set: weight, reps, RPE, rest, tempo, notes | belongs-to `SessionExercise`, `setKind: warmup/working/backoff/dropset` |
| `Block` | Periodization block | one-to-many `Routine`, holds `phase`, `weekCount`, `deloadEveryNWeeks` |
| `VolumeLandmark` | User-tunable MEV/MAV/MRV thresholds per muscle | belongs-to `MuscleGroup`, holds `mev`, `mav`, `mrv` (weekly sets) |

## Key Design Decisions

- **Template vs instance split:** `RoutineExerciseTemplate` is the prescription; `SessionExercise` is what was actually logged. Fields are copied at log time — never projected from the template at read time.
- **Cascade strategy:** Session→SessionExercise→SetLog cascade on delete. Exercise→history: nullify (soft-delete via `isArchived: Bool`).
- **Free-exercise-db as catalog seed:** ~800 exercises, public domain, bundled as JSON and seeded on first launch. Stimulus weights and movement patterns are manually curated on top.

## Layer Structure

```
TabView (root)
├── Today / Active Session tab  → NavigationStack(SessionPath)
├── Routines tab                → NavigationStack(RoutinePath)
├── Exercise Library tab        → NavigationStack(ExercisePath)
├── Progress / Stats tab        → NavigationStack(ProgressPath)
└── Settings / Blocks tab       → NavigationStack(SettingsPath)
```

State layers:
- **Persistent:** SwiftData `@Model` types, queried with `@Query` directly in views
- **Session-scoped ephemeral:** `@Observable` objects passed via `.environment(_:)` (e.g., active workout session)
- **View-local:** `@Observable` view models owned by `@State`, holding transient UI state
