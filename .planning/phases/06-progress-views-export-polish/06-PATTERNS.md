# Phase 6: Progress Views, Export & Polish — Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 28 new / 8 modified
**Analogs found:** 35 / 36 (all but the AppleArchive backup writer have direct in-repo analogs)

## Module Location Convention (extracted from existing tree)

The repo organizes code by **functional surface**, not by architectural layer. Each surface owns its math, views, sheets, and helpers in a single flat folder. Phase 6 must mirror this:

```
fitbod/
├── App/                  # RootView, fitbodApp, SeedState, PlaceholderTabView
├── ExerciseLibrary/      # Library list, detail, history, DTOs, importer, filters
├── Models/               # @Model entities + Enums/ subfolder for *Raw string enums
├── Persistence/          # SchemaV1, SchemaV2, FitbodSchemaMigrationPlan, PreviewModelContainer
├── Routines/             # Routine builder, drafts, rows, defaults
├── Sessions/             # SessionLoggerView, SessionFactory, PreviousMatchingIntent,
│   └── RestTimer/        #   ← single nested subfolder anywhere in the repo
└── Settings/             # SettingsView (single file)
```

**Phase 6 additions (matching the established convention):**

```
fitbod/
├── Progress/             # NEW — all chart surfaces + math kernels live here as siblings,
│                         #   matching how Sessions/ holds SessionLoggerView + SessionFactory + PreviousMatchingIntent
│                         #   side by side. Do NOT create Progress/Math/ or Progress/Views/ sub-folders.
├── Export/               # NEW — CSV/JSON encoders + Transferable wrappers + DTOs
├── Backup/               # NEW — AppleArchive writer/reader + manifest + UTType decl
└── Sessions/
    └── InSessionPRBanner.swift  # NEW — banner overlay lives in Sessions/ since it mounts
                                  #   on SessionLoggerView (matches PreviousColumn.swift placement)
```

Rationale (from observed conventions): `PreviousMatchingIntent.swift` (pure query) lives next to `SessionLoggerView.swift` (view) in `Sessions/` — not in a sibling `Sessions/Queries/` folder. `PrescriptionDefaults.swift` (pure function) lives in `Routines/` next to `RoutineBuilderView.swift`. **Apply the same flat-by-surface rule to Progress/.**

## File Classification

### Math kernels (Wave 1) — pure value types

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `Progress/OneRepMax.swift` | pure-function enum | pure | `Routines/PrescriptionDefaults.swift` | exact (pure-function enum, file-doc-block format identical) |
| `Progress/PRDetector.swift` | pure function over set | pure | `Routines/PrescriptionDefaults.swift` + `Sessions/PreviousMatchingIntent.swift` (hybrid) | exact |
| `Progress/WeeklyTonnageAggregator.swift` | pure aggregation | pure | `Routines/PrescriptionDefaults.swift` | role-match |
| `Progress/SessionComparator.swift` | pure match + diff over `[Session]` + `[SessionExercise]` | pure (in-memory) + one fetch | `Sessions/PreviousMatchingIntent.swift` | exact (same Sendable hit-struct + enum-namespace + UUID local-let workaround pattern) |
| `Progress/MuscleVolumeProvider.swift` | protocol + default impl | pure | (no prior protocol abstraction in repo) | NO ANALOG — use RESEARCH §"Architectural Responsibility Map" |
| `Models/Enums/PRKind.swift` | enum | persistent? No — runtime only | `Models/Enums/Intent.swift` | exact |
| `Models/Enums/TonnageSliceMode.swift` | enum | runtime only | `Models/Enums/Intent.swift` | exact |
| `Models/Enums/SeriesKind.swift` | enum (RESEARCH-only addition; not in CONTEXT explicitly) | runtime only | `Models/Enums/Intent.swift` | exact |

### Views (Waves 2 & 3) — SwiftUI surfaces

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `Progress/ProgressHomeView.swift` | tab-root list view | `@Query` direct | `ExerciseLibrary/ExerciseLibraryView.swift` + `Sessions/ResumeWorkoutBanner.swift` | exact (NavigationStack + `@Query` + sectioned list pattern) |
| `Progress/ExerciseProgressView.swift` | chart view with `@Query` + filter state | `@Query` direct, transform inline | `ExerciseLibrary/ExerciseHistoryView.swift` (outer/inner split pattern) | exact |
| `Progress/ExercisePRsView.swift` | sectioned list view | `@Query` + pure-function compute | `ExerciseLibrary/ExerciseHistoryView.swift` | exact |
| `Progress/WeeklyTonnageView.swift` | chart view with chip rows | `@Query` + aggregator | `ExerciseLibrary/ExerciseLibraryView.swift` (chip rows + outer/inner) | exact |
| `Progress/SessionComparisonView.swift` | side-by-side diff view | `@Query` + `SessionComparator` | `ExerciseLibrary/ExerciseHistoryView.swift` | role-match |
| `Progress/WeekDetailView.swift` | drill-in list (UI-SPEC adds this — not in CONTEXT) | `@Query` filtered by date range | `ExerciseLibrary/ExerciseHistoryView.swift` | role-match |
| `Progress/WeeklyTonnageFilterChips.swift` | reusable chip row (single + multi-select variants) | `@Binding<Set>` / `@Binding<Single>` | `ExerciseLibrary/FilterChip.swift` + `ExerciseLibrary/ExerciseFilterBar.swift` | exact |
| `Progress/ProgressColors.swift` | static color constants | static | (no prior constants file — match Phase 1 style of inline `Color(hex:)` literals) | role-match |
| `Progress/ChartFilterState.swift` | `@Observable` ephemeral state | mutated by view | (no in-repo `@Observable` yet — `FilterState` in `ExerciseLibrary/` is the closest non-`@Observable` analog) | role-match |
| `Progress/InSessionPRState.swift` | `@Observable` session-scoped PR state | seed at session start, mutate on save | (no in-repo `@Observable` yet) | role-match |
| `Sessions/InSessionPRBanner.swift` | banner view, `.safeAreaInset` mount | `@Bindable` state | `Sessions/ResumeWorkoutBanner.swift` | exact |

