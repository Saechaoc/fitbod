---
phase: 01-foundation-exercise-library
reviewed: 2026-05-11T00:00:00Z
depth: standard
files_reviewed: 60
files_reviewed_list:
  - fitbod/App/PlaceholderTabView.swift
  - fitbod/App/RootView.swift
  - fitbod/App/SeedState.swift
  - fitbod/ExerciseLibrary/CustomExerciseDraft.swift
  - fitbod/ExerciseLibrary/CustomExerciseEditor.swift
  - fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift
  - fitbod/ExerciseLibrary/EmptyLibraryView.swift
  - fitbod/ExerciseLibrary/EquipmentMapper.swift
  - fitbod/ExerciseLibrary/ExerciseDTO.swift
  - fitbod/ExerciseLibrary/ExerciseDetailView.swift
  - fitbod/ExerciseLibrary/ExerciseFilterBar.swift
  - fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift
  - fitbod/ExerciseLibrary/ExerciseLibraryView.swift
  - fitbod/ExerciseLibrary/ExerciseRow.swift
  - fitbod/ExerciseLibrary/FilterChip.swift
  - fitbod/ExerciseLibrary/FilterPickerSheet.swift
  - fitbod/ExerciseLibrary/FilterState.swift
  - fitbod/ExerciseLibrary/MusclePickerSheet.swift
  - fitbod/ExerciseLibrary/MuscleRegionMap.swift
  - fitbod/ExerciseLibrary/MuscleWeightRow.swift
  - fitbod/ExerciseLibrary/SeedError.swift
  - fitbod/Models/Block.swift
  - fitbod/Models/BlockPhase.swift
  - fitbod/Models/Enums/BlockPhaseKind.swift
  - fitbod/Models/Enums/Equipment.swift
  - fitbod/Models/Enums/Force.swift
  - fitbod/Models/Enums/Intent.swift
  - fitbod/Models/Enums/Level.swift
  - fitbod/Models/Enums/Mechanic.swift
  - fitbod/Models/Enums/MuscleRegion.swift
  - fitbod/Models/Enums/Pattern.swift
  - fitbod/Models/Enums/ProgressionKind.swift
  - fitbod/Models/Enums/SetType.swift
  - fitbod/Models/Enums/WeightUnit.swift
  - fitbod/Models/Exercise+Preview.swift
  - fitbod/Models/Exercise.swift
  - fitbod/Models/ExerciseMuscleStimulus.swift
  - fitbod/Models/MuscleGroup.swift
  - fitbod/Models/MuscleVolumeTarget.swift
  - fitbod/Models/Routine.swift
  - fitbod/Models/RoutineExercise.swift
  - fitbod/Models/Session.swift
  - fitbod/Models/SessionExercise.swift
  - fitbod/Models/SetEntry.swift
  - fitbod/Models/UserSettings.swift
  - fitbod/Persistence/FitbodSchemaMigrationPlan.swift
  - fitbod/Persistence/PreviewModelContainer.swift
  - fitbod/Persistence/SchemaV1.swift
  - fitbod/Settings/SettingsView.swift
  - fitbod/fitbodApp.swift
  - fitbodTests/CascadeRuleTests.swift
  - fitbodTests/CustomExerciseDraftTests.swift
  - fitbodTests/DTODecodingTests.swift
  - fitbodTests/EmptyStateTests.swift
  - fitbodTests/EnumPersistenceTests.swift
  - fitbodTests/EnumTests.swift
  - fitbodTests/FilterStatePredicateTests.swift
  - fitbodTests/IndexedQueryTests.swift
  - fitbodTests/SchemaV1Tests.swift
  - fitbodTests/SeedTests.swift
  - fitbodTests/SettingsUnitsIntegrationTests.swift
  - fitbodTests/TestSupport/InMemoryContainer.swift
  - fitbodTests/UserSettingsTests.swift
