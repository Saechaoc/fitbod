---
phase: 01
plan: 01-01
wave: 1
slug: entity-models-and-enums
complexity: L
requirements: ["FOUND-02", "FOUND-03", "FOUND-04", "LIB-06"]
covers_pitfalls: ["#1 (template/instance fields exist Day 1)", "#3 (denormalized muscle slugs)", "#5 (stimulus weight schema)", "#7 (indexes on hot fields)", "#9 (enum *Raw: String)"]
depends_on: ["00-01"]
files_modified:
  - fitbod/Models/Exercise.swift  # NEW
  - fitbod/Models/MuscleGroup.swift  # NEW
  - fitbod/Models/ExerciseMuscleStimulus.swift  # NEW
  - fitbod/Models/Routine.swift  # NEW
  - fitbod/Models/RoutineExercise.swift  # NEW
  - fitbod/Models/Session.swift  # NEW
  - fitbod/Models/SessionExercise.swift  # NEW
  - fitbod/Models/SetEntry.swift  # NEW
  - fitbod/Models/Block.swift  # NEW
  - fitbod/Models/BlockPhase.swift  # NEW
  - fitbod/Models/UserSettings.swift  # NEW
  - fitbod/Models/MuscleVolumeTarget.swift  # NEW
  - fitbod/Models/Enums/Intent.swift  # NEW
  - fitbod/Models/Enums/ProgressionKind.swift  # NEW
  - fitbod/Models/Enums/Equipment.swift  # NEW
  - fitbod/Models/Enums/Mechanic.swift  # NEW
  - fitbod/Models/Enums/Force.swift  # NEW
  - fitbod/Models/Enums/Level.swift  # NEW
  - fitbod/Models/Enums/Pattern.swift  # NEW
  - fitbod/Models/Enums/MuscleRegion.swift  # NEW
  - fitbod/Models/Enums/WeightUnit.swift  # NEW
  - fitbod/Models/Enums/BlockPhaseKind.swift  # NEW
  - fitbod/Models/Enums/SetType.swift  # NEW (warmup/working/drop/failure/rest_pause — anticipating Phase 2 use)
created: 2026-05-10
---

# Plan 01-01 — Entity Models and Enums

> **Wave 1 / Sequence 1.** The single largest plan in Phase 1. Authors all 12 SwiftData `@Model` entities and their 11 supporting enums — the load-bearing schema that every later phase composes on. This plan ships ONLY the entity definitions, not the schema wrapper (which comes in `01-PLAN-01-02`).

## Goal

Author 12 `@Model` final classes and 11 `String`-backed enums in their final, locked shape. Every property optional or default-valued (FOUND-02), every enum persisted as `*Raw: String` (FOUND-03), every hot-field has a `#Index` declaration (FOUND-04), every relationship has an explicit `inverse:` (per CONTEXT.md), and the cascade rules match `01-CONTEXT.md` Area 4 exactly.

## Requirements Covered

- **FOUND-02**: Every property has a default value (`= 0`, `= ""`, `= UUID()`, `= .now`, `= []`, `= nil`) or is `Optional`. Every relationship is `Optional` and uses `[]` default for to-many. iCloud-shape insurance even though CloudKit is v2.
- **FOUND-03**: Every domain enum is stored as `*Raw: String` (e.g., `intentRaw: String = "hypertrophy"`) with a sibling computed accessor (`var intent: Intent { ... }`) defined in an `extension`. Enum types are `String`-backed and `CaseIterable`.
- **FOUND-04**: `#Index<T>([\.keyPath], ...)` declarations on every entity that participates in hot queries. Table below.
- **LIB-06**: The `Equipment` enum has 8 cases distinguishing bodyweight, weighted-bodyweight, machine, dumbbell, barbell, cable, bands, and other. The `Exercise.equipmentRaw` field stores this.

## Files to Create / Modify

All 23 files are NEW under `fitbod/Models/` and `fitbod/Models/Enums/`.

### Entities (12 files in `fitbod/Models/`)