### Export pipeline (Wave 3)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `Export/CSVExporter.swift` | static RFC-4180 encoder | pure | `Routines/PrescriptionDefaults.swift` | role-match (pure-function enum pattern) |
| `Export/JSONExporter.swift` | static JSON envelope encoder | pure | `Routines/PrescriptionDefaults.swift` + `ExerciseLibrary/ExerciseLibraryImporter.swift` (JSONDecoder usage) | role-match |
| `Export/ExportDTOs.swift` (or split per-entity) | Codable value types | DTO | `ExerciseLibrary/ExerciseDTO.swift` | exact |
| `Export/CSVFile.swift` | `Transferable` wrapper | one-shot value | (no Transferable yet in repo) | NO ANALOG — use RESEARCH Pattern 4 |
| `Export/JSONFile.swift` | `Transferable` wrapper | one-shot value | (no Transferable yet in repo) | NO ANALOG — use RESEARCH Pattern 4 |
| `Export/ExportService.swift` | off-main coordinator | actor / `Task.detached` | `ExerciseLibrary/ExerciseLibraryImporter.swift` (`@ModelActor`) | role-match |
| `Settings/DataSettingsSection.swift` (split out of `SettingsView`) | view section | composed into `Form` | `Settings/SettingsView.swift` `unitsSection(...)` | exact |

### Backup pipeline (Wave 4)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `Backup/BackupArchiver.swift` (or `BackupWriter.swift`) | actor — composes manifest + store.json + images, archives via AppleArchive | actor + filesystem | `ExerciseLibrary/ExerciseLibraryImporter.swift` (`@ModelActor` pattern) | role-match |
| `Backup/BackupRestorer.swift` (or `BackupReader.swift`) | actor — verify + decode + repopulate ModelContainer | actor + filesystem | `ExerciseLibrary/ExerciseLibraryImporter.swift` (idempotent seed pattern; rollback semantics) | role-match |
| `Backup/BackupManifest.swift` | Codable DTO | Codable | `ExerciseLibrary/ExerciseDTO.swift` | exact |
| `Backup/FitbodBackupFile.swift` | `Transferable` wrapper | one-shot value | (no Transferable yet) | NO ANALOG — use RESEARCH Pattern 4 |
| `Backup/UTType+FitbodBackup.swift` | UTType extension declaration | static | (no UTType extension yet) | NO ANALOG — RESEARCH §Pitfall 9 |

### Tests (each wave)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `fitbodTests/Phase6/OneRepMaxTests.swift` | pure-function unit tests | Swift Testing `@Test` | `fitbodTests/PrescriptionDefaultsTests.swift` | exact (file-doc-block + suite + parameterized `@Test`) |
| `fitbodTests/Phase6/PRDetectorTests.swift` | pure-function tests | Swift Testing | `fitbodTests/PrescriptionDefaultsTests.swift` | exact |
| `fitbodTests/Phase6/WeeklyTonnageAggregatorTests.swift` | pure-function tests | Swift Testing | `fitbodTests/PrescriptionDefaultsTests.swift` | exact |
| `fitbodTests/Phase6/SessionComparatorTests.swift` | pure + SwiftData in-mem | Swift Testing `.serialized` + `InMemoryContainer` | `fitbodTests/PreviousMatchingIntentTests.swift` | exact |
| `fitbodTests/Phase6/CSVExporterTests.swift` | golden-snapshot encoder test | Swift Testing | `fitbodTests/DTODecodingTests.swift` | role-match |
| `fitbodTests/Phase6/JSONExporterTests.swift` | golden-snapshot encoder test | Swift Testing | `fitbodTests/DTODecodingTests.swift` | role-match |
| `fitbodTests/Phase6/BackupRoundTripTests.swift` | round-trip integration test (D-33 MUST-PASS) | Swift Testing `.serialized` + `InMemoryContainer` | `fitbodTests/SeedTests.swift` | exact (`.serialized` for process-wide side effects; idempotency pattern) |
| `fitbodTests/Phase6/Fixtures/SessionFixtures.swift` | test fixture builder | helper | `fitbodTests/PreviousMatchingIntentTests.swift` `makeCompletedSession(...)` | exact |
| `fitbodTests/Phase6/Fixtures/PRFixtures.swift` | test fixture builder | helper | `fitbodTests/PreviousMatchingIntentTests.swift` | exact |

### Modifications to existing files

| Existing File | Modification | Closest Pattern In-File |
|---------------|--------------|-------------------------|
| `App/RootView.swift` | Replace `PlaceholderTabView(phaseNumber: 6)` with real `ProgressHomeView`; add `progressPath` `@State` + Re-tap reset case in `tabSelection` setter | Inline pattern at lines 60–66 (`libraryPath`) + lines 132–150 (`tabSelection` Binding) |
| `Settings/SettingsView.swift` | Add Data section below About section; embed via `DataSettingsSection(settings:)` private view-builder OR composed sub-section | Inline pattern at lines 85–106 (`unitsSection(...)`) |
| `Sessions/SessionLoggerView.swift` | Mount `InSessionPRBanner` via `.safeAreaInset(edge: .top, spacing: 0)`; add `@State private var prState = InSessionPRState()` | Existing `@State` block at lines 76–93; banner mount style matches `ResumeWorkoutBanner` usage in `RootView` `TodayView` |
| `Sessions/SessionFactory.swift` | Add a second pass after planned-set creation that seeds `InSessionPRState.prTable` (per RESEARCH Pitfall 6 — one batched fetch + partition) — or expose a static `seedPRTable(for: session, context:)` helper | The existing `PreviousMatchingIntent.fetchTopWorkingSet(...)` call at lines 143–147 is the direct analog for "fetch + partition at session start" |
| `ExerciseLibrary/ExerciseDetailView.swift` | Add "View progress" `NavigationLink` row conditional on `@Query` for `SetEntry` count > 0 | Existing "Copy as Custom" CTA pattern (read the trailing-toolbar-button comment block at the top of the file) |
| `ExerciseLibrary/ExerciseHistoryView.swift` | Add `chart.line.uptrend.xyaxis` toolbar action that pushes `ExerciseProgressView(exercise:)` | Existing `.toolbar { ToolbarItem(.principal) { ... } }` block at lines 98–107 |
| `Persistence/SchemaV2.swift` | NOTE: planner-adjudicated. Per CONTEXT D-12 + RESEARCH §Summary, no new persistent fields. The proposed `#Index([\SetEntry.completedAt])` is non-persistent metadata — can be added without a SchemaV3 bump. Decide: (a) add the index to the existing `SetEntry.swift` `@Model` body (where `Session` already declares `#Index<Session>([\.startedAt], [\.sourceRoutineID])` at line 29), or (b) defer if planner decides table-scan at v1 scale is acceptable. **Do NOT bump versionIdentifier — additive `#Index` is metadata-only.** | `Models/Session.swift` line 29 (`#Index<Session>([\.startedAt], [\.sourceRoutineID])`) |