findings:
  critical: 0
  warning: 7
  info: 8
  total: 15
status: clean
fixes_applied:
  iteration: 1
  fixed_at: 2026-05-11
  warnings_fixed: 7
  warnings_skipped: 0
  info_fixed: 0
  info_deferred: 8
  dispositions:
    WR-01: fixed (clear partial state + rollback on mid-import failure)
    WR-02: fixed (.serialized trait on SeedTests + IndexedQueryTests)
    WR-03: fixed (FilterChip accessibilityName decoupled from visual label)
    WR-04: fixed (doc comment + UI-SPEC corrected to match TabView behavior)
    WR-05: fixed (pre-lift Set<String?> for pattern; == lifts mechanic)
    WR-06: fixed (uniquingKeysWith first-wins in both Draft call sites)
    WR-07: fixed (selection binding + library NavigationPath in RootView)
    IN-01: deferred (cosmetic ordering)
    IN-02: deferred (enum convention note)
    IN-03: deferred (unused error case)
    IN-04: deferred (Equipment.displayName extension)
    IN-05: deferred (already tracked in plan; surface alert is Wave 4)
    IN-06: deferred (Phase 2 work — RoutineExercise index)
    IN-07: deferred (banner / logging is low priority)
    IN-08: deferred (additional test coverage)
---

# Phase 1: Code Review Report

**Reviewed:** 2026-05-11
**Depth:** standard
**Files Reviewed:** 60 Swift files + 2 asset-catalog JSONs
**Status:** issues_found

## Summary