| File | Purpose | Indexes | Cascade rules (out-edges) |
|------|---------|---------|---------------------------|
| `Exercise.swift` | Library entry — built-in or custom | `#Index<Exercise>([\.canonicalName], [\.equipmentRaw], [\.mechanicRaw], [\.isCustom], [\.primaryMuscleSlugsJoined])` + `#Unique<Exercise>([\.externalID])` | `muscleStimuli: cascade` (owned join rows) |
| `MuscleGroup.swift` | One of 17 canonical muscle slugs | `#Unique<MuscleGroup>([\.slug])` | `stimuli: cascade`, `volumeTargets: cascade` |
| `ExerciseMuscleStimulus.swift` | Join row carrying stimulus weight | (none — small table) | (none — leaf relative to exercise + muscle) |
| `Routine.swift` | Template (Phase 2 will use; schema exists now) | (none — small table v1) | `exercises: cascade` |
| `RoutineExercise.swift` | Template line item | (none — accessed via routine) | (none — leaf) |
| `Session.swift` | Instance — logged workout (Phase 2 use) | `#Index<Session>([\.startedAt], [\.sourceRoutineID])` | `exercises: cascade` |
| `SessionExercise.swift` | Snapshotted prescription + actual sets (Phase 2 use) | `#Index<SessionExercise>([\.intentRaw])` | `sets: cascade`; `exercise: nullify` (LIB-05 cascade rule) |
| `SetEntry.swift` | Single logged set (Phase 2 use) | (none — accessed via sessionExercise) | (none — leaf) |
| `Block.swift` | Periodization block (Phase 4 use; schema exists now) | (none v1) | `phases: cascade` |
| `BlockPhase.swift` | Phase within a block (Phase 4 use) | (none v1) | (none — leaf) |
| `UserSettings.swift` | Singleton settings row | (none — single row) | (none) |
| `MuscleVolumeTarget.swift` | Per-muscle MEV/MAV/MRV (Phase 5 use) | (none v1) | (none — leaf relative to muscle) |

### Enums (11 files in `fitbod/Models/Enums/`)