---

## Pattern Assignments

### `Progress/OneRepMax.swift` (math kernel, pure function)

**Analog:** `Routines/PrescriptionDefaults.swift`

**File-header doc-block pattern** (PrescriptionDefaults.swift lines 1–24, copy verbatim shape):

```swift
//
//  OneRepMax.swift
//  fitbod
//
//  Wave-1 plan 06-PLAN-XX — the rep-range-aware e1RM estimator
//  (PROG-02 + CONTEXT D-04). Single canonical kernel called by:
//
//    1. ExerciseProgressView — to compute the LineMark series points.
//    2. PRDetector — to compute the e1RM PR bucket per set.
//    3. ExercisePRsView — to compute the e1RM column.
//
//  Formulas per CONTEXT D-04:
//    - reps == 1 → weight (identity; Epley over-estimates here per
//      RESEARCH Pitfall 4)
//    - 2 ≤ reps ≤ 6 → Brzycki: weight × 36 / (37 - reps)
//    - 7 ≤ reps ≤ 10 → Epley:  weight × (1 + reps / 30)
//    - reps > 10 OR reps ≤ 0 OR weight ≤ 0 → nil
//
//  Pure value-type logic — no `ModelContainer`, no SwiftData. Pulled
//  into its own file so the heuristic is testable in isolation
//  (`OneRepMaxTests`).
//
```

**Enum body pattern** (PrescriptionDefaults.swift lines 27–57):

```swift
import Foundation

public enum OneRepMax {

    /// e1RM estimate per CONTEXT D-04. Returns nil for reps > 10 or
    /// reps <= 0 or non-positive weight (bodyweight-assist; RESEARCH
    /// Pitfall 5), so callers can `.compactMap` cleanly.
    public static func estimate(weight: Double, reps: Int) -> Double? {
        guard reps > 0, weight > 0 else { return nil }
        switch reps {
        case 1:
            return weight
        case 2...6:
            return weight * 36.0 / (37.0 - Double(reps))
        case 7...10:
            return weight * (1.0 + Double(reps) / 30.0)
        default:
            return nil
        }
    }
}
```

**Reuse verbatim:** Doc-block format, `public enum X { public static func ... }` namespace pattern, `Foundation`-only import, `// MARK:` headers if logic grows.
**Adapt:** Body is from RESEARCH §"OneRepMax (verified math)" lines 549–565.

---

### `Progress/PRDetector.swift` (math kernel, pure)

**Analog:** `Sessions/PreviousMatchingIntent.swift` (hit-struct + enum-namespace pattern) + `Routines/PrescriptionDefaults.swift` (pure-function enum)

**Sendable hit-struct pattern** (PreviousMatchingIntent.swift lines 30–42):

```swift
/// One PR record for a single (exerciseID, intentRaw, kind, bucket) tuple.
public struct PRRecord: Sendable, Equatable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let setEntryID: UUID
    public let sessionStartedAt: Date

    public init(weight: Double, reps: Int, rpe: Double?, setEntryID: UUID, sessionStartedAt: Date) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.setEntryID = setEntryID
        self.sessionStartedAt = sessionStartedAt
    }
}
```

**Enum-namespace pattern** (PreviousMatchingIntent.swift line 44, PrescriptionDefaults.swift line 27):

```swift
public enum PRDetector {
    /// Compute the PR delta for a single set against the in-memory PR table.
    /// Returns the set of PR kinds (possibly empty) that this set newly tops.
    public static func check(set: SetEntry, against table: PRTable) -> Set<PRKind> { ... }

    /// Build the per-(exercise, intent) PR table from a flat array of
    /// committed working sets. Caller invokes this once at session start
    /// (RESEARCH Pitfall 6 — one fetch + in-memory partition).
    public static func buildTable(from sets: [SetEntry]) -> PRTable { ... }
}
```

**Reuse verbatim:** `public enum X` namespace, `public struct Y: Sendable` hit type, init-with-named-args pattern.
**Adapt:** `PRTable` is a new value type — model after a `[ExerciseID: [PRKind: [RepBucket: PRRecord]]]` dictionary; planner decides exact shape.

---

### `Progress/SessionComparator.swift` (pure + one fetch)

**Analog:** `Sessions/PreviousMatchingIntent.swift` — this is the canonical "find the prior matching session and return a typed hit" pattern.

**Critical pattern — UUID local-let workaround for SwiftData related-entity predicate** (PreviousMatchingIntent.swift lines 73–86):