The Phase 1 foundation is in good shape. The five load-bearing pitfalls (#1 template/instance separation, #2 versioned schema, #5 custom-exercise muscle mapping, #6 main-thread bulk insert, #7 indexed filtering) are mitigated correctly and have direct test coverage:

- `SchemaV1` wraps all 12 entities and `FitbodSchemaMigrationPlan.stages` is empty (PITFALLS #2 ✓)
- `Session`/`SessionExercise` carry full snapshot fields and have no SwiftData relationship back to `Routine`; `sourceRoutineID: UUID?` is the documented soft-reference (PITFALLS #1 ✓)
- `CustomExerciseDraft.isValid` enforces ≥1 primary muscle at weight ≥ 0.5; the rule has 9 unit tests covering each branch and the Save button is `.disabled(!draft.isValid)` (PITFALLS #5 ✓)
- `ExerciseLibraryImporter` is `@ModelActor`-isolated with 100-row batched saves and a `UserDefaults[seedVersionKey]` short-circuit (PITFALLS #6 ✓)
- `#Index<Exercise>` covers `canonicalName / equipmentRaw / mechanicRaw / isCustom / primaryMuscleSlugsJoined`; `#Unique<Exercise>([\.externalID])` prevents seed duplicates; `IndexedQueryTests` enforces a <200ms ceiling at seeded scale (PITFALLS #7 ✓)
- `Exercise → SessionExercise: nullify` cascade is exercised by two tests (`CascadeRuleTests.exerciseToSessionExerciseNullifies` and `CustomExerciseDeleteCascadeTests.nullifyOnDelete`), anchoring LIB-05

The 55+ Swift Testing functions cover every model's default round-trip, every enum's String persistence, the four cascade rules, the seed pipeline (idempotency + counts + perf), and the filter predicate matrix.

**However**, seven warnings should be addressed before any user-facing data is logged:

1. The importer's per-batch save is not transactional; a mid-seed failure leaves partial state plus a `#Unique` collision that bricks retry.
2. `SeedTests` and `IndexedQueryTests` share process-wide `UserDefaults` and will flake under Swift Testing's default parallel execution.
3. `FilterChip` accessibility label does not match the UI-SPEC contract.
4. `FilterState` does NOT actually reset on tab switch (TabView preserves children); the spec/comment is misleading.
5. Two `#Predicate` blocks force-unwrap optionals (`mechanic!` / `ex.patternRaw!`) inside the closure body, relying on `&&`/`||` short-circuit semantics that the predicate translator is permitted (but not required) to honor.
6. Tab re-tap pop-to-root is missing from `RootView`.
7. `Dictionary(uniqueKeysWithValues:)` in `CustomExerciseDraft.materialize` / `updateExisting` will trap-crash if the caller ever passes a `MuscleGroup` list with duplicate slugs.

Plus eight Info-level issues (mostly small consistency / dead code items).

## Warnings

### WR-01: Seed import is not transactional — partial failure bricks retry

**File:** `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift:225-247`
**Issue:** The importer commits 100-row batches via `try modelContext.save()` and only stamps `UserDefaults[seedVersionKey]` at the very end (line 247). If any batch save fails (disk full, schema-corruption, OOM during decoding of a particularly long instruction array, etc.), the partial state persists, the stamp is NOT bumped, and the next call to `seedIfNeeded()` runs the whole seed again. On the second run, every previously-imported `Exercise` will collide on the `#Unique<Exercise>([\.externalID])` constraint, and the save fails permanently. There is no recovery path short of wiping the on-disk store.

A handful of related risks:
- `MuscleGroup` rows from a partial seed already exist; the second pass re-inserts 17 more, hitting the `#Unique<MuscleGroup>([\.slug])` constraint.
- `UserSettings` is inserted only if `fetchCount == 0` (line 240-244), so that one row is correctly idempotent, but exercise/muscle/stimulus rows are not.

**Fix (cheapest):** Wrap the whole import in a try/catch and roll back via `modelContext.rollback()` before rethrowing. Better: gate every insert on a `fetchCount` check the way `UserSettings` does, OR `try modelContext.delete(model:where:)` to clear partial state at the start of each fresh seed. Production target since this is the seed pipeline for a one-shot launch:

```swift
public func seedIfNeeded(bundle: Bundle = .main) async throws {
    let bundled = try Self.bundledSeedVersion(bundle: bundle)
    let stored = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
    guard stored < bundled else { return }

    // Defensive: clear any partial state from a prior failed seed before
    // starting fresh. Cascade rules on Exercise → ExerciseMuscleStimulus
    // clean up the join rows; MuscleGroup → ExerciseMuscleStimulus does
    // the same on the muscle side. UserSettings is kept (it's the
    // singleton row the user may have already toggled).
    try modelContext.delete(model: Exercise.self)
    try modelContext.delete(model: MuscleGroup.self)
    try modelContext.save()

    // ... rest of seed ...
}
```

### WR-02: Test suites share process-wide `UserDefaults`; will flake under Swift Testing parallel execution

**File:** `fitbodTests/SeedTests.swift:49-51` and `fitbodTests/IndexedQueryTests.swift:48-50`
**Issue:** Swift Testing parallelizes `@Test` functions within a `@Suite` by default. `SeedTests` and `IndexedQueryTests` both call `UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)` at the start of each test. Because `UserDefaults.standard` is process-wide:

- Test A clears the stamp, calls `seedIfNeeded()` which sees stamp=0 and starts seeding.
- Test B (running in parallel) clears the stamp again — no-op since it's already cleared, but…
- Test A's `seedIfNeeded()` finishes and stamps version=1.
- Test B's `seedIfNeeded()` reads stamp=1 (set by Test A) and short-circuits → fails the count assertion.

The race is timing-dependent so passes on a single-core CI box and flakes on multi-core. Particularly painful for `SeedTests.idempotent`, which calls `seedIfNeeded()` twice and depends on the first call NOT being short-circuited.

**Fix:** Mark the suites `.serialized`:
```swift
@Suite("ExerciseLibraryImporter", .serialized)
struct SeedTests { ... }

@Suite("Indexed queries on Exercise", .serialized)
struct IndexedQueryTests { ... }
```
Or use a per-test `UserDefaults` suite via `UserDefaults(suiteName:)` instead of `.standard`, plumbed through the importer.

### WR-03: `FilterChip` accessibility label deviates from UI-SPEC contract

**File:** `fitbod/ExerciseLibrary/FilterChip.swift:62`
**Issue:** UI-SPEC § Accessibility Contract specifies `accessibilityLabel` for a filter chip as `"Muscle filter, 2 selected"` (facet name + selection count). The implementation does `accessibilityLabel("\(label) filter")` where `label` is already `"Muscle · 2"`. The actual VoiceOver readout is `"Muscle · 2 filter"` — both the separator and the word order are wrong. A blind user hearing "Muscle dot two filter" is going to puzzle over the readout.

**Fix:** Take facet name + count as separate parameters so the accessibility label and the visual label can diverge:

```swift
public struct FilterChip: View {
    let label: String           // visual label, e.g. "Muscle · 2"
    let accessibilityName: String  // VoiceOver-friendly, e.g. "Muscle filter, 2 selected"
    let isActive: Bool
    let action: () -> Void
    // ...
    .accessibilityLabel(accessibilityName)
```

Then in `ExerciseFilterBar`:
```swift
FilterChip(
    label: muscleLabel,
    accessibilityName: filterState.selectedMuscleSlugs.isEmpty
        ? "Muscle filter"
        : "Muscle filter, \(filterState.selectedMuscleSlugs.count) selected",
    isActive: !filterState.selectedMuscleSlugs.isEmpty
) { ... }
```

### WR-04: Filter state does NOT reset on tab switch — implementation contradicts CONTEXT.md / code comment

**File:** `fitbod/ExerciseLibrary/ExerciseLibraryView.swift:47-51, 94`
**Issue:** CONTEXT.md Area 2 says "Filter persistence: per-session only — filters reset when the user leaves the library tab." The code comment on lines 47-51 repeats this and claims `@State` + leaving the Library tab "creates a fresh `FilterState`." This is incorrect: `TabView` does NOT deallocate hidden tab children. The child view's identity is preserved; `@State` storage (including the `FilterState` reference) survives every tab switch. Filters only reset when the entire `RootView` is rebuilt — which essentially means on app cold launch.

The actual behavior is "filters persist for the life of the app process", not "filters reset per Library-tab session." This may be the more user-friendly behavior, but it doesn't match the documented contract.

**Fix (pick one):**
- **Update the spec to match the implementation** (recommended): persisted-for-process filters are usually what users want.
- **Or actually reset on tab switch:** wire `.onDisappear { filterState.clear() }` on the library list. (Use cautiously — `.onDisappear` fires on every tab switch, not only on Library-tab exits, so the modifier placement matters.)

At minimum, delete the lines 47-51 comment since it currently misleads anyone reading the file.

### WR-05: Force-unwraps inside `#Predicate` closures (`mechanic!` and `ex.patternRaw!`)

**File:** `fitbod/ExerciseLibrary/FilterState.swift:124, 136`
**Issue:** The predicate body contains:
```swift
(mechanic == nil || ex.mechanicRaw == mechanic!)        // line 124
&&
(patterns.isEmpty || (ex.patternRaw != nil && patterns.contains(ex.patternRaw!)))  // line 136
```

Both rely on the `||` and `&&` operators short-circuiting evaluation inside the macro-translated predicate. Foundation's `#Predicate` macro does honor short-circuit semantics in current iOS 18 SDKs, so this works today. But two practical risks:

1. **Static-analysis tooling and future SDK updates** may treat the force-unwrap as a hard reference, surfacing a warning or (worst case) generating different SQL.
2. **Readability:** a reviewer scanning the file sees `mechanic!` and has to verify the guard hop above it.

**Fix:** Use optional-aware operators that survive the predicate translator unambiguously:

```swift
// Replace mechanic clause:
(mechanic == nil || mechanic == ex.mechanicRaw)
// Comparing Optional to non-Optional via `==` lifts the RHS into Optional — no force-unwrap.

// Replace pattern clause:
(patterns.isEmpty || (ex.patternRaw.flatMap { patterns.contains($0) } ?? false))
// Or pre-compute a Set<String?> and let the predicate compare directly.
```

### WR-06: `Dictionary(uniqueKeysWithValues:)` in draft materialize/update will trap on duplicate slugs

**File:** `fitbod/ExerciseLibrary/CustomExerciseDraft.swift:247-249, 291-293`
**Issue:** Both call sites build the muscle lookup with `Dictionary(uniqueKeysWithValues: allMuscles.map { ($0.slug, $0) })`. `uniqueKeysWithValues:` trap-crashes if any key repeats. Production callers pass `@Query<MuscleGroup>` results, and the schema declares `#Unique<MuscleGroup>([\.slug])`, so duplicates should never appear in practice.

However: the importer's bug surface (see WR-01) can create duplicate `MuscleGroup` rows transiently if a partial seed retries. Once that happens, `@Query<MuscleGroup>` returns duplicates, the editor's save button is tapped, and the app hard-crashes inside the dictionary initializer with `Fatal error: Duplicate values for key`.

**Fix:** Use the failable initializer `Dictionary(allMuscles.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })`. The first-wins choice is fine — the duplicates have the same `slug` and the materialize/update only reads `slug` from the muscle anyway.

### WR-07: Tab re-tap pop-to-root not implemented

**File:** `fitbod/App/RootView.swift:104-134`
**Issue:** UI-SPEC § Interaction patterns: "When the Library tab is tapped while already active, clear its `NavigationPath`." None of the five tabs binds a `NavigationPath`, and `RootView` has no notion of which tab is currently selected. So tapping the Library tab while on `ExerciseDetailView` does NOT pop back to the library list — the user has to use the back button. Same for any future deep navigation.

**Fix:** Wire a `@State selectedTab` to `TabView`'s selection binding, then detect double-taps and clear the matching `NavigationPath`:
```swift
@State private var selectedTab: Tab = .library
@State private var libraryPath = NavigationPath()
@State private var settingsPath = NavigationPath()
// ... use Binding<Tab> with onChange to detect re-tap and call libraryPath.removeAll() ...
```

Note: this is partially documented as "Wave 4 polish" in the file header, but no follow-up task is filed and the UI-SPEC contract is not met today.

## Info

### IN-01: `updateExisting` writes `primaryMuscleSlugsJoined` after stimulus inserts; `materialize` writes it during construction

**File:** `fitbod/ExerciseLibrary/CustomExerciseDraft.swift:235-260 vs 305-308`
**Issue:** `materialize()` populates `primaryMuscleSlugsJoined` as a constructor argument before any stimulus row is created. `updateExisting()` does the same write at the very end, AFTER the stimulus row inserts. Both are correct, but the inconsistency makes a future reader wonder whether ordering matters (it doesn't here). Either pattern works; pick one and use it in both methods.

**Fix:** Move the `primaryMuscleSlugsJoined` assignment in `updateExisting()` to immediately after the other scalar field updates (around line 283), so both methods set the field in the same place relative to the inserts.

### IN-02: `Pattern`, `Force`, `Level` enums lack `static let default`; others have one

**File:** `fitbod/Models/Enums/Pattern.swift`, `Force.swift`, `Level.swift`
**Issue:** `Equipment / Mechanic / Intent / MuscleRegion / WeightUnit / ProgressionKind / BlockPhaseKind / SetType` all declare `public static let default`. `Pattern / Force / Level` do not. The reason — those three are stored as Optionals — is reasonable but inconsistent. `EnumTests.defaultsAreMembers` skips them silently.

**Fix:** Either add `default` constants for completeness or document the convention in a comment ("enums whose storage is Optional do not declare a `default`").

### IN-03: `SeedError.unexpectedMuscleSlug(String)` declared but never thrown

**File:** `fitbod/ExerciseLibrary/SeedError.swift:37`
**Issue:** The importer logs unknown muscle slugs at debug level (line 199, 211) but never throws this case. The unused enum case clutters the error surface.

**Fix:** Either thread it through (throw if some required muscle is missing) or remove the case.

### IN-04: Equipment display-name transform duplicated across 4 files

**File:** `ExerciseDetailView.swift:214-219`, `CustomExerciseEditor.swift:255-260`, `FilterPickerSheet.swift:194-198`, `ExerciseRow.swift:81-83`
**Issue:** All four sites independently re-implement `eq.rawValue.replacingOccurrences(of: "_", with: " ").capitalized`. Drift risk if the spec changes (e.g. "weighted_bodyweight" → "Body Weight (Weighted)").

**Fix:** Add an extension on `Equipment`:
```swift
extension Equipment {
    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
```
…and replace every call site.

### IN-05: `RootView.runSeed` failure not surfaced on first launch with empty store

**File:** `fitbod/App/RootView.swift:148-158`
**Issue:** When `seedIfNeeded()` throws, the splash dismisses (line 92's `case .failed: return false`) and the tab bar appears. Library tab is empty, no message. UI-SPEC § Error states defines an alert ("Library Failed to Load") but this is documented as deferred to Wave 4 polish.

Acceptable for v1 personal-install, but: if the seed has never run successfully, the user has zero feedback. At minimum log to `Logger.error` (which the file does) and let the developer see the diagnostic in Console.app.

**Fix:** No code change for v1. Track the deferred work item.

### IN-06: `RoutineExercise` lacks `#Index` declaration; spec only requires SessionExercise to be indexed on intentRaw

**File:** `fitbod/Models/RoutineExercise.swift`
**Issue:** No bug. Just noting that `intentRaw` queries on `RoutineExercise` (future routine-builder phase) will table-scan. Within CONTEXT.md scope so not a violation.

**Fix:** None for Phase 1. Add `#Index<RoutineExercise>([\.intentRaw])` when the routine-builder query lands in Phase 2.

### IN-07: `try? modelContext.save()` in editor save/delete flows

**File:** `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:289, 296`
**Issue:** Both `save()` and `deleteCustom()` discard the save error via `try?`. On the (unlikely) save failure, the sheet dismisses, the user thinks the action succeeded, and the next launch reveals the missing/extra row.

**Fix (low priority):** Show a non-blocking error banner. Or at minimum log:
```swift
do { try modelContext.save() } catch {
    Logger(subsystem: "com.fitbod.app", category: "ui").error("Save failed: \(error)")
}
dismiss()
```

### IN-08: `CustomExerciseDraft.updateExisting` and Copy-as-Custom hydration are not unit-tested

**Files:** `fitbod/ExerciseLibrary/CustomExerciseDraft.swift:273-309`, `fitbod/ExerciseLibrary/ExerciseDetailView.swift:241-260`
**Issue:** `CustomExerciseDraftTests` covers `isValid` exhaustively and `materialize` end-to-end, but not:
- The wholesale-replace logic in `updateExisting()` (delete old stimuli, insert new, rewrite `primaryMuscleSlugsJoined`).
- `ExerciseDetailView.makeDraft(from:)` — the hydration step that the "Copy as Custom Exercise" action depends on. This is currently a private function with no direct test surface.

**Fix:** Add two tests:
1. `updateExistingReplacesStimuli` — create an Exercise with stimulus rows, edit the draft to swap muscles, call `updateExisting`, assert old stimuli are deleted and new ones reflect the draft.
2. Either expose `makeDraft(from:)` as `internal` and test it directly, or test the integration path by hydrating a draft from a fixture Exercise and calling `materialize` on the result.

---

_Reviewed: 2026-05-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