| File | Cases | Default |
|------|-------|---------|
| `Intent.swift` | `strength, hypertrophy, power, endurance, technique` | `hypertrophy` |
| `ProgressionKind.swift` | `rpe, double, block, hybrid` | `double` |
| `Equipment.swift` | `barbell, dumbbell, machine, cable, bands, bodyweight, weightedBodyweight, kettlebell, other` | `other` — **LIB-06 anchor** |
| `Mechanic.swift` | `compound, isolation` | `compound` |
| `Force.swift` | `push, pull, static` | (no default — nullable) |
| `Level.swift` | `beginner, intermediate, expert` | (no default — nullable) |
| `Pattern.swift` | `horizontalPush, verticalPush, horizontalPull, verticalPull, squat, hinge, lunge, carry, core` | (no default — nullable; Phase 1 leaves `patternRaw` nil per Open Question #5) |
| `MuscleRegion.swift` | `upper, lower, core` | `upper` |
| `WeightUnit.swift` | `lb, kg` | `lb` |
| `BlockPhaseKind.swift` | `accumulation, intensification, realization, deload` | `accumulation` |
| `SetType.swift` | `warmup, working, drop, failure, restPause` | `working` |

All enums conform to `String, CaseIterable, Sendable` and provide a static `default` if relevant.

## Detailed Schema (per-entity field set, locked)

Below is the field-by-field contract. The executor builds against this exactly; no field additions or renames without a new plan.

### `Exercise`

```
final class Exercise {
  #Index<Exercise>([\.canonicalName], [\.equipmentRaw], [\.mechanicRaw], [\.isCustom], [\.primaryMuscleSlugsJoined])
  #Unique<Exercise>([\.externalID])

  @Attribute(.unique) id: UUID = UUID()
  externalID: String? = nil                    # dataset row id; nil for custom (LIB-04)
  name: String = ""
  canonicalName: String = ""                   # lowercased + diacritic-folded; #Index hot
  equipmentRaw: String = "other"               # Equipment enum
  mechanicRaw: String = "compound"
  forceRaw: String? = nil                      # Force? optional
  levelRaw: String? = nil                      # Level? optional
  patternRaw: String? = nil                    # Pattern? nullable v1 (Open Q #5)
  category: String = "strength"                # filter discriminator; populated from dataset
  instructions: [String] = []
  imagePaths: [String] = []                    # relative paths; binaries deferred (CONTEXT § deferred)
  @Attribute(.externalStorage) imageData: Data? = nil  # optional custom image (LIB-04)
  isCustom: Bool = false                       # #Index hot
  primaryMuscleSlugsJoined: String = ""        # denormalized "|chest|triceps|" for muscle predicate (Pitfall 3)
  createdAt: Date = .now

  @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.exercise)
  muscleStimuli: [ExerciseMuscleStimulus]? = []

  init() {}                                    # no-arg keeps FOUND-02 invariant
  convenience init(...)                        # parameterized convenience (per RESEARCH Example 3)
}

extension Exercise {
  var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
  var mechanic: Mechanic { Mechanic(rawValue: mechanicRaw) ?? .compound }
  var force: Force?      { forceRaw.flatMap(Force.init) }
  var level: Level?      { levelRaw.flatMap(Level.init) }
  var pattern: Pattern?  { patternRaw.flatMap(Pattern.init) }
}
```

### `MuscleGroup`

```
final class MuscleGroup {
  #Unique<MuscleGroup>([\.slug])

  @Attribute(.unique) id: UUID = UUID()
  slug: String = ""                            # canonical: "chest", "lats", "triceps", ...
  displayName: String = ""                     # "Chest", "Lats", ...
  regionRaw: String = "upper"                  # MuscleRegion

  @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.muscle)
  stimuli: [ExerciseMuscleStimulus]? = []

  @Relationship(deleteRule: .cascade, inverse: \MuscleVolumeTarget.muscle)
  volumeTargets: [MuscleVolumeTarget]? = []

  init() {}
  convenience init(slug: String, displayName: String, region: MuscleRegion = .upper)
}

extension MuscleGroup {
  var region: MuscleRegion { MuscleRegion(rawValue: regionRaw) ?? .upper }
}
```

### `ExerciseMuscleStimulus`

```
final class ExerciseMuscleStimulus {
  @Attribute(.unique) id: UUID = UUID()
  exercise: Exercise? = nil                    # inverse declared on Exercise.muscleStimuli
  muscle: MuscleGroup? = nil                   # inverse declared on MuscleGroup.stimuli
  role: String = "primary"                     # "primary" | "secondary"
  weight: Double = 1.0                         # 0.0..1.0 stimulus weight (PITFALLS #5)

  init() {}
  convenience init(exercise: Exercise, muscle: MuscleGroup, role: String, weight: Double)
}
```

### `Routine`

```
final class Routine {
  @Attribute(.unique) id: UUID = UUID()
  name: String = ""
  notes: String? = nil
  createdAt: Date = .now
  updatedAt: Date = .now
  isArchived: Bool = false
  block: Block? = nil                          # optional link

  @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
  exercises: [RoutineExercise]? = []

  init() {}
}
```

### `RoutineExercise`

```
final class RoutineExercise {
  @Attribute(.unique) id: UUID = UUID()
  routine: Routine? = nil
  exercise: Exercise? = nil
  orderIndex: Int = 0
  intentRaw: String = "hypertrophy"            # Intent enum
  targetSets: Int = 3
  targetRepsLow: Int = 8
  targetRepsHigh: Int = 12
  targetRPE: Double? = nil
  targetRIR: Int? = nil
  prescribedRestSeconds: Int = 120
  tempo: String? = nil                         # e.g. "3-1-1-0"
  notes: String? = nil
  progressionKindRaw: String = "double"        # ProgressionKind
  generateWarmups: Bool = false                # default false; first compound flag set in Phase 3

  init() {}
}

extension RoutineExercise {
  var intent: Intent              { Intent(rawValue: intentRaw) ?? .hypertrophy }
  var progressionKind: ProgressionKind { ProgressionKind(rawValue: progressionKindRaw) ?? .double }
}
```

### `Session`

```
final class Session {
  #Index<Session>([\.startedAt], [\.sourceRoutineID])

  @Attribute(.unique) id: UUID = UUID()
  startedAt: Date = .now
  completedAt: Date? = nil
  routineSnapshotName: String = ""
  sourceRoutineID: UUID? = nil                 # weak soft reference to template (PITFALLS #1)
  block: Block? = nil
  notes: String? = nil
  totalDurationSeconds: Int? = nil

  @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
  exercises: [SessionExercise]? = []

  init() {}
}
```

### `SessionExercise`

```
final class SessionExercise {
  #Index<SessionExercise>([\.intentRaw])

  @Attribute(.unique) id: UUID = UUID()
  session: Session? = nil
  exercise: Exercise? = nil                    # nullify on Exercise delete (LIB-05)
  orderIndex: Int = 0
  intentRaw: String = "hypertrophy"            # SNAPSHOTTED (PITFALLS #1)
  targetSets: Int = 3
  targetRepsLow: Int = 8
  targetRepsHigh: Int = 12
  targetRPE: Double? = nil
  targetRIR: Int? = nil
  prescribedRestSeconds: Int = 120
  tempo: String? = nil
  progressionKindRaw: String = "double"
  prescribedWeight: Double? = nil

  @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
  sets: [SetEntry]? = []

  init() {}
}

extension SessionExercise {
  var intent: Intent { Intent(rawValue: intentRaw) ?? .hypertrophy }
}
```

**Cascade rule note for `SessionExercise.exercise`:** The `exercise` field is a plain optional relationship (NOT declared with `@Relationship(deleteRule: .cascade, ...)`). The inverse declaration lives on `Exercise.muscleStimuli` (cascade) but `Exercise → SessionExercise` is NOT cascaded — it nullifies by default because we do not declare a forward relationship from `Exercise` to `SessionExercise`. Verified via `01-RESEARCH.md` § Cascade Rules and `CONTEXT.md` Area 4. The cascade-test (`CascadeRuleTests/exerciseToSessionExerciseNullifies`) in `01-PLAN-01-03` proves it.

### `SetEntry`

```
final class SetEntry {
  @Attribute(.unique) id: UUID = UUID()
  sessionExercise: SessionExercise? = nil
  orderIndex: Int = 0
  weight: Double = 0
  reps: Int = 0
  rpe: Double? = nil
  rir: Int? = nil
  restAfterSeconds: Int? = nil
  tempoActual: String? = nil
  notes: String? = nil
  isWarmup: Bool = false
  setTypeRaw: String = "working"               # SetType enum (added now for Phase 2 schema parity)
  completedAt: Date = .now

  init() {}
}

extension SetEntry {
  var setType: SetType { SetType(rawValue: setTypeRaw) ?? .working }
}
```

### `Block`

```
final class Block {
  @Attribute(.unique) id: UUID = UUID()
  name: String = ""
  startDate: Date = .now
  endDate: Date? = nil
  notes: String? = nil
  isActive: Bool = false

  @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
  phases: [BlockPhase]? = []

  @Relationship(inverse: \Routine.block) routines: [Routine]? = []
  @Relationship(inverse: \Session.block) sessions: [Session]? = []

  init() {}
}
```

### `BlockPhase`

```
final class BlockPhase {
  @Attribute(.unique) id: UUID = UUID()
  block: Block? = nil
  orderIndex: Int = 0
  nameRaw: String = "accumulation"             # BlockPhaseKind
  weeks: Int = 4
  volumeMultiplier: Double = 1.0
  intensityMultiplier: Double = 1.0
  notes: String? = nil

  init() {}
}

extension BlockPhase {
  var kind: BlockPhaseKind { BlockPhaseKind(rawValue: nameRaw) ?? .accumulation }
}
```

### `UserSettings`

```
final class UserSettings {
  @Attribute(.unique) id: UUID = UUID()
  unitsRaw: String = "lb"                      # WeightUnit — SET-01 anchor
  defaultProgressionKindRaw: String = "double"
  warmupSchemeRaw: String = "standard"
  customWarmupPercents: [Double]? = nil
  plateauWindowSessions: Int = 4
  plateauTolerance: Double = 0.005             # 0.5% e1RM flat → stalled (Phase 5 use)
  deloadAlertEnabled: Bool = true
  weekStartsMonday: Bool = true

  init() {}

  static func `default`() -> UserSettings {
    let s = UserSettings()
    s.unitsRaw = "lb"
    return s
  }
}

extension UserSettings {
  var weightUnit: WeightUnit {
    get { WeightUnit(rawValue: unitsRaw) ?? .lb }
    set { unitsRaw = newValue.rawValue }
  }
  var defaultProgressionKind: ProgressionKind {
    get { ProgressionKind(rawValue: defaultProgressionKindRaw) ?? .double }
    set { defaultProgressionKindRaw = newValue.rawValue }
  }
}
```

### `MuscleVolumeTarget`

```
final class MuscleVolumeTarget {
  @Attribute(.unique) id: UUID = UUID()
  muscle: MuscleGroup? = nil
  mev: Int = 8
  mav: Int = 14
  mrv: Int = 22
  mv: Int = 6                                  # maintenance
  notes: String? = nil

  init() {}
}
```

## Acceptance Criteria

1. All 12 entity files and 11 enum files exist at the paths listed under "Files to Create / Modify."
2. Each entity file declares a `final class` with `@Model`, the `init() {}` no-arg initializer, and (where applicable) a convenience init.
3. Every property on every entity is either Optional or has a default literal (verified by `grep -E '^\s+(var|let)\s+\w+\s*:\s*[^=?]+$' fitbod/Models/*.swift | grep -v '^#' | grep -c .` — count must be `0` after filtering out comments).
4. Every domain enum is stored as `*Raw: String` on its owning entity (verified by `grep -E 'var \w+Raw: String' fitbod/Models/*.swift | grep -v '^#' | wc -l` ≥ 12).
5. Each entity that owns a hot query field has a `#Index` macro at the top of the class body — verified by `grep -c '#Index<' fitbod/Models/*.swift` ≥ 4 (Exercise + Session + SessionExercise + at least one more).
6. The `Equipment` enum has exactly 9 cases (8 from LIB-06 + `kettlebell` per RESEARCH Open Q #4): `grep -c 'case ' fitbod/Models/Enums/Equipment.swift` == 9.
7. The project compiles **standalone in `fitbod/Models/`** as soon as plan `01-02` wires the schema — i.e., these files have no external imports beyond `Foundation` and `SwiftData`. (At the end of plan 01-01 alone, the project still fails to compile because `fitbodApp.swift` references the deleted `Item`. That is resolved in plan `01-02`.)

## Test Expectations

This plan ships entity definitions only — tests come in plan `01-PLAN-01-03` (which has the `PreviewModelContainer` to run them against). The relevant tests in that plan will exercise:

- `SchemaV1Tests/allPropertiesOptionalOrDefaulted` — reflection check that every property is Optional or has a default → verifies FOUND-02 across all 12 entities.
- `EnumPersistenceTests/*` — round-trip every `*Raw` enum through insert + fetch → verifies FOUND-03.
- `CascadeRuleTests/exerciseToMuscleStimulusCascades` — deleting `Exercise` cascades into `ExerciseMuscleStimulus` rows.
- `CascadeRuleTests/exerciseToSessionExerciseNullifies` — deleting `Exercise` leaves `SessionExercise.exercise == nil` (LIB-05).
- `CascadeRuleTests/sessionCascadesToSetEntry` — `Session → SessionExercise → SetEntry` cascade chain.
- `EnumTests/equipmentHasNineCases` — compile-time assertion (LIB-06 anchor).

## Decisions Honored

- **C-2 (CONTEXT.md Area 4 — cascade rules):** `Exercise → SessionExercise: nullify`, `Exercise → ExerciseMuscleStimulus: cascade`, `Routine → RoutineExercise: cascade`, `Session → SessionExercise → SetEntry: cascade chain`. Encoded as outlined above.
- **C-3 (CONTEXT.md Area 4 — `*Raw: String`):** Every enum field is `*Raw: String` with computed accessor in an `extension`.
- **C-4 (CONTEXT.md Area 4 — all optional / defaulted):** Every property is `Optional` or has a default literal. iCloud-shape insurance.
- **R-2 (RESEARCH Pitfall 3 — denormalized muscle slugs):** `Exercise.primaryMuscleSlugsJoined: String` field added; indexed in `#Index<Exercise>` declaration; populated at seed time in plan `02-02`.
- **R-3 (RESEARCH Open Q #4 — `weightedBodyweight` case):** Added to `Equipment` enum now to avoid a Phase 2 migration.
- **R-4 (RESEARCH Open Q #5 — `Pattern` enum):** Added now as nullable `patternRaw: String? = nil` on Exercise; populated by curation in Phase 2 or later.
- **R-5 (RESEARCH Code Example 3 — `init() {}` pattern):** Every `@Model` ships a no-arg init AND a parameterized convenience init. The no-arg init satisfies FOUND-02; the convenience init keeps call sites tidy.

## Anti-Patterns Avoided

- **Not** decoding JSON straight into `@Model` via `Codable` (PITFALLS #2 in RESEARCH). The JSON decode lives in plan `02-01`'s DTO struct.
- **Not** parking enums as `Codable` on the `@Model` types — `*Raw: String` only (PITFALLS #9, RESEARCH § Pattern 6).
- **Not** mirroring entities in a parallel `*ViewModel` layer (FOUND-06 anti-pattern). No `*ViewModel.swift` files exist in this plan.
- **Not** wrapping `@Query` inside an `@Observable` class — the schema layer doesn't even reference `@Query`. (FOUND-06 is enforced in the view layer in Wave 3.)
- **Not** assigning relationships in `init(...)` before `context.insert(model)` — every entity's `init()` takes no relationship arguments; relationships are wired via the convenience init or by direct property assignment AFTER insertion.

## Out of Scope (handled by later plans)

- `SchemaV1: VersionedSchema` enum that lists all 12 types → plan `01-PLAN-01-02`.
- `FitbodSchemaMigrationPlan: SchemaMigrationPlan` → plan `01-PLAN-01-02`.
- `ModelContainer` wiring in `fitbodApp.swift` → plan `01-PLAN-01-02`.
- `PreviewModelContainer.make()` → plan `01-PLAN-01-03`.
- Unit tests against these entities → plan `01-PLAN-01-03`.
- Populating `primaryMuscleSlugsJoined` from real data → plan `01-PLAN-02-02` (importer) + plan `01-PLAN-03-04` (custom exercise editor's `materialize` method).
- Hand-curating stimulus weights for compound lifts → deferred to Phase 5 per CONTEXT.md.

## Commit Message Template

```
feat(01): add 12 SwiftData @Model entities + 11 *Raw String enums

- Exercise (with denormalized primaryMuscleSlugsJoined for muscle-filter
  predicate per RESEARCH Pitfall 3), MuscleGroup, ExerciseMuscleStimulus
- Routine + RoutineExercise (templates; Phase 2 will use)
- Session + SessionExercise + SetEntry (instances; Phase 2 will use; snapshot
  fields locked Day 1 per PITFALLS #1)
- Block + BlockPhase (Phase 4 schema parity)
- UserSettings (singleton; unitsRaw drives SET-01 toggle) + MuscleVolumeTarget
- 11 enums under Enums/: Intent, ProgressionKind, Equipment (9 cases — LIB-06
  + kettlebell + weightedBodyweight per RESEARCH Open Q #4), Mechanic, Force,
  Level, Pattern (nullable v1 per Open Q #5), MuscleRegion, WeightUnit,
  BlockPhaseKind, SetType
- every property optional or default-valued (FOUND-02)
- every enum *Raw: String with computed accessor (FOUND-03, PITFALLS #9)
- #Index on Exercise.{canonicalName, equipmentRaw, mechanicRaw, isCustom,
  primaryMuscleSlugsJoined} + Session.{startedAt, sourceRoutineID} +
  SessionExercise.intentRaw (FOUND-04, PITFALLS #7)
- cascade rules per CONTEXT § Area 4 (Exercise→Stimulus cascade;
  Exercise→SessionExercise nullify so LIB-05 history-preserving deletes
  work; Session→SessionExercise→SetEntry cascade chain)

Schema wrapper (SchemaV1: VersionedSchema) lands in next plan.
```