```swift
// RESEARCH §6 Pitfall 1 — extract to locals BEFORE the #Predicate.
// Comparing `se.exercise?.id == exerciseID` directly inside the
// predicate triggers a known SwiftData footgun on iOS 17/18 where
// the related-entity-ID compare silently returns empty results.
let targetID = exerciseID
let targetIntent = intentRaw

var descriptor = FetchDescriptor<SessionExercise>(
    predicate: #Predicate { se in
        se.intentRaw == targetIntent && se.exercise?.id == targetID
    },
    sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
)
descriptor.fetchLimit = 5
```

**Reuse verbatim:** The exact 4-line "extract to locals BEFORE #Predicate" comment and pattern. Phase 6 RESEARCH §"D-22 correction" explicitly requires this workaround on `sourceRoutineID` and `intentRaw` lookups.
**Adapt for D-22 matching rule:** `currentSession.sourceRoutineID == priorSession.sourceRoutineID` AND `currentSession.exercises[i].intentRaw == prior.exercises[i].intentRaw` AND `dateDifference < 14 days`. Note: per RESEARCH §Schema reality, the match is on the **per-exercise** `(sourceRoutineID, exerciseID, intentRaw)` triple, not the top-level `session.routine` (which is the soft `sourceRoutineID: UUID?` field per `Session.swift` line 35).

---

### `Progress/ExerciseProgressView.swift` (chart view)

**Analog:** `ExerciseLibrary/ExerciseHistoryView.swift` — the outer/inner view split where the outer view owns filter state and the inner view owns the `@Query` whose predicate is keyed off that state.

**Outer/inner split pattern** (ExerciseHistoryView.swift lines 71–120):

```swift
public struct ExerciseProgressView: View {
    public let exercise: Exercise

    /// Ephemeral chip state — both default ON per CONTEXT D-07.
    @State private var showTopSet: Bool = true
    @State private var showAllAvg: Bool = true

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Chip row owns toggle state via @Binding
            SeriesToggleChipRow(showTopSet: $showTopSet, showAllAvg: $showAllAvg)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            // Inner view owns @Query keyed on the exercise's UUID. The
            // predicate does NOT change across toggle flips — the toggle
            // filters the post-fetch array, NOT the query (RESEARCH
            // Pitfall 2 — keep predicate as tight as possible to the
            // exercise UUID; let post-fetch filtering handle visual state).
            ProgressChartHost(
                exerciseID: exercise.id,
                showTopSet: showTopSet,
                showAllAvg: showAllAvg
            )
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressChartHost: View {
    @Query private var sets: [SetEntry]
    let showTopSet: Bool
    let showAllAvg: Bool

    init(exerciseID: UUID, showTopSet: Bool, showAllAvg: Bool) {
        // RESEARCH §6 Pitfall 1 — local-let UUID before #Predicate.
        let targetID = exerciseID
        _sets = Query(
            filter: #Predicate<SetEntry> { entry in
                entry.isComplete && !entry.isWarmup
                    && entry.sessionExercise?.exercise?.id == targetID
            },
            sort: \.completedAt,
            order: .forward
        )
        self.showTopSet = showTopSet
        self.showAllAvg = showAllAvg
    }

    var body: some View {
        // Transform sets → [E1RMSeriesPoint] inline via pure helpers,
        // then feed Chart(series) { ... }. See RESEARCH Pattern 1.
    }
}
```

**Reuse verbatim:** The outer/inner split, `init(...)` constructing `_sets = Query(...)`, UUID local-let workaround.
**Adapt:** Chart body from RESEARCH §"Pattern 1: Intent-split chart" lines 198–238.

---

### `Sessions/InSessionPRBanner.swift` (overlay banner)

**Analog:** `Sessions/ResumeWorkoutBanner.swift` — the established "banner mounted at the top of a session-related surface, conditionally rendered, with `EmptyView()` when empty" pattern.

**Conditional banner body pattern** (ResumeWorkoutBanner.swift lines 73–115):

```swift
public struct InSessionPRBanner: View {
    @Bindable public var state: InSessionPRState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: InSessionPRState) {
        self.state = state
    }

    public var body: some View {
        if let banner = state.currentBanner {
            bannerBody(banner: banner)
                .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity))
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerBody(banner: InSessionPRBannerContent) -> some View {
        HStack(spacing: 4) {
            ForEach(banner.kinds.indices, id: \.self) { i in
                if i > 0 {
                    Text("·").foregroundStyle(.secondary)
                }
                Text(banner.kinds[i].headlineLabel)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Text("\(banner.weight, specifier: "%g") kg × \(banner.reps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(Color.accentColor.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .onTapGesture { state.dismiss() }
    }
}
```

**Reuse verbatim:** `if let active = ...; else EmptyView()` shape, `HStack { ... } .padding(16) .background(...) .clipShape(...) .padding(.horizontal, 16)` envelope, `Button("Resume") { ... }.foregroundStyle(Color.accentColor)` accent treatment.
**Adapt:** Mount via `.safeAreaInset(edge: .top, spacing: 0)` on `SessionLoggerView` per RESEARCH Pattern 3 (NOT inside a `List` like `ResumeWorkoutBanner`).
**Critical:** ResumeWorkoutBanner is mounted INSIDE a `List` with `.listRowInsets(EdgeInsets())` / `.listRowBackground(Color.clear)`. **InSessionPRBanner must NOT be mounted that way** — it goes in `.safeAreaInset(edge: .top)` per the research pitfall about layout-shift on set save.

---

### `Progress/WeeklyTonnageFilterChips.swift` (reusable chip row)

**Analog:** `ExerciseLibrary/FilterChip.swift` — the single-chip primitive — plus `ExerciseLibrary/ExerciseFilterBar.swift` for the horizontal-scroll row composition.

**Single chip pattern** (FilterChip.swift lines 41–76, copy verbatim):

```swift
public struct FilterChip: View {
    let label: String
    let accessibilityName: String
    let isActive: Bool
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color(.systemGray5))
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityName)
    }
}
```

