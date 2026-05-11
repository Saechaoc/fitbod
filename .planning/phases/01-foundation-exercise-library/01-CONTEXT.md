# Phase 1: Foundation & Exercise Library - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning
**Mode:** Auto-generated via `/gsd-autonomous` smart-discuss (recommended options auto-selected; rationale per area below)

<canonical_refs>
## Canonical References

These docs are MANDATORY reads for researcher and planner:
- `.planning/PROJECT.md` — Project context, constraints, key decisions
- `.planning/REQUIREMENTS.md` — All 80 v1 requirements with traceability (LIB-01..06, FOUND-01..07, SET-01 mapped to this phase)
- `.planning/research/SUMMARY.md` — Executive summary; top-leverage architectural decisions
- `.planning/research/STACK.md` — Stack choices, `yuhonas/free-exercise-db` schema notes, SwiftData modeling guidance
- `.planning/research/ARCHITECTURE.md` — 12 SwiftData @Model entities with relationships, cascade rules, indexes; 22-step build order
- `.planning/research/PITFALLS.md` — 12 critical pitfalls; #1 (template/instance), #2 (versioned schema), #5 (stimulus weighting), #6 (main-thread bulk ops), #7 (filter indexes) all apply directly to this phase
- `.planning/ROADMAP.md` — Phase 1 success criteria (6 must-be-true conditions)
</canonical_refs>

<domain>
## Phase Boundary

This phase delivers: a versioned SwiftData schema, the full domain entity set (`Exercise`, `MuscleGroup`, `ExerciseMuscleStimulus`, `Routine`, `RoutineExercise`, `Session`, `SessionExercise`, `SetEntry`, `Block`, `BlockPhase`, `UserSettings`, `MuscleVolumeTarget`), a `ModelContainer` wired into the app, a one-time exercise library seed pipeline running inside a `@ModelActor`, and the user-facing exercise library UI (browse, multi-facet filter, type-ahead search, custom exercise creation).

After this phase the app does not log workouts yet — routines and sessions are entities in the schema but not exercised by UI. The keystone of every later phase (exercises with stimulus-weighted muscle mappings) is in place.

In scope: FOUND-01..07, LIB-01..06, SET-01.
Out of scope (handled by later phases): routine builder UI, session logger, prescription engine, progression strategies, blocks, fatigue model, progress views, export.
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Exercise Library Seeding

