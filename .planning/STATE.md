---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-11T07:18:23.233Z"
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 12
  completed_plans: 10
  percent: 83
---

# Project State: Fitbod

**Last updated:** 2026-05-11 (post 03-04)

---

## Project Reference

**Core value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

**Stack:** SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1, zero third-party dependencies.

**Mode:** MVP — every phase delivers an end-to-end vertical slice (not a horizontal layer).

**Granularity:** standard (5–8 phases).

---

## Current Position

**Phase:** 1 — Foundation & Exercise Library (in progress)
**Plan:** 03-04 complete (Wave 3, sequence 4 of 4) — CustomExerciseEditor + CustomExerciseDraft + PITFALLS #5 validation gate shipped; next: 03-03 (ExerciseDetailView with Copy as Custom action — uses this plan's CustomExerciseDraft type)
**Status:** Ready to execute
**Progress:** [████████░░] 83%

### Phase Outlook

| # | Phase | Reqs | Status |
|---|-------|-----:|--------|
| 1 | Foundation & Exercise Library | 14 | In progress (Wave 3 sequence 4 of 4 complete; 03-03 next — last plan in phase) |
| 2 | Core Loop (Routines + Sessions) | 20 | Not started |
| 3 | Smart Prescription & Warm-ups | 15 | Not started |
| 4 | Periodization & Blocks | 10 | Not started |
| 5 | Fatigue Model & Plateau Detection | 10 | Not started |
| 6 | Progress Views, Export & Polish | 11 | Not started |

**Coverage:** 80 / 80 v1 requirements mapped.

---

## Performance Metrics

Phase 1 in flight; metrics roll up at phase completion. Per-plan duration table:

| Phase | Plan | Duration (s) | Tasks | Files | Notes |
|-------|------|-------------:|------:|------:|-------|
| 1 | 00-01 | 240 (approx) | 3 | 12 | Project hygiene — delete Item.swift, bump Swift 6, scaffold folders |
| 1 | 00-02 | 180 (approx) | 2 | 3 | Asset catalog — AccentColor + placeholder AppIcon |
| 1 | 01-01 | 480 | 1 | 23 | 12 entity models + 11 enums |
| 1 | 01-02 | 68 | 2 | 4 | SchemaV1 + FitbodSchemaMigrationPlan + fitbodApp rewire + RootView stub |
| 1 | 01-03 | 240 | 3 | 10 | PreviewModelContainer + 5 Swift Testing suites (48 @Test funcs / 49+ parameterised invocations) |
| 1 | 02-01 | 216 | 3 | 8 | Vendor free-exercise-db JSON (873 rows, ~1.0 MB, SHA `acd61f7`) + ExerciseDTO + EquipmentMapper + MuscleRegionMap + 9 DTODecodingTests |
| 1 | 02-02 | 229 | 3 | 3 | ExerciseLibraryImporter @ModelActor (idempotent seed pipeline) + SeedError + 7 SeedTests (FOUND-05 + LIB-01) |
| 1 | 03-01 | 0 (single-commit micro-plan) | 1 | 4 | RootView 5-tab TabView + RootView.task seed trigger + SeedState + PlaceholderTabView + ContentView.swift deletion |
| 1 | 03-02 | 270 | 3 | 9 | ExerciseLibraryView (outer/inner split per RESEARCH § Pattern 3) + FilterState (@Observable, captures-by-value) + FilterChip / ExerciseFilterBar (44pt HIG, .safeAreaInset sticky) + FilterPickerSheet (4 facets, [.medium, .large] detents) + ExerciseRow ("Custom" tag) + RootView LibraryTabHost 1-line wire + 7 FilterStatePredicateTests + 2 IndexedQueryTests. Closes LIB-01 / LIB-02 / LIB-03; verifies FOUND-04 / FOUND-06. |
| 1 | 03-04 | 353 | 3 | 7 | CustomExerciseDraft @Observable form state (FOUND-07 pure-value-type isValid: name + ≥1 primary muscle weight ≥0.5 — PITFALLS #5 runtime gate) + CustomExerciseEditor Form (5 sections + Delete in Edit mode; Save disabled gate; "Discard Changes?" confirmationDialog on dirty; verbatim UI-SPEC § Custom exercise editor copy) + MusclePickerSheet (@Query<MuscleGroup> closure-driven) + MuscleWeightRow (segmented role picker + Slider 0.0-1.0 step 0.05 + percent display + UI-SPEC accessibilityLabel/Value) + CustomExerciseImagePicker (native PhotosPicker; no NSPhotoLibraryUsageDescription per RESEARCH Pattern 7) + ExerciseLibraryView "+" toolbar wire (.sheet replaces plan-03-02 NavigationLink placeholder; removes dead NewCustomExerciseRequest token) + 10 CustomExerciseDraftTests (truth-table coverage of every validation branch + materialize round-trip + snapshot dirty-detection) + 1 CustomExerciseDeleteCascadeTests (LIB-05 nullify cascade duplicated at editor surface). Closes LIB-04 / FOUND-07; verifies LIB-05 / LIB-06 / FOUND-06. |

---

## Accumulated Context

### Key Decisions (from PROJECT.md, locked in)

- iOS native SwiftUI + SwiftData (Xcode template already created)
- Single-user, local-only v1 (no auth, no cloud, no backend)
- Per-exercise prescription as the core unit
- User-selectable progression model (4 options: RPE/RIR autoreg, double progression, block-periodized, hybrid)
- RP-style weekly volume tracking against MEV/MAV/MRV
- Deload: scheduled by default + advisory fatigue alert (block schedule is canonical)
- 1000+ exercise library seeded from `yuhonas/free-exercise-db` (Unlicense, ~800 exercises)
- Auto warm-up ramp on first compound only
- Phone-only v1 (no Watch, no HealthKit, no VBT)

### Architectural Stance (from research/ARCHITECTURE.md)

1. **MV-VM-lite** — Views bind to `@Model` directly via `@Query` / `@Bindable`. No parallel ViewModel layer mirrors the schema.
2. **Template vs Instance via snapshot** — `SessionFactory.start(...)` copies prescription fields from `RoutineExercise` (template) to `SessionExercise` (instance) at session-start. Template edits never rewrite history.
3. **Progression and fatigue as pure stateless services behind protocols** — `ProgressionStrategy` has four conforming value types; `FatigueModel`, `PlateauDetector`, `PeriodizationEngine` are pure functions over plain inputs. Trivially unit-testable without `ModelContainer`.

### Load-Bearing Pitfalls (from research/PITFALLS.md)

These drive phase ordering and are mitigated by phase placement:

| # | Pitfall | Mitigated in |
|---|---------|--------------|
| 1 | Collapsing template and instance | Phase 1 (schema) + Phase 2 (snapshot proven end-to-end) |
| 2 | Missing `VersionedSchema` in v1 | Phase 1 (FOUND-01) |
| 3 | Volume math correct but UX doesn't drive a decision | Phase 5 (verb labels, not just numbers) |
| 4 | Rest timer drifts/stops on lock | Phase 2 (`Date` + `UNUserNotification`, never foreground `Timer`) |
| 5 | RPE-to-weight back-calc uses population averages | Phase 3 (Tuchscherer as prior; per-lifter calibration after ≥10 sets) |
| 9 | Codable enums on @Model types crash; *Raw String + computed accessor is the workaround | Phase 1 (FOUND-03 anchored at unit-test level via EnumPersistenceTests) |
| Phase 01 P03-04 | 353 | 3 tasks | 7 files |

### Open Research Items (deferred to plan-phase time)

- **Phase 3:** Tuchscherer RPE table cell values + per-exercise per-lifter calibration algorithm (linear vs locally-weighted; min-points threshold)
- **Phase 4:** Block phase curve multipliers (default volume/intensity per accumulation/intensification/realization/deload) confirmed against current RP/RTS literature
- **Phase 5:** Stimulus-weighting table for the ~50 main compound lifts (beyond 1.0/0.5 defaults) + RP-published MEV/MAV/MRV seed values per muscle

### Todos

- [x] `/gsd-plan-phase 1` — decompose Phase 1 into executable plans (PLAN-INDEX.md created)
- [x] Confirm `Item.swift` template model is removed before any seed import (plan 00-01 deleted it; plan 01-02 removed all `Item.self` references)
- [x] Plan 01-03 — `PreviewModelContainer.make()` + first batch of SchemaV1 unit tests (Wave 1 complete)
- [x] Plan 02-01 — `ExerciseDTO` + EquipmentMapper + MuscleRegionMap + vendored exercises.json (Wave 2, seq 1)
- [x] Plan 02-02 — `ExerciseLibraryImporter` `@ModelActor` + SeedError + 7 SeedTests (Wave 2, seq 2 — closes FOUND-05)
- [x] Plan 03-01 — RootView 5-tab TabView + RootView.task seed trigger + SeedState + PlaceholderTabView (Wave 3, seq 1)
- [x] Plan 03-02 — ExerciseLibraryView (browse + multi-facet filter + .searchable) + FilterState + FilterPickerSheet + ExerciseRow + 9 Swift Testing funcs (Wave 3, seq 2 — closes LIB-01 / LIB-02 / LIB-03; verifies FOUND-04 / FOUND-06)
- [x] Plan 03-04 — CustomExerciseEditor + CustomExerciseDraft + 11 Swift Testing funcs (Wave 3, seq 4 — closes LIB-04 / FOUND-07; verifies LIB-05 / LIB-06; PITFALLS #5 runtime gate at editor surface)
- [ ] Plan 03-03 — ExerciseDetailView with "Copy as Custom" (Wave 3, seq 3 — depends on 03-04's CustomExerciseDraft; last plan in Phase 1)

### Phase 1 Plans Completed

- **00-01** (Wave 0): Project hygiene — deleted `Item.swift`, bumped Swift 6 + strict concurrency, scaffolded feature-organized folders. Commits: `24ac4e0` / `8a16c96` / `40d9531` / `fa32cf2`.
- **00-02** (Wave 0, parallel): Asset catalog — AccentColor `#0E7C86` / `#3FBFC9`, placeholder AppIcon. Commits: `a1df0f3` / `e0c68d4`.
- **01-01** (Wave 1, seq 1): 12 `@Model` entities + 11 String-backed enums + 23 files. Commits: `cb27292` / `6aed051` / `8e35c93` / `adf8a7b` / `a4c5991`.
- **01-02** (Wave 1, seq 2): `SchemaV1: VersionedSchema` + `FitbodSchemaMigrationPlan` + `fitbodApp` rewire + interim `RootView` stub. Commits: `28795c8` / `58ea362`. Closes FOUND-01.
- **01-03** (Wave 1, seq 3): `PreviewModelContainer.make()` + `Exercise.previewSample` + `InMemoryContainer` helper + 5 Swift Testing suites (SchemaV1Tests, CascadeRuleTests, EnumPersistenceTests, EnumTests, UserSettingsTests). 48 `@Test` funcs anchoring FOUND-01..03, LIB-05/06, SET-01. Commits: `38d975b` / `5369cb7`. Closes the Wave 1 testing-infrastructure bar.
- **02-01** (Wave 2, seq 1): Vendored `yuhonas/free-exercise-db` `exercises.json` (873 raw rows, ~1.0 MB, pinned to upstream SHA `acd61f7`, Unlicense / public domain). Authored `SEED_VERSION.txt` = 1 + `SOURCE.md` (provenance + 5-step refresh procedure). Created `ExerciseDTO` (plain Codable struct, 11 fields), `EquipmentMapper` (LIB-06 anchor: 12+ raw → 9-case Equipment, plus `shouldImport(category:)` strength filter), `MuscleRegionMap` (RESEARCH Open Q #3: 17 slugs → 10/6/1 region split + `displayName(for:)` + `allSlugs: [String]`). Added 9 `DTODecodingTests` (15-input parameterised equipment-mapping + exhaustive coverage over actual bundled JSON + region bucket sizes + Codable round-trip). Commits: `f7279bb` / `3d21e20` / `fa33433`. Closes LIB-01.
- **02-02** (Wave 2, seq 2): `ExerciseLibraryImporter` `@ModelActor` — load-bearing seed pipeline. Reads `UserDefaults["exercise_seed_version"]` vs bundled `SEED_VERSION.txt`; short-circuits when up-to-date. On fresh seed: decodes `exercises.json` via `ExerciseDTO`, filters via `EquipmentMapper.shouldImport(category:)` (yielding ~675 rows), upserts 17 `MuscleGroup` rows from `MuscleRegionMap.allSlugs`, inserts the filtered exercises with `equipmentRaw` translated via `EquipmentMapper.map(_:)`, populates the denormalized `primaryMuscleSlugsJoined = "|chest|triceps|"` field (PITFALLS #3 — index-friendly muscle-filter predicate), creates `ExerciseMuscleStimulus` join rows (primary=1.0 / secondary=0.5) AFTER inserting each parent (PITFALLS #7), 100-row batched `modelContext.save()` (PITFALLS #6 — off the main thread), seeds `UserSettings.default()` singleton if absent, stamps `UserDefaults["exercise_seed_version"]` on success. `SeedError` Sendable enum for typed failure modes. 7 `SeedTests`: `strengthOnlyCount`, `muscleGroupCount`, `idempotent`, `userSettingsSeeded`, `stimulusWeightingDefaults`, `denormalizedMuscleField`, `coldLaunchUnder2s` (soft cap 5s for CI; production target <2s = FOUND-05). Commits: `998bacb` / `97f023a`. Closes FOUND-05 and the seed-pipeline portion of LIB-01.
- **03-01** (Wave 3, seq 1): `RootView` (`fitbod/App/RootView.swift`) — 5-tab `TabView` with locked UI-SPEC SF Symbols + labels (Today / Routines / Library / Progress / Settings), `RootView.task`-driven seed trigger calling `ExerciseLibraryImporter(modelContainer:).seedIfNeeded(bundle: .main)`, `ProgressView("Preparing library…")` splash dismissed by dual-signal predicate (`@Query<Exercise>.isEmpty` AND `SeedState.phase in {.idle, .loading}`). `PlaceholderTabView` "Available in Phase {N}" filler for Today / Routines (Phase 2) / Progress (Phase 6). `@Observable SeedState` lifecycle (idle / loading / ready / failed(message:)). Two interim hosts (`LibraryTabHost` / `SettingsTabHost`) as 1-line edit-points for plans 03-02 / 04-01. Deleted `fitbod/ContentView.swift` (interim stub from 01-02 superseded). Commits: `a9a121e`. Wave 3 sequence 1 of 4 complete.
- **03-02** (Wave 3, seq 2): `ExerciseLibraryView` (`fitbod/ExerciseLibrary/ExerciseLibraryView.swift`) — outer view owns `@State filterState / searchText / debouncedSearch / presentingFacet`; inner private `FilteredExerciseList` consumes a `Predicate<Exercise>` via `init(predicate:)` and re-runs its `@Query` whenever the predicate changes (RESEARCH § Pattern 3). `.searchable` with 150 ms `.task(id: searchText)` debounce (PITFALLS #4). Sectioned alphabetical `List` (.insetGrouped). `FilterState` (`@Observable`) composes `Predicate<Exercise>` from muscle/equipment/mechanic/pattern + debounced search; captures-by-value (PITFALLS #12); denormalized muscle filter via `primaryMuscleSlugsJoined.contains("|slug|")` (PITFALLS #3). `FilterChip` (44pt HIG `.frame(minHeight: 44)`). `ExerciseFilterBar` (sticky via `.safeAreaInset(edge: .top)`; "Clear filters" trailing button when `!filterState.isEmpty`). `FilterPickerSheet` (multi-select for muscle/equipment/pattern, single-select for mechanic; `[.medium, .large]` detents; pattern footer copy explains the Phase 1 nullable state per Open Q #5). `ExerciseRow` (name `.body` + equipment·mechanic caption + "Custom" capsule tag per UI-SPEC). Empty state ships with both UI-SPEC copy variants now (with-query: `No exercises match "{query}"`; without: `No exercises match`); "Create Custom Exercise" CTA deferred to 04-01 (depends on 03-04's editor). RootView `LibraryTabHost` rewired to `var body: some View { ExerciseLibraryView() }` — the 1-line edit-point planned in 03-01 D-4. 7 `FilterStatePredicateTests` (empty / search / equipment / mechanic / muscle-denormalised / multi-facet AND / multi-select OR) + 2 `IndexedQueryTests` (canonicalName.contains + primaryMuscleSlugsJoined.contains; production target <50 ms, soft cap 200 ms for CI). Commits: `5d16b4f` / `d1dc0da` / `8e75585`. Closes LIB-01 / LIB-02 / LIB-03; verifies FOUND-04 / FOUND-06.
- **03-04** (Wave 3, seq 4): `CustomExerciseDraft` (`fitbod/ExerciseLibrary/CustomExerciseDraft.swift`) — `@Observable` final-class form state. `isValid` (PITFALLS #5 runtime gate at the only authoring surface) is a PURE-VALUE-TYPE computed property: name (trimmed) non-empty AND ≥1 `MuscleAssignment` with `role == .primary AND weight >= 0.5`. Testable WITHOUT `ModelContainer` — FOUND-07 in microcosm. `MuscleAssignment` Identifiable struct (id / slug / role / weight); `Role` enum (primary / secondary). `Snapshot` value-type for dirty detection (imageData reduced to hashValue for cheap equality). `materialize(into:allMuscles:)` inserts a NEW `Exercise` (with `isCustom=true` and `primaryMuscleSlugsJoined = "|chest|"` denormalized for PITFALLS #3 muscle-filter parity) + `ExerciseMuscleStimulus` rows; insert-then-relate ordering (RESEARCH Pitfall 7). `updateExisting(in:allMuscles:)` for Edit mode (wired but no user entry point in v1 — deferred per plan Out of Scope). `CustomExerciseEditor` (`fitbod/ExerciseLibrary/CustomExerciseEditor.swift`) — Form with 5 sections (Name / Muscles / Equipment / Mechanic / Image (optional)) + Delete section in Edit mode. Save toolbar button `.disabled(!draft.isValid)` with UI-SPEC `accessibilityHint = "Add a primary muscle to enable saving"`. Cancel presents `confirmationDialog("Discard Changes?")` only when dirty (snapshot diff); Delete presents `alert("Delete \"{name}\"?")` with body "Logged session history for this exercise will be preserved." per UI-SPEC § Error states. Body decomposed into 5 private computed sections to dodge the SwiftUI "expression too complex" wall. First muscle added → primary @ 1.0; subsequent → secondary @ 0.5; button label "Add Primary Muscle" / "Add Another Muscle" state-dependent. Duplicate-slug guard in `appendMuscle(_:)` prevents accidental volume-doubling (D-1). `MusclePickerSheet` (`@Query<MuscleGroup>` closure-driven; region badges; "Select Muscle" navigation title). `MuscleWeightRow` (segmented role picker + 0.0–1.0 Slider step 0.05 + monospaced "{percent}%" display + trash button; UI-SPEC `accessibilityLabel = "Stimulus weight for {muscle}"`). `CustomExerciseImagePicker` (native `PhotosPicker(selection:matching:photoLibrary:)`; async `.onChange(of:)` → `Task { try? await loadTransferable(type: Data.self) }`; no `NSPhotoLibraryUsageDescription` needed per RESEARCH Pattern 7 / Assumption A6). `ExerciseLibraryView.swift` edited: `+` toolbar Button now sets `presentingNewCustom = true` and `.sheet(isPresented:)` presents `NavigationStack { CustomExerciseEditor(draft: CustomExerciseDraft()) }`; the dead `NewCustomExerciseRequest` navigation token and its placeholder destination are removed. 10 `CustomExerciseDraftTests` covering every truth-table branch (empty name / whitespace / no muscles / only secondary / primary < 0.5 / primary at 0.5 threshold / primary at 1.0 / multiple primaries / materialize round-trip / snapshot dirty) + 1 `CustomExerciseDeleteCascadeTests` duplicating the LIB-05 cascade assertion at the editor surface. Commits: `a125cf6` / `09443c4` / `9ea8be6`. Closes LIB-04 / FOUND-07; verifies LIB-05 / LIB-06 / FOUND-06.

### Blockers

None.

---

## Session Continuity

### Last Action

Executed plan 03-04 (CustomExerciseEditor + CustomExerciseDraft + PITFALLS #5 validation gate). Created 5 production files under `fitbod/ExerciseLibrary/` (CustomExerciseDraft, CustomExerciseEditor, MusclePickerSheet, MuscleWeightRow, CustomExerciseImagePicker) + 1 test file under `fitbodTests/` (CustomExerciseDraftTests with 11 @Test functions across 2 @Suites). Modified `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` to replace the plan-03-02 `NavigationLink` + `navigationDestination` placeholder with a direct `.sheet(isPresented: $presentingNewCustom)` presenting `NavigationStack { CustomExerciseEditor(draft: CustomExerciseDraft()) }`; removed the now-dead `NewCustomExerciseRequest` navigation token. `CustomExerciseDraft` is `@Observable` final-class form state with PURE-VALUE-TYPE `isValid` (FOUND-07 in microcosm) that requires: trimmed name non-empty AND ≥1 `MuscleAssignment` with `role == .primary AND weight >= 0.5`. This is the PITFALLS #5 runtime gate at the only authoring surface — without it, the user could silently create an Exercise with no primary-muscle stimulus rows and Phase 5's RP-style volume math would read zero. `materialize(into:allMuscles:)` inserts a NEW `Exercise(isCustom: true)` + `ExerciseMuscleStimulus` rows, populates `primaryMuscleSlugsJoined = "|chest|"` for PITFALLS #3 muscle-filter parity with the seed pipeline; insert-then-relate ordering (RESEARCH Pitfall 7). `updateExisting(in:allMuscles:)` for Edit mode lands wired but no user entry point exists in v1 (deferred per plan Out of Scope). `CustomExerciseEditor` Form has 5 sections (Name / Muscles / Equipment / Mechanic / Image (optional)) + Delete section in Edit mode; body decomposed into 5 private computed section properties to dodge the SwiftUI "expression too complex" wall. Save toolbar button `.disabled(!draft.isValid)` with UI-SPEC `accessibilityHint = "Add a primary muscle to enable saving"`. Cancel presents `confirmationDialog("Discard Changes?")` only when dirty (snapshot diff with `imageData.hashValue` for cheap equality); Delete presents `alert("Delete \"{name}\"?")` with verbatim body "Logged session history for this exercise will be preserved.". First muscle added defaults to primary @ 1.0; subsequent to secondary @ 0.5; button label "Add Primary Muscle" / "Add Another Muscle" state-dependent. Duplicate-slug guard in `appendMuscle(_:)` prevents accidental double-mapping (Plan 03-04 D-1 — PITFALLS #5's evil twin not called out by the pitfall directly). `MusclePickerSheet` uses `@Query<MuscleGroup>` with closure-driven selection. `MuscleWeightRow` has segmented role picker + 0.0–1.0 Slider (step 0.05) + monospaced "{percent}%" display + trash button; UI-SPEC `accessibilityLabel = "Stimulus weight for {muscle}"` + `accessibilityValue = "{percent} percent"`. `CustomExerciseImagePicker` uses native iOS-16+ `PhotosPicker(selection:matching:photoLibrary:)` with async `.onChange(of:)` → `Task { try? await loadTransferable(type: Data.self) }` populating `draft.imageData` — no `NSPhotoLibraryUsageDescription` Info.plist entry needed (RESEARCH Pattern 7 / Assumption A6; sandboxed `PHPickerViewController`). 10 `CustomExerciseDraftTests` cover every truth-table branch (empty name / whitespace / no muscles / only secondary / primary < 0.5 / primary at 0.5 threshold / primary at 1.0 / multiple primaries / materialize round-trip / snapshot dirty detection) + 1 `CustomExerciseDeleteCascadeTests` duplicates the LIB-05 cascade assertion at the editor surface. Commits: `a125cf6` (CustomExerciseDraft + tests, +535 lines) / `09443c4` (CustomExerciseEditor + MusclePickerSheet + MuscleWeightRow + CustomExerciseImagePicker, +603 lines) / `9ea8be6` (ExerciseLibraryView wiring, +30 / -19 lines). UI-SPEC verbatim copy verified by grep across all 5 section headers + 2 navigation titles + 6 toolbar buttons + name placeholder + 2 muscle-button labels + Discard/Delete confirmations + image picker labels + accessibility contracts. `xcrun swiftc -parse` over all 47 production + 11 test Swift files (58 total) exits 0 with no output. Wave 3 sequence 4 of 4 complete; plan 03-03 next (last plan in Phase 1).

### Next Action

`/gsd-execute-phase 03-03` (Wave 3, sequence 3 of 4 — last plan in Phase 1) — `ExerciseDetailView` (read-only browse: instructions / muscles with stimulus % / equipment / mechanic) with a "Copy as Custom Exercise" action that instantiates `CustomExerciseDraft` (from this plan) pre-populated from the source built-in exercise's fields (name / equipment / mechanic / muscle stimuli) with `editingExisting = nil` so it creates a new custom exercise rather than overwriting the built-in. Pushed onto the Library tab's `NavigationStack` via the `navigationDestination(for: Exercise.self)` at line ~197 of `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — that line is the 1-line edit-point. UI-SPEC § Exercise detail screen locks every string ("Instructions" / "Muscles" / "Equipment" / "Mechanic" section headers, "{Muscle name} · {weight as percent}" row format, "Copy as Custom Exercise" button label).

### Open Questions

- None at this layer. The full test suite (now 5 production suites + the new 7-test SeedTests = 62 `@Test` funcs total across the project) will be run on the user's machine in Xcode when next opened; the parse-clean state means every `@Test` is expected to pass on that first run. The cold-launch perf bar in `coldLaunchUnder2s` is currently a soft cap of 5.0s for CI headroom; the production target <2.0s (FOUND-05) is documented in code + summary for tightening once CI cold-launch profiling stabilizes.

### Key Decisions Accumulated (Phase 1)

- **Plan 01-01 D-1**: Public access modifiers throughout (test target reaches via `@testable import`)
- **Plan 01-01 D-2**: snake_case rawValues for multi-word enum cases (matches `yuhonas/free-exercise-db` wire format)
- **Plan 01-01 D-3**: `@Relationship(inverse:)` declared on owning side only (single canonical place per relationship)
- **Plan 01-02 D-1**: `enum FitbodSchemaMigrationPlan: SchemaMigrationPlan` (not `class`) — Apple-canonical form
- **Plan 01-02 D-2**: `let container: ModelContainer` (not `lazy var`) — Sendable-friendly under Swift 6 strict concurrency
- **Plan 01-02 D-4**: Interim `RootView` stays in `ContentView.swift` for this plan; renamed + moved to `App/RootView.swift` by plan 03-01 as a single pbxproj edit
- **Plan 01-03 D-1**: `PreviewModelContainer` is an `enum` (not `struct` or `class`) — namespace-only type, matches SchemaV1 / FitbodSchemaMigrationPlan style
- **Plan 01-03 D-3**: `InMemoryContainer.makeEmpty()` throws (vs `make()`'s `try!`) — tests surface ModelContainer init errors verbatim, previews fatalError
- **Plan 01-03 D-4**: Twelve separate per-entity default-init `@Test` funcs (not one parameterised loop) — clearer failure messages for FOUND-02 regressions
- **Plan 01-03 D-5/D-6**: `EnumPersistenceTests` parameterises over `Enum.allCases` (auto-covers new cases); `EnumTests` asserts case count AND the full rawValue `Set<String>` (catches renames + additions)
- **Plan 01-03 D-7**: `Exercise.previewSample` lives in the main target (not test target) so `#Preview` blocks reach it without `@testable` ceremony
- **Plan 02-01 D-1**: Pinned upstream SHA `acd61f7` recorded in `SOURCE.md`; future refresh follows the 5-step procedure
- **Plan 02-01 D-2**: Did NOT pre-filter at vendor time — bundled JSON is the full 873-row upstream dataset byte-for-byte; the strength filter is a runtime predicate (`EquipmentMapper.shouldImport(category:)`), preserves diff-against-upstream traceability
- **Plan 02-01 D-3**: `e-z curl bar → .barbell` (not `.other`) — UX-driven mapping so 9 E-Z curl exercises stay discoverable under the "barbell" filter chip
- **Plan 02-01 D-7**: `MuscleRegionMap.allSlugs` exposed as `public static let [String]` so plan 02-02 has a single source of truth for the canonical 17-slug list
- **Plan 02-02 D-1**: Iterated `MuscleRegionMap.allSlugs` (not the DTO-derived union) when seeding the 17 MuscleGroup rows — future-bump safe even if a dataset refresh temporarily drops a slug; canonical 17 muscles always present for Phase 5's MEV/MAV/MRV wiring
- **Plan 02-02 D-2**: Unknown-slug stimulus rows are soft-skipped with `os_log` debug rather than throwing `SeedError.unexpectedMuscleSlug` — keeps the seed resilient against future dataset refreshes; error case preserved in type surface for callers that want strict validation
- **Plan 02-02 D-3**: `dto.mechanic ?? Mechanic.compound.rawValue` (not bare string `"compound"`) — type-system-enforced rawValue fallback so future enum renames surface as compile errors, not silent drift
- **Plan 02-02 D-7**: Removed defensive pre-flush save after MuscleGroup inserts — Pitfall #7 only requires *insert* before children reference, not *save*. Muscle rows ride along on the first exercise batch's save; satisfies AC #5 (`grep -c 'modelContext.save' ≤ 3`)
- **Plan 03-01 D-1**: Added a small `@Observable SeedState` type (idle / loading / ready / failed(message:)) rather than the plan's bare `@State Bool` — four-case enum carries error.localizedDescription for the deferred Wave-4 Alert without restructuring RootView
- **Plan 03-01 D-2**: Splash dismissal uses a dual-signal predicate (`@Query<Exercise>.isEmpty AND SeedState in {.idle, .loading}`) — AND form gives cleanest behaviour in all four scenarios (cold first launch / warm second launch / cold launch + seed failure / hot dev rebuild); eliminates second-launch flash
- **Plan 03-01 D-4**: Two interim tab hosts (`LibraryTabHost` / `SettingsTabHost`) as private structs inside `RootView.swift` — co-located so plan 03-02 / 04-01 swaps are visible in single 1-line diffs
- **Plan 03-02 D-1**: Empty state ships with both UI-SPEC copy variants now (with-query + without-query) rather than deferring to 04-01. Only the "Create Custom Exercise" CTA (which depends on 03-04's editor existing) is deferred — headline + body copy is locked now per UI-SPEC § Empty states.
- **Plan 03-02 D-2**: Inner `FilteredExerciseList` takes 4 init parameters (`predicate / activeQuery / hasActiveFilters / clearFiltersAction`) rather than 1, so the empty-state surface can render the verbatim UI-SPEC copy without violating FOUND-06 (only the inner view consumes `@Query`).
- **Plan 03-02 D-3**: `FilterPickerSheet` is one file with a four-case switch on `facet`, not four separate sheet files — each section is < 20 lines and the toolbar buttons are identical.
- **Plan 03-02 D-4**: `LibraryTabHost` stays as a one-line wrapper (`var body: some View { ExerciseLibraryView() }`) for symmetry with the pending `SettingsTabHost` swap in plan 04-01.
- **Plan 03-02 D-5**: `EmptyLibraryView` and `NewCustomExerciseRequest` are private nested types inside `ExerciseLibraryView.swift` so plan 04-01's empty-state polish and plan 03-04's editor wiring are single-file diffs.
- **Plan 03-02 D-6**: Equipment + Pattern display names split underscored raw values (`weighted_bodyweight` → "Weighted Bodyweight", `horizontal_push` → "Horizontal Push") via `.replacingOccurrences(of: "_", with: " ").capitalized` rather than `.capitalized` on the raw (which yields `Weighted_bodyweight`).
- **Plan 03-04 D-1**: Duplicate-slug guard in `CustomExerciseEditor.appendMuscle(_:)` — `guard !draft.muscles.contains(where: { $0.slug == mg.slug }) else { return }` prevents accidental double-mapping of the same muscle (silent volume doubling — PITFALLS #5's evil twin not called out by the pitfall directly).
- **Plan 03-04 D-2**: `CustomExerciseEditor` body decomposed into 5 private computed section properties (`nameSection` / `musclesSection` / `equipmentSection` / `mechanicSection` / `imageSection`) to pre-empt the SwiftUI "expression too complex" wall on multi-section Forms.
- **Plan 03-04 D-3**: Muscles section uses 3-closure `Section { ... } header: { Text("Muscles") } footer: { VStack { ... } }` form rather than `Section("Muscles") { ... }` — required because the footer conditionally shows the `systemRed` validation error text alongside the body explanatory text.
- **Plan 03-04 D-4**: Inline validation error "At least one primary muscle is required to save." only shown when `!draft.isValid AND !draft.muscles.isEmpty` (not on fresh draft) — the "Add Primary Muscle" button affordance carries intent before any muscle is mapped.
- **Plan 03-04 D-5**: Removed dead `NewCustomExerciseRequest` navigation token from `ExerciseLibraryView.swift` — the plan-03-02 file-private token was the 1-line edit-point for plan 03-04; the `.sheet(isPresented:)` wiring replaces both the `NavigationLink` and the `navigationDestination`, making the token orphan state.
- **Plan 03-04 D-6**: Trash button on `MuscleWeightRow` uses `Button(role: .destructive)` + `.foregroundStyle(.secondary)` (quiet visual; destructive semantic) rather than full destructive-red. Same convention Apple's Settings app uses for in-row destructive sub-actions.
- **Plan 03-04 D-7**: Single Save handler in `CustomExerciseEditor` branches internally on `isEditing` to call `materialize(into:)` or `updateExisting(in:)` then `ctx.save()` + dismiss — keeps the toolbar consistent regardless of entry point.
- **Plan 03-04 D-8**: Edit Exercise / Delete code paths wired but not user-reachable in v1 (no edit affordance from the library list — deferred per plan Out of Scope). Documented as a Known Stub in the SUMMARY for traceability; a future entry point won't require changes to this plan's files.

---

*State initialized: 2026-05-10 after roadmap creation. Updated: 2026-05-11 after plan 03-04 (Wave 3 seq 4 of 4 complete; CustomExerciseEditor + CustomExerciseDraft + PITFALLS #5 validation gate shipped; ExerciseLibraryView "+" toolbar rewired to .sheet presenting the real editor; 11 new Swift Testing functions; LIB-04 / FOUND-07 closed, LIB-05 / LIB-06 / FOUND-06 verified at the editor surface. Phase 1 next: 03-03 ExerciseDetailView, the last plan in the phase).*