**Reuse verbatim:** The entire `FilterChip` view — Phase 6 should depend on it directly, not duplicate it. UI-SPEC §Color item 24 explicitly says Phase 6 chips match Phase 3 chip styling.
**Adapt:** Wrap multiple `FilterChip`s in a `ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ... } }` per UI-SPEC §Spacing line "horizontal scroll, NOT wrap." The `WeeklyTonnageFilterChips` view takes a `@Binding<Set<ID>>` (multi-select) or `@Binding<ID>` (single-select) generic parameter.

> **NOTE — slight visual delta with UI-SPEC:** the existing `FilterChip` uses `Color.white` for active foreground, but UI-SPEC §Color item 24 calls for `Color.accentColor` foreground on a `Color.accentColor.opacity(0.15)` background for series-toggle chips. The Phase 6 chip is therefore **visually distinct** from the library `FilterChip`. Planner: either (a) create a new `ProgressFilterChip` with the accent-tinted style, OR (b) parameterize `FilterChip` with a `style:` enum. Recommend (a) — keep the library chip stable and add a new sibling.

---

### `Export/ExportDTOs.swift` (Codable value types)

**Analog:** `ExerciseLibrary/ExerciseDTO.swift` — the canonical "plain Codable struct decoupled from `@Model`" pattern.

**Pattern** (ExerciseDTO.swift lines 1–72):

```swift
//
//  ExportDTOs.swift
//  fitbod
//
//  Plain Codable value types for the JSON / .fitbodbackup export envelope
//  (EXP-02 + EXP-03 + CONTEXT D-28). NOT `@Model` (PITFALLS #2: keep
//  Codable off SwiftData entity types). The Phase 6 ExportService reads
//  every entity from the ModelContainer and writes [ExportExerciseDTO],
//  [ExportSessionDTO], etc., to give the export shape stability that's
//  independent of SwiftData internals.
//
//  NOTE on name collision: ExerciseLibrary/ExerciseDTO.swift already
//  defines `ExerciseDTO` (the free-exercise-db seed shape). The export
//  DTOs are prefixed `Export*DTO` to avoid the collision.
//

import Foundation

public struct ExportExerciseDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let externalID: String?
    public let isCustom: Bool
    public let equipmentRaw: String
    public let mechanicRaw: String
    public let primaryMuscles: [String]
    public let secondaryMuscles: [String]
    // ... etc.
}

public struct ExportSessionDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date?
    public let routineSnapshotName: String
    public let sourceRoutineID: UUID?
    public let exercises: [ExportSessionExerciseDTO]
    // ... etc.
}

// ... and so on for every @Model entity in SchemaV2.
```

**Reuse verbatim:** File-doc-block style, `public struct X: Codable, Equatable, Sendable` declaration, single explicit `public init(...)` with named args (omitted above for brevity, but ExerciseDTO.swift lines 47–72 is the template).
**Adapt:** Cover every entity in `Persistence/SchemaV2.swift` lines 39–58 (15 entities total).
**Critical name-collision per RESEARCH §"DTO name collision":** Do NOT name `ExerciseDTO` — already exists at `ExerciseLibrary/ExerciseDTO.swift`. Use `ExportExerciseDTO` prefix uniformly.

---

### `Export/ExportService.swift` (off-main coordinator)

**Analog:** `ExerciseLibrary/ExerciseLibraryImporter.swift` — the established `@ModelActor` pattern for off-main-thread heavy work.

**Pattern** (ExerciseLibraryImporter.swift lines 58–60, 78, 120–293):

```swift
//
//  ExportService.swift
//  fitbod
//
//  Wave-3 plan 06-PLAN-XX — the off-main coordinator that reads every
//  @Model entity from the container, builds [ExportExerciseDTO] / etc.,
//  encodes via JSONEncoder (D-28) or RFC4180 (CSVExporter), and returns
//  a Data blob for ShareLink's Transferable wrapper.
//
//  Authored as a @ModelActor so the work runs off the main thread
//  (matching ExerciseLibraryImporter pattern from plan 02-02).
//

import Foundation
import OSLog
import SwiftData

@ModelActor
public actor ExportService {

    private static let log = Logger(subsystem: "com.fitbod.app", category: "export")

    public func renderCSV() async throws -> Data { ... }
    public func renderJSON() async throws -> Data { ... }
    public func snapshotForBackup() async throws -> ExportDocument { ... }
}
```

**Reuse verbatim:** `@ModelActor` macro, `Logger(subsystem: "com.fitbod.app", category: ...)` (use a new category like `"export"` or `"backup"`), `public func ... async throws` method shape.
**Adapt:** The importer is one-way write; ExportService is one-way read. The pattern (off-main + structured-concurrency context) is identical.

---

### `Backup/BackupArchiver.swift` (no in-repo analog for AppleArchive)

**Closest analog:** `ExerciseLibrary/ExerciseLibraryImporter.swift` for the `@ModelActor` + idempotency + rollback patterns.

**Use RESEARCH §"Pattern 5: Backup `.fitbodbackup` (AppleArchive)"** lines 354–386 verbatim for the AppleArchive byte-stream construction.

**Critical existing patterns to copy from ExerciseLibraryImporter.swift:**

- Lines 95–112: idempotent entry-point doc-block — "1. Reads X. 2. If Y, returns immediately. 3. Otherwise wipes partial state. 4. Stamps the version stamp. 5. On mid-import failure rolls back."
- Line 78: `private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")` — copy with `category: "backup"`.
- Lines 282–292: the `catch { modelContext.rollback(); throw error }` mid-import failure pattern. Restore is destructive, so the side-file insurance per CONTEXT D-32 step 4 is the equivalent of this rollback.

---

### `Settings/DataSettingsSection.swift` (Settings extension)

**Analog:** `Settings/SettingsView.swift` `unitsSection(...)` (lines 85–106)

**Section composition pattern** (SettingsView.swift lines 62–106):