- **Source dataset**: Bundle `yuhonas/free-exercise-db` JSON in the app target. License (Unlicense / public domain) requires no attribution. Filter import at seed time to `category ∈ {strength, powerlifting, olympic weightlifting, strongman}` — drop cardio/stretching since those are out of scope for v1.
- **Seed timing**: Run on first launch; idempotent on subsequent launches.
- **Idempotency mechanism**: `UserDefaults` key `exercise_seed_version` storing the seed-data version stamp; if the bundled JSON's version matches the stored stamp, skip seeding entirely.
- **Concurrency**: Seed runs inside a `@ModelActor` (per PITFALLS.md #6 — never block the main thread for 800+ rows of insert). Target <2s on cold launch (Phase 1 success criterion 1).
- **Image assets**: v1 ships *without* bundled exercise images to keep the app binary small. Images can be wired in a later phase (`LIB-04` notes image as optional). The seed records the relative image path string from the dataset for future use, but does not bundle the binaries.
- **Stimulus weighting seed**: For each exercise, create one `ExerciseMuscleStimulus` row per primary muscle with `weight = 1.0` and one per secondary muscle with `weight = 0.5`. Hand-curation of the top ~50 lifts (compound exercises that pull on multiple muscle groups asymmetrically) is **deferred to Phase 5** — but the schema supports it from day 1.

### Area 2 — Filter and Search UX

- **Filter UI**: Sticky chip-row at the top of the library screen (muscle, equipment, mechanic, pattern); selected chips filter the list reactively. Multi-select within a facet, AND across facets.
- **Search**: A native SwiftUI `.searchable` modifier on the list; type-ahead matches against `Exercise.canonicalName` (case- and diacritic-insensitive). Indexed via `#Index(\.canonicalName)`.
- **Filter persistence**: Per-session only — filters reset when the user leaves the library tab. (Persisting filters across launches is deferred — could surface as a v2 idea.)
- **Default sort**: Alphabetical by canonical name. Sort options menu (alphabetical / muscle / equipment) deferred to v1.x.
- **Performance bar**: Sub-100ms response on filter chip taps and keystrokes, validated against the full 800-exercise set (Phase 1 success criterion 2 & 3).

### Area 3 — Custom Exercise Creation

- **Required fields**: name, primary muscle (at least one, with stimulus weight ≥ 0.5), equipment kind, mechanic (compound/isolation). Image is optional (camera + photo library both supported via `PhotosUI`).
- **Stimulus weight UI**: For each selected muscle, a slider 0.0–1.0 with default 1.0 for primary, 0.5 for secondary. Tooltip explains "stimulus weight" as "how much this exercise contributes to weekly volume for this muscle."
- **Validation**: Save button disabled until all required fields are populated; the validation rule lives in a `CustomExerciseDraft` value type used by the form (testable without `ModelContainer`).
- **Edit/delete on user-created**: editable + deletable freely. Built-in exercises are read-only; a "Copy as custom" action creates an editable user-owned duplicate. Deleting a custom exercise with existing history shows a confirmation explaining session history will be preserved (via Nullify cascade on the `SessionExercise.exercise` relationship).
- **`isCustom: Bool` flag**: persisted; indexed.

### Area 4 — Schema, Migrations, and ModelContainer

- **`VersionedSchema`**: All 12 `@Model` types wrapped in `enum SchemaV1: VersionedSchema { ... static var models: [any PersistentModel.Type] = [...] }`. A `class FitbodSchemaMigrationPlan: SchemaMigrationPlan` is created with an empty `static var stages: [MigrationStage] = []`. This is the load-bearing pitfall fix (PITFALLS.md #2 — every later schema change pays compound interest if this is skipped).
- **`ModelContainer` config**: Single shared container in `fitbodApp.swift`, configured with the versioned schema, on-disk store, **not** `isStoredInMemoryOnly: false`. SwiftUI views consume via `.modelContainer(_)` injection.
- **Preview / test container**: Helper factory `PreviewModelContainer.make()` produces an in-memory `ModelContainer` seeded with a deterministic mini-fixture (a handful of exercises across the muscle taxonomy) — used by SwiftUI `#Preview` blocks and unit tests alike.
- **Cascade rules** (locked from ARCHITECTURE.md):
  - `Session` → `SessionExercise` → `SetEntry`: cascade delete
  - `Routine` → `RoutineExercise`: cascade delete
  - `Exercise` → `SessionExercise`: **nullify** (deleting a library entry must not delete history)
  - `Exercise` → `ExerciseMuscleStimulus`: cascade delete (stimulus rows are owned)
  - All relationships declare explicit inverses.
- **Enum persistence**: every enum stored as `*Raw: String` with a computed enum accessor (PITFALLS.md #9). Enums affected this phase: `MuscleGroup.regionRaw`, `Exercise.kindRaw / mechanicRaw / equipmentRaw / patternRaw`, `WeightUnit` (lb/kg).
- **All properties optional or default-valued** (FOUND-02 — iCloud-shape insurance). The model definitions must follow this rule even though iCloud is not wired in v1.
- **Indexes** (iOS 18 `#Index`):
  - `Exercise`: `\.canonicalName`, `\.equipmentRaw`, `\.mechanicRaw`, `\.isCustom`
  - `Session`: `\.startedAt`, `\.sourceRoutineID`
  - `SessionExercise`: `\.intentRaw`
  - Plus any others surfaced by the planner during research.
- **iOS deployment target**: confirm and set to `18.0` in the Xcode project (the existing template likely set the project's current default; explicitly setting 18.0 unlocks `#Index`).
- **`Item.swift` (stock template model)**: delete after `SchemaV1` is wired, before any production schema work. Don't leave it as a stray model — it will pollute the schema and migrations forever (PITFALLS.md #2 corollary).

### Claude's Discretion

- Exact Xcode project layout / folder structure (group hierarchy within the project) — planner picks something readable; suggest a feature-organized layout (`Models/`, `ExerciseLibrary/`, `Persistence/`, `Settings/`).
- Test target stack details — Swift Testing for unit, XCTest only for UI (per STACK.md).
- Exact `MuscleGroup` taxonomy — start from `free-exercise-db`'s 17-muscle list, but normalize names (e.g., dataset's "lats" vs "latissimus dorsi" → canonical form). Decisions on aggregate groups ("chest" = upper + lower pec?) are at planner discretion; document the chosen taxonomy in code.
- Asset catalog content (icons, accent color) — at planner discretion; defer detailed UI/brand decisions to UI-SPEC for this phase.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

Practically none — the codebase is the stock Xcode SwiftUI + SwiftData template created on 2026-05-10:
- `fitbod/fitbodApp.swift` — `@main` App with `sharedModelContainer` over the stock `Item` schema
- `fitbod/ContentView.swift` — stock SwiftData template (NavigationSplitView with Item list)
- `fitbod/Item.swift` — placeholder `@Model` (must be deleted in this phase)

### Established Patterns

None yet — this phase establishes them. The patterns to lock here include:
- `@MainActor` for everything except the seed (`@ModelActor`) — per ARCHITECTURE.md
- MV-VM-lite: bind views to `@Model` directly via `@Query` / `@Bindable`; no parallel ViewModel layer mirroring the schema (PITFALLS.md #8)
- Strategy/service pattern for math (anticipates Phase 3 `ProgressionStrategy` and Phase 5 `FatigueModel`) — for this phase, only the seed-import and stimulus-default services exist as standalone testable types

### Integration Points

- `fitbodApp.swift` is the root entry — `ModelContainer` injection happens here
- `ContentView.swift` is currently the stock view — Phase 1 replaces it with a `RootView` that hosts a `TabView` (library tab is the first user-visible surface; other tabs are placeholders that later phases fill in)
- iOS deployment target is set in the `fitbod.xcodeproj` project settings — Phase 1 confirms / raises to 18.0

</code_context>

<specifics>
## Specific Ideas

- The "no-modal exercise picker" rule from ROUTINE-01 (Phase 2) implies the library list must be reusable as an embedded subview (e.g., inside a routine-builder sheet) — the planner should design the library `ExerciseListView` to accept a selection-handler closure so Phase 2 can reuse it without forking. This is a Phase-2 concern but the Phase-1 API shape locks it in.
- Custom exercises should always be visually distinguishable from bundled ones in the list (a small "custom" tag/chip) so the user always knows whether they're editing a built-in entity. Built-in entries are immutable.
- Filter chips should reflect actual data (e.g., the "equipment" facet's chip set is derived from `DISTINCT equipment` across exercises after import, not a hardcoded list) — prevents drift between the dataset and the UI.
- The seed must log on completion (`os_log` debug level) so first-launch performance is observable during development.
- The 17-muscle taxonomy comes from `free-exercise-db`. Plan to add canonical-name aliases (e.g., dataset's "middle back" → "rhomboids/mid traps") in a small handwritten alias map. The MEV/MAV/MRV thresholds (Phase 5) will key off the canonical names.

</specifics>

<deferred>
## Deferred Ideas

- **Bundled exercise images / GIFs** — bundle binary assets in a Phase 1.x polish pass (or later) once core flows are validated. Image path strings are persisted from day 1 so a future seed can hydrate them.
- **Hand-curated stimulus-weighting table for the top 50 compound lifts** — deferred to Phase 5 (Fatigue Model) where the math actually depends on it; defaults (1.0 primary / 0.5 secondary) carry through Phases 2–4 fine.
- **Filter state persistence across launches** — single-session reset is the v1 behavior; promote to a v1.x or v2 feature if it proves friction-y.
- **Sort options menu** — alphabetical only in v1; defer "sort by muscle / equipment / recently used" until usage tells us we need them.
- **Aggregate muscle groups** (e.g., "chest" = upper + lower pec) — locked taxonomy decision deferred to planning, not a user-facing question.
- **iCloud sync** (FOUND-02 ensures shape-readiness but no sync yet) — explicit v2 item per REQUIREMENTS.md.

</deferred>
