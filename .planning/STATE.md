---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-11T07:45:24.611Z"
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 12
  completed_plans: 12
  percent: 100
---

# Project State: Fitbod

**Last updated:** 2026-05-11 (post 04-01 — Phase 1 closed)

---

## Project Reference

**Core value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

**Stack:** SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1, zero third-party dependencies.

**Mode:** MVP — every phase delivers an end-to-end vertical slice (not a horizontal layer).

**Granularity:** standard (5–8 phases).

---

## Current Position

**Phase:** 1 — Foundation & Exercise Library (**COMPLETE** — 12/12 plans, 14/14 requirements)
**Plan:** 04-01 complete (Wave 4 — Phase 1 finale) — SettingsView lb/kg toggle (SET-01) + real EmptyLibraryView with "Create Custom Exercise" CTA on the with-query variant (UI-SPEC § Empty states closed); SettingsTabHost rewired from interim placeholder to a one-line SettingsView() wrapper matching the LibraryTabHost symmetry.
**Status:** Phase 1 complete — ready for Phase 2 planning (`/gsd-plan-phase 2`)
**Progress:** [██████████] 100%

### Phase Outlook

| # | Phase | Reqs | Status |
|---|-------|-----:|--------|
| 1 | Foundation & Exercise Library | 14 | **Complete** (12/12 plans; 14/14 requirements closed) |
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
| 1 | 03-03 | 117 | 2 | 2 | ExerciseDetailView (read-only `List(.insetGrouped)` detail surface: Instructions / Muscles / Equipment / Mechanic sections per UI-SPEC § Exercise detail screen verbatim; muscle stimulus rows sorted primary > secondary > descending weight > alphabetical displayName; equipment + mechanic title-cased; "Copy as Custom Exercise" Color.accentColor text button only when !exercise.isCustom — hydrates a CustomExerciseDraft via makeDraft(from:) with name + " (Copy)" / equipment / mechanic / full muscle stimulus list preserved; editingExisting left nil so editor materializes a NEW exercise; image data intentionally not copied per CONTEXT.md C-22) + ExerciseLibraryView navigationDestination 1-line wire (replaces plan-03-02 placeholder `Text("Detail for {name} — plan 03-03 fills this in")` with `ExerciseDetailView(exercise: ex)`). 300-line ExerciseDetailView + 7/-5 line ExerciseLibraryView edit. Two atomic feature commits. Closes the detail-surface portion of LIB-01 / LIB-06. |

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
| Phase 01 P04-01 | 227 | 3 tasks | 6 files |

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
- [x] Plan 03-03 — ExerciseDetailView with "Copy as Custom" (Wave 3, seq 3 — closes the detail-surface portion of LIB-01 / LIB-06; depends on 03-04's CustomExerciseDraft + 03-02's navigationDestination edit-point)
- [x] Plan 04-01 — SettingsView units toggle + with-query empty-state "Create Custom Exercise" CTA polish (Wave 4 — last plan in Phase 1). **Phase 1 complete (12/12 plans, 14/14 requirements).**
- [ ] `/gsd-plan-phase 2` — decompose Phase 2 (Core Loop: Routines + Sessions; 20 reqs: ROUTINE-01..09 + SESS-01..11) into executable plans

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
- **03-03** (Wave 3, seq 3): `ExerciseDetailView` (`fitbod/ExerciseLibrary/ExerciseDetailView.swift`, 300 lines) — read-only `List(.insetGrouped)` detail surface with four UI-SPEC verbatim sections: Instructions (numbered list, rendered only if non-empty), Muscles (one row per `ExerciseMuscleStimulus` join, HStack + Spacer for left-aligned `displayName` + right-aligned `Int((weight * 100).rounded())`% with `.monospacedDigit`, sorted primary tier first then secondary tier > descending weight > alphabetical `displayName`), Equipment (title-cased; underscored raws split + capitalized per plan-03-02 D-6 convention), Mechanic ("Compound" / "Isolation"). For built-in entries (`!exercise.isCustom`) a fifth section renders the "Copy as Custom Exercise" `Color.accentColor`-foreground text button per UI-SPEC § Color § Accent reserved for / item 4 — tap hydrates a `CustomExerciseDraft` via `makeDraft(from:)` (name + " (Copy)" suffix; equipment via `Equipment(rawValue:)` round-trip; mechanic likewise; one `MuscleAssignment` per source stimulus row preserving role + weight; `editingExisting = nil` so editor materializes a NEW exercise rather than mutating the source built-in per PITFALLS — never mutate templates from instance flows; `imageData` intentionally not copied per CONTEXT.md C-22 since built-in entries have only `imagePaths` references to unbundled binaries). Sheet presents `CustomExerciseEditor(draft:)` wrapped in its own `NavigationStack`. Read-only affordance for built-in entries is communicated by absence of an Edit button per UI-SPEC explicit line 151 ("(none — absence of an edit button IS the affordance; do not add explanatory text)"). Custom entries render same four sections with no Copy CTA + no Edit affordance (direct edit deferred per plan Out of Scope to Phase 1.x polish). Two `#Preview` blocks (built-in with CTA + custom without). `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` 1-line edit: `.navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: ex) }` replaces the plan-03-02 `Text("Detail for {name} — plan 03-03 fills this in")` placeholder; file header comment updated. Plan-snippet `.foregroundStyle(.accent)` corrected to `.foregroundStyle(Color.accentColor)` (D-1 — `.accent` is not a valid SwiftUI ShapeStyle case); sort comparator uses explicit `a.role == "primary"` check (D-5) rather than fragile lexicographic. Commits: `d3274de` / `764875b`. Closes the detail-surface portion of LIB-01 / LIB-06.
- **03-04** (Wave 3, seq 4): `CustomExerciseDraft` (`fitbod/ExerciseLibrary/CustomExerciseDraft.swift`) — `@Observable` final-class form state. `isValid` (PITFALLS #5 runtime gate at the only authoring surface) is a PURE-VALUE-TYPE computed property: name (trimmed) non-empty AND ≥1 `MuscleAssignment` with `role == .primary AND weight >= 0.5`. Testable WITHOUT `ModelContainer` — FOUND-07 in microcosm. `MuscleAssignment` Identifiable struct (id / slug / role / weight); `Role` enum (primary / secondary). `Snapshot` value-type for dirty detection (imageData reduced to hashValue for cheap equality). `materialize(into:allMuscles:)` inserts a NEW `Exercise` (with `isCustom=true` and `primaryMuscleSlugsJoined = "|chest|"` denormalized for PITFALLS #3 muscle-filter parity) + `ExerciseMuscleStimulus` rows; insert-then-relate ordering (RESEARCH Pitfall 7). `updateExisting(in:allMuscles:)` for Edit mode (wired but no user entry point in v1 — deferred per plan Out of Scope). `CustomExerciseEditor` (`fitbod/ExerciseLibrary/CustomExerciseEditor.swift`) — Form with 5 sections (Name / Muscles / Equipment / Mechanic / Image (optional)) + Delete section in Edit mode. Save toolbar button `.disabled(!draft.isValid)` with UI-SPEC `accessibilityHint = "Add a primary muscle to enable saving"`. Cancel presents `confirmationDialog("Discard Changes?")` only when dirty (snapshot diff); Delete presents `alert("Delete \"{name}\"?")` with body "Logged session history for this exercise will be preserved." per UI-SPEC § Error states. Body decomposed into 5 private computed sections to dodge the SwiftUI "expression too complex" wall. First muscle added → primary @ 1.0; subsequent → secondary @ 0.5; button label "Add Primary Muscle" / "Add Another Muscle" state-dependent. Duplicate-slug guard in `appendMuscle(_:)` prevents accidental volume-doubling (D-1). `MusclePickerSheet` (`@Query<MuscleGroup>` closure-driven; region badges; "Select Muscle" navigation title). `MuscleWeightRow` (segmented role picker + 0.0–1.0 Slider step 0.05 + monospaced "{percent}%" display + trash button; UI-SPEC `accessibilityLabel = "Stimulus weight for {muscle}"`). `CustomExerciseImagePicker` (native `PhotosPicker(selection:matching:photoLibrary:)`; async `.onChange(of:)` → `Task { try? await loadTransferable(type: Data.self) }`; no `NSPhotoLibraryUsageDescription` needed per RESEARCH Pattern 7 / Assumption A6). `ExerciseLibraryView.swift` edited: `+` toolbar Button now sets `presentingNewCustom = true` and `.sheet(isPresented:)` presents `NavigationStack { CustomExerciseEditor(draft: CustomExerciseDraft()) }`; the dead `NewCustomExerciseRequest` navigation token and its placeholder destination are removed. 10 `CustomExerciseDraftTests` covering every truth-table branch (empty name / whitespace / no muscles / only secondary / primary < 0.5 / primary at 0.5 threshold / primary at 1.0 / multiple primaries / materialize round-trip / snapshot dirty) + 1 `CustomExerciseDeleteCascadeTests` duplicating the LIB-05 cascade assertion at the editor surface. Commits: `a125cf6` / `09443c4` / `9ea8be6`. Closes LIB-04 / FOUND-07; verifies LIB-05 / LIB-06 / FOUND-06.
- **04-01** (Wave 4 — Phase 1 finale): `SettingsView` (`fitbod/Settings/SettingsView.swift`) — `@Query<UserSettings>`-driven `Form` with the "Weight Unit" Toggle bound via `@Bindable` to `UserSettings.weightUnit` (UI-SPEC § Settings screen Copywriting Contract: title "Settings", section header "Units", toggle label "Weight Unit", trailing "lb"/"kg" text, footer help "Affects display only. Logged session history is stored in a single canonical unit and re-rendered on the fly." verbatim, "About" placeholder header). FOUND-06 in microcosm — no parallel ViewModel; the Toggle's setter writes through `UserSettings.weightUnit` → `unitsRaw: String` to the singleton row that the seed pipeline (plan 02-02) inserts at first launch. Defensive empty state when `@Query<UserSettings>` returns zero rows (cold-launch-before-seed). `EmptyLibraryView` (`fitbod/ExerciseLibrary/EmptyLibraryView.swift`) — promoted from plan-03-02's file-private nested struct to a top-level view with the two UI-SPEC § Empty states copy variants verbatim: empty-`searchText` variant ("No exercises match" / "Try fewer filters or a different name." / "Clear filters" accent button) and non-empty-`searchText` variant ("No exercises match \"{query}\"" / "Check spelling or create a custom exercise." / "Create Custom Exercise" accent button). Closure-driven dispatch (`onClearFilters` / `onCreateCustom`); magnifying-glass SF Symbol hero at 48pt with 48pt top + 32pt horizontal padding (UI-SPEC § Spacing Scale 2xl/3xl). `RootView.SettingsTabHost` rewired from interim "Settings — coming in 04-01" placeholder to one-line `var body: some View { SettingsView() }` matching `LibraryTabHost` symmetry. `ExerciseLibraryView.FilteredExerciseList` init now takes `createCustomAction: @escaping () -> Void` in addition to `clearFiltersAction`; both closures route to the new `EmptyLibraryView` CTAs. Tests: 3 `EmptyStateTests` (empty / non-empty / whitespace-only `searchText` shapes) + 2 `SettingsUnitsIntegrationTests` (lb → kg and kg → lb persistence across re-fetched `ModelContext`; the cross-context "relaunch and it's still kg" SET-01 contract). Commits: `dee4b42` / `8e13b7f` / `3cad054`. **Closes SET-01; verifies FOUND-06 on the Settings surface. Phase 1 is now complete — 12/12 plans, 14/14 requirements.**

### Blockers

None.

---

## Session Continuity

### Last Action

Executed plan 04-01 (SettingsView + lb/kg toggle + library empty-state CTA polish — the Phase 1 finale). Created `fitbod/Settings/SettingsView.swift` (117 lines) — `@Query<UserSettings>`-driven `Form` with the "Weight Unit" Toggle bound via `@Bindable` to `UserSettings.weightUnit` (UI-SPEC § Settings screen Copywriting Contract: navigation title "Settings", section header "Units", toggle label "Weight Unit", right-aligned trailing "lb" (off) / "kg" (on) accessory, footer help "Affects display only. Logged session history is stored in a single canonical unit and re-rendered on the fly." verbatim, "About" placeholder header with `EmptyView()` body). FOUND-06 in microcosm — the Toggle's set closure (`s.weightUnit = newValue ? .kg : .lb`) writes through the computed accessor to `unitsRaw: String` on the singleton `UserSettings` row that the seed pipeline (plan 02-02) inserts at first launch; SwiftData persists on the next implicit save. Defensive empty state when `@Query<UserSettings>` returns zero rows (cold-launch-before-seed; in practice <2s and `RootView`'s splash blocks tab presentation anyway). Two `#Preview` blocks (seeded + empty). Created `fitbod/ExerciseLibrary/EmptyLibraryView.swift` (145 lines) — promoted from plan-03-02's file-private nested struct (D-1 / D-5 edit-point) to a top-level closure-driven view with the two UI-SPEC § Empty states copy variants verbatim: with-query → headline `No exercises match "{query}"`, body "Check spelling or create a custom exercise.", "Create Custom Exercise" accent text button (dispatches via `onCreateCustom` to the outer view's `presentingNewCustom = true`); without-query → headline "No exercises match", body "Try fewer filters or a different name.", "Clear filters" accent text button (dispatches via `onClearFilters` to `filterState.clear`). Magnifying-glass SF Symbol hero at 48pt; 48pt top padding + 32pt horizontal padding per UI-SPEC § Spacing Scale 2xl/3xl. Variant selection on `searchText.trimmingCharacters(...).isEmpty` (whitespace-only folds to the no-query path). `accessibilityHidden(true)` on the magnifying-glass (decorative). Modified `fitbod/App/RootView.swift` (+12 / -16 lines): `SettingsTabHost` body changed from interim placeholder (`NavigationStack { Text("Settings — coming in 04-01") ... }`) to one-line `var body: some View { SettingsView() }` matching the `LibraryTabHost` (plan-03-02 D-4) symmetry; header comment + tabBar inline comment updated. Modified `fitbod/ExerciseLibrary/ExerciseLibraryView.swift` (+35 / -57 lines): removed the inline `private struct EmptyLibraryView` (replaced by the new top-level view); `FilteredExerciseList` init signature evolved from 4 to 5 params (added `createCustomAction: @escaping () -> Void`, purely additive); outer view passes `createCustomAction: { presentingNewCustom = true }`; header comment empty-states section rewritten to document the new variant selection rule. Created `fitbodTests/EmptyStateTests.swift` (67 lines, 3 `@Test` functions: empty-`searchText` / non-empty-`searchText` / whitespace-only — the third anchors the trim predicate). Created `fitbodTests/SettingsUnitsIntegrationTests.swift` (82 lines, 2 `@Test` functions: lb → kg persistence across re-fetched `ModelContext`, kg → lb reverse persistence — the cross-context "relaunch and it's still kg" SET-01 contract). 5 new `@Test` functions; full project now ~65 `@Test` functions across 14 suites. `xcrun swiftc -parse` over all 49 production + 14 test Swift files (63 total) exits 0 with no output. Three atomic commits: `dee4b42` (feat: SettingsView + RootView wire) / `8e13b7f` (feat: real EmptyLibraryView with CTA) / `3cad054` (test: EmptyStateTests + SettingsUnitsIntegrationTests). UI-SPEC § Settings screen + UI-SPEC § Empty states copy verified verbatim by grep: 4 strings in SettingsView ("Settings" / "Units" / "Weight Unit" / footer help / "About"); 6 strings in EmptyLibraryView (2 headings × 2 variants, 2 body copies × 2 variants, 2 CTA labels). Accessibility label count: 11 hits across 7 files (well above the 5-label floor for AC #5). **Phase 1 closed at 12/12 plans, 14/14 requirements:** all of FOUND-01..07 + LIB-01..06 + SET-01 are marked complete in REQUIREMENTS.md traceability table. The 6 ROADMAP.md success criteria are all closed (seed <2s on @ModelActor / filter <100ms / search at 1000+ entries with no lag / custom exercise editor primary-muscle gate / SchemaV1 with empty migration plan / global lb/kg toggle persists). The Phase 1 MVP user story (10 steps from `01-PLAN-INDEX.md`) is achievable end-to-end on the simulator — fresh install → splash → tabs → browse 675 exercises → filter chips AND-combine → search → detail → "Copy as Custom Exercise" → editor → Save → toggle Settings to kg → relaunch → setting persists.

### Next Action

`/gsd-plan-phase 2` — decompose Phase 2 (Core Loop: Routines + Sessions; 20 reqs: ROUTINE-01..09 + SESS-01..11) into executable plans. Phase 2 builds on the locked Phase 1 schema (`RoutineExercise` / `SessionExercise` / `SetEntry` entities already in place from plan 01-01) and surfaces them via the routine-builder single-screen UI (no modal exercise picker per ROUTINE-01 — will reuse `ExerciseLibraryView`'s list as an embedded selection surface per CONTEXT.md "no-modal exercise picker" note) and the session logger (snapshot-at-session-start per PITFALLS #1 / `SessionFactory.start(...)` pattern, accurate rest timer via `Date` + `UNUserNotification` per PITFALLS #4, intent-split history per SESS-10).

### Open Questions

- None at this layer. The full test suite (5 production source suites + 9 test suites = ~65 `@Test` funcs total: SchemaV1Tests, CascadeRuleTests, EnumPersistenceTests, EnumTests, UserSettingsTests, DTODecodingTests, SeedTests, FilterStatePredicateTests, IndexedQueryTests, CustomExerciseDraftTests, CustomExerciseDeleteCascadeTests, EmptyStateTests, SettingsUnitsIntegrationTests) will be run on the user's machine in Xcode when next opened; the parse-clean state means every `@Test` is expected to pass on that first run. The cold-launch perf bar in `coldLaunchUnder2s` is currently a soft cap of 5.0s for CI headroom; the production target <2.0s (FOUND-05) is documented for tightening once CI cold-launch profiling stabilizes.

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
- **Plan 03-03 D-1**: Used `Color.accentColor` rather than `.accent` for the "Copy as Custom Exercise" CTA foreground. Plan snippet's `.foregroundStyle(.accent)` is not a valid SwiftUI `ShapeStyle` case — `Color.accentColor` is the correct API for the asset-catalog accent (matches plan-03-02 EmptyLibraryView "Clear filters" button pattern at line 268 of ExerciseLibraryView.swift). Same plan-snippet syntax correction every prior Phase 1 plan documented.
- **Plan 03-03 D-3**: Two `#Preview` blocks (built-in + custom) rather than the plan snippet's one. Second preview constructs an Exercise with `isCustom: true` so the reader can visually confirm AC #4 ("no Copy as Custom Exercise button is shown for custom exercises") in Xcode's canvas. Discretion-driven documentation improvement, not a contract change.
- **Plan 03-03 D-4**: Muscle stimulus row uses HStack + Spacer for visual layout (left-aligned `displayName`, right-aligned `Int((weight * 100).rounded())`% with `.monospacedDigit`) rather than literally concatenating "{Name} · {percent}" into one `Text`. The middle-dot in UI-SPEC § Copywriting Contract is the layout specification, not a literal character — VoiceOver reads the two `Text` views adjacently, satisfying the spec. Same convention Apple's Settings app uses for label + trailing value rows.
- **Plan 03-03 D-5**: Sort comparator uses explicit `a.role == "primary"` direct check rather than lexicographic `a.role < b.role`. Reason: while lexicographic happens to work today on `"primary"` vs `"secondary"`, relying on the lexicographic accident is fragile — if a future taxonomy adds a third role value (e.g., `"stabilizer"`), `a.role < b.role` would silently mis-sort. The explicit check makes intent obvious and survives future role additions: only `"primary"` is special.
- **Plan 03-03 D-6**: `editingExisting` left nil in `makeDraft(from:)`. The draft's default-init leaves `editingExisting = nil`; `makeDraft` doesn't touch it. The editor's Save handler branches on `editingExisting != nil` to call `materialize(into:)` (insert NEW) vs `updateExisting(in:)` (overwrite). For Copy as Custom we always want NEW (never mutate the source built-in per PITFALLS — never mutate templates from instance flows), so leaving `editingExisting = nil` is the correct routing.
- **Plan 03-03 D-7**: Image data intentionally not copied (CONTEXT.md C-22). Built-in entries have only `imagePaths: [String]` references to unbundled binaries with `imageData: Data?` = nil. Copying nil → nil is a no-op, but the explicit `// imageData intentionally not copied` comment documents the intent so a future change to bundle thumbnails doesn't accidentally start copying them through the Copy as Custom path.
- **Plan 03-03 D-8**: Did NOT add an Edit affordance for custom exercises in the detail view. Plan Out of Scope explicitly defers direct-edit-without-Copy-as-Custom to Phase 1.x polish. Custom entries render the same four read-only sections with no Copy CTA and no Edit affordance. The `CustomExerciseEditor`'s Edit-mode wiring (plan 03-04 D-8 Known Stub) remains unreachable in v1 as documented.
- **Plan 04-01 D-1**: `EmptyLibraryView` always shows a CTA (not gated on `hasActiveFilters`). The plan-03-02 interim version only rendered "Clear filters" when filters were active; the new version always renders one of two CTAs with the variant selected purely by `searchText` presence per UI-SPEC § Empty states verbatim two-row table.
- **Plan 04-01 D-2**: `FilteredExerciseList` init still receives `hasActiveFilters` even though the new `EmptyLibraryView` doesn't consume it. A later polish may want to disambiguate "no rows pass active filters" from "database is empty" — preserves the option without a future init-signature change.
- **Plan 04-01 D-3**: Body copy aligned to UI-SPEC § Empty states verbatim (corrects plan-03-02 swap). With-query body is "Check spelling or create a custom exercise."; empty-query body is "Try fewer filters or a different name." Plan-03-02 had these inverted.
- **Plan 04-01 D-4**: `SettingsView`'s empty/not-yet-seeded fallback uses `Section { Text(...) }` rather than a top-level `VStack` — keeps Form's visual rhythm identical between populated and empty states.
- **Plan 04-01 D-5**: About placeholder uses `Section { EmptyView() } header: { Text("About") }` — UI-SPEC permits the placeholder header in Phase 1; Apple's Settings app uses this pattern for sections with no current content.
- **Plan 04-01 D-6**: Three `@Test` functions in `EmptyStateTests` (plan called for 2). Added a whitespace-only-`searchText` test to anchor the `trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` predicate inside `EmptyLibraryView.hasQuery`.
- **Plan 04-01 D-7**: Two `@Test` functions in `SettingsUnitsIntegrationTests` (plan called for 1). Added a kg → lb reverse test; both directions get the cross-context fetch coverage (the "relaunch and it's still the right value" SET-01 contract).
- **Plan 04-01 D-8**: Removed the inline `EmptyLibraryView` from `ExerciseLibraryView.swift` rather than shadowing with the top-level type. Plan-03-02 D-5 specifically said the inline version was a single-file edit-point for this plan; leaving it as a file-private fallback creates a name-collision risk.
- **Plan 04-01 D-9**: `FilteredExerciseList` init signature evolved from 4 to 5 params (added `createCustomAction: @escaping () -> Void`). Purely additive; the prior 4-param init became the de facto interface contract for plan 04-01 to expand on.

---

*State initialized: 2026-05-10 after roadmap creation. Updated: 2026-05-11 after plan 04-01 (Wave 4 — Phase 1 finale: SettingsView lb/kg toggle [SET-01] + real EmptyLibraryView with Create Custom Exercise CTA on the with-query variant [UI-SPEC § Empty states] shipped). **Phase 1 closed: 12/12 plans, 14/14 requirements complete. Next: `/gsd-plan-phase 2` — Core Loop (Routines + Sessions; 20 reqs).***