```swift
extension SettingsView {
    @ViewBuilder
    func dataSection(settings: UserSettings) -> some View {
        Section {
            // Row 1: Export as CSV — wraps ShareLink(item:) per RESEARCH Pattern 4
            if let csvFile = csvFile {
                ShareLink(item: csvFile, preview: SharePreview(csvFile.filename)) {
                    Text("Export as CSV")
                }
            } else {
                Button("Export as CSV") {
                    Task { await prepareCSVExport() }
                }
            }
            // Row 2: Export as JSON
            // ...
            // Row 3: Create backup
            // ...
            // Row 4: Restore from backup (destructive — Color.systemRed label per UI-SPEC item 28)
            Button(role: .destructive) {
                showingImporter = true
            } label: {
                Text("Restore from backup")
                    .foregroundStyle(Color(.systemRed))
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Exports include every set you've logged. Backups can be shared via Files, iCloud Drive, or AirDrop.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.fitbodBackup],
            allowsMultipleSelection: false,
            onCompletion: handleRestoreFileImport
        )
    }
}
```

**Reuse verbatim:** `Section { ... } header: { Text(...) } footer: { Text(...).font(.caption).foregroundStyle(.secondary) }` shape — exact match to existing `unitsSection`. Recommend keeping `dataSection(...)` as a private `@ViewBuilder func` on `SettingsView` rather than a standalone file (the existing `unitsSection` is inline on `SettingsView`). **Alternative:** if the section grows past ~60 lines, split into a private nested struct `DataSettingsSection: View` per planner discretion — matches `ExerciseHistoryView`'s `FilteredHistoryList` inner-view convention.

---

### `App/RootView.swift` modification

**Pattern in-place:** RootView.swift already declares `case progress` in the `Tab` enum (line 81) — the work is to replace the placeholder body (line 187–191) with the real Progress tab host.

**Current placeholder** (lines 187–191):

```swift
PlaceholderTabView(phaseNumber: 6)
    .tabItem {
        Label("Progress", systemImage: "chart.xyaxis.line")
    }
    .tag(Tab.progress)
```

**Replacement pattern** (model after lines 181–185 LibraryTabHost wiring):

```swift
ProgressTabHost(path: $progressPath)
    .tabItem {
        Label("Progress", systemImage: "chart.line.uptrend.xyaxis")  // UI-SPEC tab icon
    }
    .tag(Tab.progress)
```

And in the `tabSelection` setter (lines 132–150), update the switch to handle `.progress` path-clear (matching how `.library` is handled at lines 138–141):

```swift
case .progress:
    progressPath = NavigationPath()
```

Plus add `@State private var progressPath = NavigationPath()` next to `libraryPath` at line 66, and a private `struct ProgressTabHost: View { @Binding var path: NavigationPath; var body: some View { ProgressHomeView(path: $path) } }` next to `LibraryTabHost` at line 282.

**UI-SPEC discrepancy (resolve in planner):** UI-SPEC line 137 says `chart.line.uptrend.xyaxis`; RootView.swift line 189 currently uses `chart.xyaxis.line`. Per UI-SPEC (downstream), use `chart.line.uptrend.xyaxis`.

---

### `fitbodTests/Phase6/OneRepMaxTests.swift` (unit test)

**Analog:** `fitbodTests/PrescriptionDefaultsTests.swift` — the canonical pure-function Swift Testing pattern.

**File-doc + suite + test pattern** (PrescriptionDefaultsTests.swift lines 1–24, then 22–104):

```swift
//
//  OneRepMaxTests.swift
//  fitbodTests
//
//  Boundary coverage for `OneRepMax.estimate(weight:reps:)`
//  (PROG-02 + CONTEXT D-04 + RESEARCH Pitfalls 4+5).
//
//    1. identityAtOneRep — reps == 1 returns weight verbatim
//    2. brzyckiRange — reps 2..6 use Brzycki formula
//    3. epleyRange — reps 7..10 use Epley formula
//    4. suppressesHighRep — reps > 10 returns nil
//    5. nilOnNonPositiveInputs — weight ≤ 0 or reps ≤ 0 returns nil
//    6. handlesNegativeWeight — bodyweight-assist (Pitfall 5) returns nil
//

import Foundation
import Testing
@testable import fitbod

@Suite("OneRepMax (PROG-02 + CONTEXT D-04)")
struct OneRepMaxTests {

    @Test("identityAtOneRep — reps == 1 returns weight verbatim")
    func identityAtOneRep() {
        #expect(OneRepMax.estimate(weight: 100, reps: 1) == 100)
        #expect(OneRepMax.estimate(weight: 60.5, reps: 1) == 60.5)
    }

    @Test("brzyckiRange — reps 2..6 use Brzycki", arguments: [
        (100.0, 5, 112.5),    // 100 * 36 / 32
        (60.0,  3, 63.529),   // ~
        (80.0,  6, 92.903),   // 80 * 36 / 31
    ] as [(Double, Int, Double)])
    func brzyckiRange(weight: Double, reps: Int, expected: Double) {
        let actual = try #require(OneRepMax.estimate(weight: weight, reps: reps))
        #expect(abs(actual - expected) < 0.1)
    }

    // ... etc.
}
```

**Reuse verbatim:** `@Suite("Name (REQ + CONTEXT-decision-id)")` naming, `@Test("test-name — short description")` format, `#expect(...)` over `XCTAssert`, parameterized `arguments:` form, `try #require(...)` for unwrap-or-fail.
**Adapt:** The test ID + decision-anchor pattern from PrescriptionDefaultsTests.swift line 23 (`"PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1)"`).

---

### `fitbodTests/Phase6/BackupRoundTripTests.swift` (MUST-PASS acceptance per D-33)

**Analog:** `fitbodTests/SeedTests.swift` + `fitbodTests/PreviousMatchingIntentTests.swift`

**`.serialized` pattern** (SeedTests.swift lines 33–55):

```swift
//
//  BackupRoundTripTests.swift
//  fitbodTests
//
//  D-33 MUST-PASS acceptance — export → wipe → import yields entity-
//  by-entity equality across SchemaV2's 15 @Model types.
//
//  .serialized because BackupWriter writes to documentDirectory and
//  ModelContainer reset is process-wide.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BackupRoundTrip (D-33 acceptance)", .serialized)
struct BackupRoundTripTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
    }

    @Test("roundTrip — every entity round-trips with field equality")
    func roundTrip() async throws {
        let containerA = try makeInMemoryContainer()
        // 1. Seed fixture (use SessionFixtures.seed(into:))
        // 2. Archive
        // 3. Fresh container
        // 4. Restore
        // 5. Compare DTOs
    }
}
```

**Reuse verbatim:** `.serialized` trait, `@MainActor @Suite`, the `makeInMemoryContainer()` helper (matches `PreviousMatchingIntentTests.swift` lines 34–43 + `InMemoryContainer.makeEmpty()` pattern).
**Adapt:** Pattern from RESEARCH lines 608–641 (the full `BackupRoundTripTests` skeleton).

---

### `fitbodTests/Phase6/Fixtures/SessionFixtures.swift`

**Analog:** `fitbodTests/PreviousMatchingIntentTests.swift` `makeCompletedSession(...)` helper (lines 48–83)

**Fixture helper pattern** (PreviousMatchingIntentTests.swift lines 46–83):

```swift
enum SessionFixtures {
    /// Create a completed Session with one SessionExercise and N SetEntries.
    @discardableResult
    static func makeCompletedSession(
        ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        intentRaw: String,
        sets: [(weight: Double, reps: Int, rpe: Double?, isWarmup: Bool, isComplete: Bool)]
    ) throws -> Session {
        let session = Session()
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(60 * 45)
        session.routineSnapshotName = "Test"
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.intentRaw = intentRaw
        se.targetSets = sets.count
        ctx.insert(se)

        for (i, tup) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = tup.weight
            entry.reps = tup.reps
            entry.rpe = tup.rpe
            entry.isWarmup = tup.isWarmup
            entry.isComplete = tup.isComplete
            entry.completedAt = startedAt
            ctx.insert(entry)
        }
        try ctx.save()
        return session
    }
}
```

**Reuse verbatim:** The entire helper, lifted into an `enum SessionFixtures` namespace so it's reusable across PRDetectorTests, SessionComparatorTests, BackupRoundTripTests, and WeeklyTonnageAggregatorTests.

---

## Shared Patterns (cross-cutting)

### Pattern A — `*Raw: String` enum persistence

**Source:** `Models/SessionExercise.swift` lines 41, 49 + `Models/SetEntry.swift` line 37 + `Models/Enums/Intent.swift`
**Apply to:** `Models/Enums/PRKind.swift`, `Models/Enums/TonnageSliceMode.swift`, `Models/Enums/SeriesKind.swift`

```swift
public enum PRKind: String, CaseIterable, Sendable {
    case weight
    case reps
    case volume
    case e1RM = "e1rm"  // lowercase rawValue for diff-friendly storage
}
```

**Critical:** Per RESEARCH §Schema-reality, these enums are **runtime-only** (not persisted to `@Model` fields). They drive UI rendering and PR-table dictionary keys. No `*Raw: String` field is needed on any `@Model`. Still adopt `String` raw values + `CaseIterable + Sendable` per FOUND-03 / PITFALLS #9 convention so future persistence is trivial.

### Pattern B — `#Index` declaration on `@Model`

**Source:** `Models/Session.swift` line 29 (`#Index<Session>([\.startedAt], [\.sourceRoutineID])`) + `Models/SessionExercise.swift` line 34 (`#Index<SessionExercise>([\.intentRaw])`)
**Apply to:** `Models/SetEntry.swift` — add `#Index<SetEntry>([\.completedAt])` after line 25.

```swift
@Model
public final class SetEntry {
    #Index<SetEntry>([\.completedAt])  // NEW — supports per-exercise time-series query (RESEARCH §Pitfall 6)
    @Attribute(.unique) public var id: UUID = UUID()
    // ... rest unchanged
}
```

**Reason:** Per CONTEXT §"Established Patterns" line 195 — `#Index` is non-persistent metadata. **No SchemaV3 bump required.**

### Pattern C — SwiftData related-entity-ID predicate workaround

**Source:** `Sessions/PreviousMatchingIntent.swift` lines 73–86
**Apply to:** Every `@Query`/`FetchDescriptor` that traverses an optional `@Relationship` to compare a UUID. In Phase 6 that means:

- `Progress/ExerciseProgressView.swift` (filter `SetEntry` by `sessionExercise.exercise.id`)
- `Progress/ExercisePRsView.swift` (same)
- `Progress/SessionComparator.swift` (filter `Session` by `sourceRoutineID` — direct comparison; but per-`SessionExercise` matching needs the workaround)
- `Progress/PRDetector.swift` (PR-table-build query)
- `Backup/BackupRestorer.swift` (entity-by-entity comparisons during round-trip test)

```swift
// At every predicate construction site:
let targetID = exerciseID
let targetIntent = intentRaw

var descriptor = FetchDescriptor<SetEntry>(
    predicate: #Predicate { entry in
        entry.sessionExercise?.exercise?.id == targetID
            && entry.sessionExercise?.intentRaw == targetIntent
    },
    sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
)
```

### Pattern D — `@Query` in inner view, filter state in outer view

**Source:** `ExerciseLibrary/ExerciseHistoryView.swift` lines 71–120 (outer `ExerciseHistoryView` + private inner `FilteredHistoryList`) and `ExerciseLibrary/ExerciseLibraryView.swift` (outer / inner pattern documented in file-header doc-block lines 18–35)
**Apply to:** `ExerciseProgressView`, `ExercisePRsView`, `WeeklyTonnageView`, `SessionComparisonView`

```swift
public struct ExerciseProgressView: View {
    @State private var showTopSet = true
    @State private var showAllAvg = true

    public var body: some View {
        VStack {
            SeriesToggleChipRow(...)
            ProgressChartHost(exerciseID: exercise.id, showTopSet: showTopSet, ...)
        }
    }
}

private struct ProgressChartHost: View {
    @Query private var sets: [SetEntry]

    init(exerciseID: UUID, showTopSet: Bool, ...) {
        let targetID = exerciseID
        _sets = Query(filter: #Predicate { $0.sessionExercise?.exercise?.id == targetID }, ...)
    }

    var body: some View { /* Chart(sets) { ... } */ }
}
```

**Reuse verbatim:** The outer-owns-`@State` / inner-owns-`@Query` split, the inner-view `init(...)` that constructs the `Query` from outer state, and the UUID local-let workaround in the inner `init`.

### Pattern E — Foundation-only test fixtures

**Source:** `fitbodTests/PreviousMatchingIntentTests.swift` lines 34–43 (`makeContext()`) + `fitbodTests/TestSupport/InMemoryContainer.swift`
**Apply to:** All Phase 6 tests that need a ModelContainer

```swift
import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor @Suite("Name", .serialized)  // .serialized for UserDefaults / process-wide effects
struct MyTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
```

### Pattern F — File-doc-block format

**Source:** Every Swift file in the repo (sampled across `Routines/PrescriptionDefaults.swift`, `Sessions/PreviousMatchingIntent.swift`, `Sessions/SessionFactory.swift`, `ExerciseLibrary/ExerciseLibraryImporter.swift`)
**Apply to:** Every new Phase 6 file

```swift
//
//  FileName.swift
//  fitbod                       // or "fitbodTests" for test files
//
//  Wave-N plan 06-PLAN-XX — one-line summary of what this file delivers
//  (REQ-IDs like PROG-02 + CONTEXT.md Area N or D-XX anchors).
//
//  ## Section heading (when file > 80 lines)
//
//  Multi-paragraph context — what calls this, what it calls, what
//  invariants it enforces, what pitfalls it dodges. Reference RESEARCH
//  pitfalls and patterns by section anchor.
//
//  ## Why X and not Y
//
//  Document the design tradeoff inline.
//
```

The repo has zero exceptions to this convention. Every Phase 6 file MUST start with the same shape.

### Pattern G — `OSLog` subsystem for service classes

**Source:** `ExerciseLibrary/ExerciseLibraryImporter.swift` line 78 + `App/RootView.swift` line 68 + `Sessions/SessionLoggerView.swift` (used in `engine` integration)
**Apply to:** `Export/ExportService.swift`, `Backup/BackupArchiver.swift`, `Backup/BackupRestorer.swift`

```swift
import OSLog

private static let log = Logger(subsystem: "com.fitbod.app", category: "export")  // or "backup"
```

**Subsystem is always `"com.fitbod.app"`.** Category is per-service.

---

## No Analog Found

Files with no direct in-repo match — planner uses RESEARCH.md patterns instead:

| File | Role | Reason | Use Pattern From |
|------|------|--------|------------------|
| `Backup/BackupArchiver.swift` | AppleArchive byte-stream writer | No existing AppleArchive code | RESEARCH §"Pattern 5" lines 350–386 |
| `Backup/BackupRestorer.swift` | AppleArchive byte-stream reader + ModelContainer reset | No existing reset code | RESEARCH §"Pattern 6" lines 392–411 + §"Pitfall 10" |
| `Backup/UTType+FitbodBackup.swift` | UTType + Info.plist UTExportedTypeDeclarations | No custom UTI yet | RESEARCH §"Pitfall 9" |
| `Export/CSVFile.swift` | `Transferable` `DataRepresentation` | No prior Transferable | RESEARCH §"Pattern 4" lines 322–348 |
| `Export/JSONFile.swift` | `Transferable` `DataRepresentation` | Same | Same |
| `Backup/FitbodBackupFile.swift` | `Transferable` `FileRepresentation` | Same | RESEARCH §"Pattern 4" + §"Pattern 5" |
| `Progress/MuscleVolumeProvider.swift` | Protocol-based DI for Phase 5 dependency | No protocols in repo yet | RESEARCH §"Architectural Responsibility Map" + §"Recommended Project Structure" |
| `Progress/ChartFilterState.swift` + `Progress/InSessionPRState.swift` | `@Observable` classes | No `@Observable` classes exist yet — repo currently uses `@State` value types and `@Bindable` on `@Model` rows | PROJECT.md §"State Management" + RESEARCH §"Architectural Responsibility Map" PR-table row |
| Restore-flow `exit(0)` after `.alert` | App restart on restore completion | No prior restart flow | RESEARCH §"Pitfall 10" |

---

## Metadata

**Analog search scope:** `fitbod/`, `fitbodTests/`, with explicit reads of:
- `Models/SetEntry.swift`, `Models/Session.swift`, `Models/SessionExercise.swift`, `Models/Block.swift`, `Models/Enums/Intent.swift`, `Models/Enums/Equipment.swift`
- `Persistence/SchemaV2.swift`
- `Sessions/SessionFactory.swift`, `Sessions/PreviousMatchingIntent.swift`, `Sessions/SessionLoggerView.swift`, `Sessions/ResumeWorkoutBanner.swift`
- `Routines/PrescriptionDefaults.swift`
- `ExerciseLibrary/ExerciseDTO.swift`, `ExerciseLibrary/ExerciseLibraryImporter.swift`, `ExerciseLibrary/ExerciseLibraryView.swift`, `ExerciseLibrary/ExerciseHistoryView.swift`, `ExerciseLibrary/ExerciseDetailView.swift`, `ExerciseLibrary/FilterChip.swift`
- `App/RootView.swift`
- `Settings/SettingsView.swift`
- `fitbodTests/PrescriptionDefaultsTests.swift`, `fitbodTests/PreviousMatchingIntentTests.swift`, `fitbodTests/SeedTests.swift`, `fitbodTests/TestSupport/InMemoryContainer.swift`

**Files scanned:** ~80 Swift files across `fitbod/` and `fitbodTests/`
**Pattern extraction date:** 2026-05-22
