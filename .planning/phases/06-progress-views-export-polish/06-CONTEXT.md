# Phase 6: Progress Views, Export & Polish - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning (with dependency caveat below)
**Mode:** Auto-generated via `/gsd-discuss-phase 6 --auto` — recommended options selected from PROJECT.md, REQUIREMENTS.md, ROADMAP Phase 6 success criteria, and Phase 1/2/3 CONTEXT artifacts.

> **DEPENDENCY CAVEAT:** Phase 4 (Periodization & Blocks) is mid-planning and Phase 5 (Fatigue Model & Plateau Detection) is not yet started at the time of this discussion. Phase 6 success criterion #3 references "block phase" slicing for weekly tonnage; live PR detection at set save (PROG-08) overlays the Phase 2 `SessionLoggerView` that is now also overlaid by Phase 3 ("Why this weight?" disclosure, plate calculator) and Phase 5 (plateau stall flag, weekly recap). Researcher and planner MUST reconfirm `Block`/`BlockPhase` schema, plateau signal source, and weekly recap surface against the actual Phase 4 and Phase 5 outputs before writing plans. Decisions below are anchored on the schemas already defined in Phase 1 (`Block`, `BlockPhase` entities exist) and on Phase 2 history queries.

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & scope
- `.planning/PROJECT.md` — locked tech stack, charting decision, what NOT to use, state management, persistence stance (local-only, no CloudKit)
- `.planning/REQUIREMENTS.md` §PROG-01..05,07,08 + §EXP-01..04 — the 11 requirements this phase fulfills
- `.planning/ROADMAP.md` §"Phase 6: Progress Views, Export & Polish" — 5 must-be-true success criteria

### Prior-phase context (locked decisions)
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — entity catalog (`Block`, `BlockPhase`, `Session`, `SessionExercise`, `SetEntry`, `MuscleGroup`, `ExerciseMuscleStimulus`); SchemaV1 versioned schema pattern; `*Raw: String` enum persistence; `#Index` patterns
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` — `SessionFactory.start(...)` snapshot pattern (`SessionExercise.routine: Routine?` link is the matching key for session comparison); `PreviousMatchingIntent` query (intent-split history); `SetEntry.actualWeight/actualReps/actualRPE` are source-of-truth for all charts
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — `SetEntry.wasManualOverride: Bool` (informational badge in history); `Exercise.smallestIncrement` (plate-rounded weight in charts)
- `.planning/phases/04-periodization-blocks/` (when complete) — block phase schema for tonnage slicing; deload week boundaries
- `.planning/phases/05-fatigue-plateau/` (when complete) — plateau detector (`PROG-06`, owned by Phase 5 — Phase 6 charts overlay the stall flag); weekly recap surface owner

### e1RM formulas (PROG-02)
- Brzycki: `1RM = weight × 36 / (37 - reps)` — used when `reps ≤ 6`
- Epley:   `1RM = weight × (1 + reps / 30)` — used when `6 < reps ≤ 10`
- Suppressed entirely from PR detection AND from chart series when `reps > 10` (per ROADMAP success criterion #1). High-rep sets still appear in raw history and weekly-tonnage, but they do not feed e1RM trend lines or PR comparisons.

### Export formats
- CSV — RFC 4180, UTF-8, header row mandatory, ISO-8601 timestamps, weights in user's canonical unit + a `unit` column to make rows self-describing
- JSON — schema-versioned (`schemaVersion: "v2"` matching SchemaV2 + a `formatVersion: 1` for the export envelope), pretty-printed, NSCalendar-independent ISO-8601 dates
- Backup file — single `.fitbodbackup` document = ZIP container of (`store.json` full schema dump + `images/` directory of custom exercise images + `manifest.json` with schemaVersion + checksum)

### iOS APIs
- `Charts` (Swift Charts) — `LineMark`, `PointMark`, `BarMark`, `RuleMark` (PR thresholds), `AreaMark` (band fill), `chartXScale`, `chartYScale`
- `ShareLink` (iOS 16+) with `Transferable` conformance — `ShareLink(item: csvFile)` for CSV and JSON
- `UIDocumentPickerViewController` (wrapped in `UIViewControllerRepresentable`) or `.fileImporter(...)` for restore
- `FileManager` (`urls(for: .documentDirectory)`) for staging exports

</canonical_refs>

<domain>
## Phase Boundary

This phase delivers **the resolution at which serious lifters actually inspect their training** plus **data ownership**:

1. **Per-exercise progress charts** — Swift Charts time-series with intent-split (strength vs hypertrophy as distinct series on the same axes), top-set vs all-set-average e1RM as toggleable series, rep-range-aware e1RM (Brzycki ≤6, Epley 6–10, suppress >10 from PR detection and trend lines).
2. **PRs view** — per exercise: weight PR, rep PR, volume PR (set tonnage), e1RM PR — intent-matched (a strength PR compares only against strength sessions) and rep-range-aware (a 5RM PR doesn't compete with a 10RM PR).
3. **Live PR detection** — at set save, the session logger evaluates the just-completed working set against the per-exercise PR table and surfaces an in-session banner ("weight PR", "volume PR", "e1RM PR"). Stacks multiple PRs into one banner when the same set sets multiple records.
4. **Weekly tonnage chart** — total weight × reps per week, sliceable by week / block phase / muscle group. Block-phase slicing uses the existing `Block`/`BlockPhase` entities; muscle slicing uses Phase 5's stimulus-weighted aggregation (with a graceful fallback to raw set count if Phase 5 lands later than expected).
5. **Session comparison** — this week's session vs last week's "same routine" session, side-by-side per-exercise diff (weight Δ, reps Δ, e1RM Δ).
6. **CSV / JSON export** — full data export at one-row-per-set granularity (CSV) and full schema dump (JSON). Both shipped via `ShareLink`.
7. **Backup / restore** — `.fitbodbackup` document (ZIP of JSON + custom-exercise images + manifest) writable to and restorable from Files / iCloud Drive / AirDrop. Restore wipes-and-replaces with explicit data-loss confirmation.

In scope: PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-07, PROG-08, EXP-01, EXP-02, EXP-03, EXP-04 (11 requirements).
Out of scope: PROG-06 plateau detector (Phase 5 owns the signal — Phase 6 only renders the flag if Phase 5 lands first); VOL-01..07 weekly volume bars (Phase 5); weekly recap surface (Phase 5 success criterion #6); muscle heatmap (Phase 5); CloudKit sync (out of v1); cross-device transfer beyond the `.fitbodbackup` file (out of v1).

</domain>

<decisions>
## Implementation Decisions

### Area 1 — Progress navigation entry points

- **D-01:** Add a **new "Progress" tab** to `RootView`'s `TabView` (alongside Library, Routines, Sessions, Settings). The existing tab order becomes Sessions / Routines / Library / Progress / Settings. The Progress tab's root is a `ProgressHomeView` that lists per-exercise cards (sorted by most-recently-trained), a "Weekly Tonnage" entry, and a "PRs" entry. Reason: charts deserve a first-class destination; nesting them under ExerciseDetailView only is discoverable but does not surface cross-exercise views (weekly tonnage, all-PRs feed).
- **D-02:** Per-exercise chart also reachable from `ExerciseDetailView` ("View progress") AND from `ExerciseHistoryView` (Phase 2) — both deep-link into the same `ExerciseProgressView`. Reason: lifters often want to jump from a history list straight into the chart.
- **D-03:** Each Progress tab has its own `NavigationPath` per the PROJECT.md navigation rule (`TabView` not wrapped in a parent `NavigationStack`). Tap-to-pop-to-root on the active tab resets that tab's path.

### Area 2 — e1RM calculation and series

- **D-04:** **Formulas** — Brzycki `weight × 36 / (37 - reps)` for `reps ≤ 6`; Epley `weight × (1 + reps / 30)` for `6 < reps ≤ 10`; `>10 reps → nil` (suppressed from chart series, PR table, and PR detection). Pure function `OneRepMax.estimate(weight:reps:) -> Double?` returns nil for the suppression case so views can `.filter { $0 != nil }` and Swift Charts naturally drops missing points.
- **D-05:** **Top-set definition** — for each `SessionExercise`, the top set is the set with the highest e1RM among `setKind == .working` (NOT highest weight — this matters for high-volume hypertrophy sessions where a higher-rep set at lower weight produces a higher e1RM than a heavier single). Tiebreaker: the highest weight; second tiebreaker: latest set in the session.
- **D-06:** [informational — covered by D-04 OneRepMax kernel + D-07 series toggle] **All-set-average e1RM** — arithmetic mean of e1RM across all working sets in the session that have a non-nil e1RM. Sets with `reps > 10` are excluded from the average (consistent with suppression rule).
- **D-07:** **Chart series toggle** — `ExerciseProgressView` exposes two `Toggle` chips: `[Top set]` and `[All-set avg]`, both default ON. Strength sessions render as solid lines, hypertrophy sessions render as dashed lines on the SAME chart (intent-split via stroke style, not via separate charts). Color: top-set = accent `#0E7C86`, all-set-avg = accent `#3FBFC9` (Phase 1 design token reuse).
- **D-08:** [informational — axis spec implicit in UI-SPEC chart contract] **X-axis** — `Date` (session date), auto-scaled to the visible data range with `chartXScale(domain: .automatic)`. **Y-axis** — weight in canonical unit (kg internally, displayed per `UserSettings.unitSystem`).
- **D-09:** **Empty state** — when there are fewer than 2 sessions with non-nil e1RM for that exercise, show an empty-state card "Log 2 sessions to see your trend" instead of an empty chart.

### Area 3 — PRs view (per-exercise)

- **D-10:** **PR types tracked** — `weightPR` (max `actualWeight` for any single set), `repPR` (max `actualReps` at any given weight bucket — see D-11), `volumePR` (max set tonnage = `actualWeight × actualReps` for a single set), `e1RMPR` (max non-nil e1RM for a single set). All four computed per `(exercise, intent)` so a strength PR doesn't compete with a hypertrophy PR.
- **D-11:** **Rep-range bucketing** — for rep PRs, bucket reps by the same boundaries used for formula selection: `1–6` (strength), `7–10` (hypertrophy strict), `>10` (high-rep accessory; excluded from formal PR list but tracked as "best reps at weight X" lookup). For weight PRs, bucket by the same rep ranges so "weight PR for 5RM" and "weight PR for 8RM" are distinct.
- **D-12:** [informational — on-demand computation is the implementation strategy of 06-02 PRDetector + 06-07 seedPRTable; no separate PR entity] **PR storage** — computed on-demand from `SetEntry` history; NOT denormalized into a `PR` entity. Reason: SwiftData query on `(exercise, intent)` with the existing index from Phase 3 is fast at the scale of a personal app; denormalization adds a maintenance burden. If profiling later shows latency, planner can add a `cachedPRTable` blob on `Exercise`.
- **D-13:** **PRs view layout** — `ExercisePRsView` shows four rows (Weight, Reps, Volume, e1RM), each with intent toggle (Strength / Hypertrophy / All), and the top 3 PRs per bucket with `(weight × reps @ RPE, date)`. Tappable to jump to that session.

### Area 4 — Live PR detection (PROG-08)

- **D-14:** **Trigger** — when a working set is saved (commit of `SetEntry.actualWeight`/`actualReps`/`actualRPE`), `PRDetector.check(set:) -> Set<PRKind>` runs against the cached per-exercise per-intent PR table for that session. PR table is rebuilt at session start and held in `@Observable` session state (not re-queried per set).
- **D-15:** **Banner UX** — `InSessionPRBanner` is a single dismissable capsule at the top of `SessionLoggerView` that lists all PR kinds hit by the most-recently-saved set ("Weight PR · Volume PR · e1RM PR"). Auto-dismisses after 5s OR on next set save, whichever first. Subtle haptic (`UINotificationFeedbackGenerator.notificationOccurred(.success)`) on appearance. No exclamation points (matches Phase 2 voice).
- **D-16:** **Stacking rule** — multiple PRs in one set = one banner with multiple chips. Multiple PRs across consecutive sets = the next save replaces the prior banner (no banner queue, no stack of capsules).
- **D-17:** **Manual override interaction** — `wasManualOverride` does NOT suppress PR detection; an honest higher-weight set is a real PR regardless of whether the user typed it manually. The override badge appears in history (Phase 3 decision); the PR banner here is independent.

### Area 5 — Weekly tonnage chart (PROG-04)

- **D-18:** **Tonnage definition** — sum of `actualWeight × actualReps` over all working sets (`setKind == .working`) in the week. Warmups and drop sets excluded. Week boundary = ISO 8601 (Monday-start; configurable later via `UserSettings.weekStart` if a need surfaces).
- **D-19:** **Slicing UI** — three independent filter chip rows at the top of `WeeklyTonnageView`:
  - **Time range:** `[Last 8 wk]` `[Last 26 wk]` `[All time]` (single-select; default: Last 26 wk)
  - **Block phase:** chips per `BlockPhaseKind` enum case (`.accumulation`, `.intensification`, `.realization`, `.deload`) — multi-select; default: all selected. Disabled (greyed out with "no block data yet") until Phase 4 ships.
  - **Muscle group:** chips per top-10 trained muscles (sorted by historical volume); multi-select; default: none selected (= "all muscles, single bar per week"). Selecting muscles switches the chart to a stacked-bar view (one bar per week, segmented by selected muscle).
- **D-20:** **Muscle-stack source** — when Phase 5 ships, use stimulus-weighted aggregation (`ExerciseMuscleStimulus.weight`). Until Phase 5 lands, fall back to unweighted attribution (each exercise contributes its full set tonnage to every primary muscle, none to secondary). Planner: write the aggregation behind a `MuscleVolumeProvider` protocol so the Phase 5 implementation drops in without touching `WeeklyTonnageView`.
- **D-21:** **Chart type** — `BarMark` per week, X axis = week start date, Y axis = tonnage in canonical unit. `RuleMark` overlays for "previous best week" (subtle dashed line). Tap a bar to drill into a "week detail" view listing sessions in that week.

### Area 6 — Session comparison view (PROG-07)

- **D-22:** **Matching rule** — "same routine last week" = the most recent prior `Session` where `session.routine == currentSession.routine` AND `session.intent == currentSession.intent` AND `currentSession.startedAt - prior.startedAt < 14 days`. The 14-day window gives slack for users who train a routine roughly weekly but not exactly weekly. No match → empty-state "no comparable prior session".
- **D-23:** **Layout** — `SessionComparisonView` shows two columns side-by-side per exercise. Each row is one exercise, with this-week's top working set on the left and prior session's top working set on the right, plus the Δ (`+5 kg`, `+1 rep`, `+3 e1RM kg`) in the center. Sort: by exercise order in the routine.
- **D-24:** **Entry point** — accessible from the completed-session summary screen (existing Phase 2 surface) AND from the Progress tab → "This week vs last week" card.

### Area 7 — CSV export (EXP-01)

- **D-25:** **CSV shape** — one row per `SetEntry`. Columns (in order):
  `session_id, session_started_at, session_completed_at, session_intent, routine_id, routine_name, exercise_id, exercise_name, set_index, set_kind, target_weight, target_reps, target_rpe, actual_weight, actual_reps, actual_rpe, was_manual_override, partial_reps, tempo, rest_taken_sec, e1rm, set_note, unit`
- **D-26:** **Encoding & format** — RFC 4180, UTF-8 with BOM (so Excel opens it correctly), comma delimiter, fields-with-commas-or-newlines double-quoted, embedded double-quotes escaped as `""`. ISO-8601 dates in UTC (`2026-05-22T14:33:00Z`). Booleans as `true`/`false`. Empty optionals as empty string (NOT the literal word `nil`).
- **D-27:** **Surface** — settings → Data → "Export as CSV" → spawns `ShareLink(item:)` with a `Transferable` `CSVFile` value type that lazily renders the CSV on first read. Filename: `fitbod-export-{ISO-date}.csv`.

### Area 8 — JSON export (EXP-02)

- **D-28:** **JSON shape** — schema-versioned envelope:
  ```
  {
    "formatVersion": 1,
    "schemaVersion": "v2",
    "exportedAt": "2026-05-22T14:33:00Z",
    "unitSystem": "kg",
    "exercises": [...],          // full Exercise + ExerciseMuscleStimulus
    "routines": [...],           // Routines + RoutineExercises + overrides + folders
    "sessions": [...],           // Sessions + SessionExercises + SetEntries (nested)
    "blocks": [...],             // Block + BlockPhase
    "muscleGroups": [...],
    "muscleVolumeTargets": [...],
    "userSettings": {...}
  }
  ```
  Encoded via `JSONEncoder` with `.prettyPrinted` and `.sortedKeys` for diff-friendliness. `Codable` DTOs per entity (NOT the `@Model` classes directly — gives stable schema independent of SwiftData internals).
- **D-29:** **Surface** — settings → Data → "Export as JSON" → `ShareLink` with `Transferable` `JSONFile`. Filename: `fitbod-export-{ISO-date}.json`.

### Area 9 — Backup / restore (EXP-03, EXP-04)

- **D-30:** **Backup file format** — `.fitbodbackup` document = ZIP archive containing:
  - `manifest.json` — `{ "schemaVersion": "v2", "formatVersion": 1, "createdAt": "...", "checksum": "<sha256 of store.json>" }`
  - `store.json` — the same JSON shape as D-28
  - `images/` — directory of custom-exercise images keyed by `Exercise.id.uuidString + ".jpg"`
  Use Apple's `Compression` framework (or a tiny zip implementation) — no third-party dependency. UTI `com.<bundle-id>.fitbodbackup` declared in Info.plist with conformsTo `public.zip-archive`.
- **D-31:** **Backup surface** — settings → Data → "Create backup" → writes to `FileManager.urls(for: .documentDirectory)` then opens `ShareLink(item:)`. User chooses Files / iCloud Drive / AirDrop in the share sheet. No automatic background backups in v1.
- **D-32:** **Restore flow** —
  1. Settings → Data → "Restore from backup" → `.fileImporter(allowedContentTypes: [.fitbodBackup])`
  2. Read manifest, verify checksum, verify `schemaVersion` matches current SchemaV2 (mismatch → blocking alert "Backup is from a different schema version — restore not supported").
  3. **Explicit destructive-confirmation alert** — two-step: "This will replace all current data with the backup. This cannot be undone." → user types/holds-confirm → proceed.
  4. Backup current store to a side file (`store-pre-restore-{timestamp}.json`) in `.documentDirectory` so a botched restore is recoverable.
  5. Delete `ModelContainer`'s on-disk store, instantiate fresh container, decode JSON, insert all entities, save context, copy `images/` to the custom-exercise images directory, restart the app (or reload `ModelContext`).
- **D-33:** **Round-trip guarantee** — Phase 6 includes a Swift Testing suite (`BackupRoundTrip.test.swift`) that seeds a synthetic dataset, exports, wipes, restores, and asserts entity-by-entity equality. This is a must-pass acceptance test (ROADMAP success criterion #5).

### Area 10 — Polish scope (the "& Polish" in the phase name)

- **D-34:** [informational — empty-state copy is locked in 06-UI-SPEC §Copywriting and consumed by 06-05/06/07/08 view plans] **Empty states** — every new view (`ProgressHomeView`, `ExerciseProgressView`, `WeeklyTonnageView`, `ExercisePRsView`, `SessionComparisonView`) has a hand-written empty state with a single actionable prompt ("Log 2 sessions to see your trend", "Define a block to see phase slicing", etc.). No generic "No data" placeholders.
- **D-35:** **Haptics & motion** — PR banner uses `.success` notification haptic; chart series toggles use `.selectionChanged` haptic; all transitions ≤200ms; reduce-motion-aware (respect `@Environment(\.accessibilityReduceMotion)`).
- **D-36:** [informational — perf is implicit in 06-02's #Index addition + 06-05's outer/inner @Query split per PATTERNS] **Performance budget** — `ExerciseProgressView` must render in <300ms for an exercise with 1000 logged sets (well above realistic v1 scale). Achieved via: query-level `#Index` on `(exercise, performedAt DESC)`; lazy chart series construction; no in-memory filtering.
- **D-37:** [informational — explicit deferral declaration; nothing to implement] **Polish — out of scope for v1** — onboarding tutorial overlays, animated chart entry, themable color schemes beyond the existing accent. Deferred.

### Claude's Discretion

- Exact chart styling (line weight, point mark size, axis label density) — UI-SPEC for Phase 6 will lock these.
- Filter-chip row form factor (horizontal scroll vs wrapped) — UI-SPEC decision.
- Whether the Progress tab's home is a list, a grid, or a hybrid card layout — UI-SPEC.
- Banner copy variations ("Weight PR" vs "Weight PR · 5RM") — match Phase 2 voice.
- Whether `CSVFile` / `JSONFile` `Transferable` types live in `Export/` or alongside their producing services — planner organizational choice.
- Whether the per-exercise PR table is computed once per session (held in session state) or eagerly precomputed at `ProgressHomeView` load — planner profile-driven decision.
- ZIP implementation choice for `.fitbodbackup` — Apple Compression framework with a tiny zip header writer, OR `NSFileCoordinator + Archive` patterns — planner picks the simplest that satisfies UTI declaration.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1, 2, 3)

- `Exercise` entity — primary keying for all charts; `name`, `primaryMuscles`, `category`, `mechanic` are filter inputs. Phase 3 adds `smallestIncrement`, `barWeightOverride`, `unitOverride`.
- `Session` entity — `routine: Routine?`, `intent: SessionIntent`, `startedAt: Date`, `completedAt: Date?` — drive session-comparison matching (D-22) and weekly-tonnage bucketing (D-18).
- `SessionExercise` snapshots prescription per Phase 2. `setEntries` relationship is the source for top-set / all-set-avg computation.
- `SetEntry` — `actualWeight`, `actualReps`, `actualRPE`, `setKind: SetKind` (warmup/working/drop/failure/restPause), `performedAt: Date`, `partialReps: Int?`, `tempo: TempoSpec?`, `notes`, `restTakenSec: Int?`. Phase 3 adds `wasManualOverride: Bool`. THIS is the universal source-of-truth for every chart and export row.
- `PreviousMatchingIntent` query (Phase 2) — already returns the prior intent-matched `SetEntry` for a given `(exercise, intent)`. Reusable for live PR detection's seed-set lookup at session start.
- `Block`, `BlockPhase` entities exist (Phase 1 schema) — Phase 4 populates them. D-19 block-phase slicing reads these directly.
- `MuscleGroup`, `ExerciseMuscleStimulus` (Phase 1) — D-20 muscle-stack source.
- `UserSettings.unitSystem` (Phase 1) — single source of canonical unit for display.
- `SettingsView` (Phase 1, extended by Phase 3) — add the Data section (Export CSV, Export JSON, Create backup, Restore from backup).
- `RootView` `TabView` (Phase 1) — add the Progress tab.

### Established Patterns

- **Per-tab `NavigationStack`** never nested in a parent `NavigationStack`; each tab owns its own `NavigationPath`. The new Progress tab follows this verbatim.
- **`@Query` directly in views** — no MVVM wrappers around `@Query`. `ExerciseProgressView` reads `@Query var setEntries: [SetEntry]` filtered by exercise/intent via `Predicate<SetEntry>`.
- **`@Observable` for ephemeral state** — `PRDetectorState`, `ChartFilterState` are `@Observable` classes owned by the view with `@State`.
- **Enums persisted as `*Raw: String`** — new enums (`PRKind`, `TonnageSliceMode`) follow this rule if they need persistence; pure runtime enums don't need it.
- **`#Index` on hot paths** — `#Index([\SetEntry.exercise, \SetEntry.performedAt])` and `#Index([\Session.startedAt])` MUST exist before chart queries hit them at scale. Confirm in planner.
- **`SchemaV1: VersionedSchema` + empty `SchemaMigrationPlan`** — Phase 3 adds SchemaV2 fields; Phase 6 adds no new persistent fields (PR table is computed; export DTOs are non-persistent Codable structs). No new schema version needed.
- **Atomic per-plan commits** — keep the file count per plan tight.
- **Swift Testing for math** — `OneRepMax`, `PRDetector`, `WeeklyTonnageAggregator`, `SessionComparator`, export encoders are all pure functions and testable in isolation.
- **`.serialized` trait** for any test that touches `UserSettings` / `UserDefaults`.

### Integration Points

- `SessionLoggerView` (Phase 2 + Phase 3 overlays) — adds `InSessionPRBanner` (D-14, D-15) at the top of the working-set list. Phase 3 already adds the "Why this weight?" affordance and plate calculator disclosure; Phase 6 banner sits above those. UI-SPEC for Phase 6 must show how the banner coexists with Phase 3's affordances.
- `ExerciseDetailView` (Phase 1) — add "View progress" navigation row (D-02).
- `ExerciseHistoryView` (Phase 2) — add "View progress" affordance (D-02).
- `RootView.TabView` (Phase 1) — add Progress tab (D-01).
- `SettingsView` (Phase 1) — add Data section (D-27, D-29, D-31, D-32).
- `SessionFactory.start(...)` (Phase 2 + Phase 3) — additionally seeds the per-exercise PR table into session-state so the in-session detector doesn't query SwiftData on every set save (D-14).
- `Sessions/CompletedSessionView` (Phase 2) — add "Compare to last week" row (D-24).

</code_context>

<specifics>
## Specific Ideas

- Charts use the existing Phase 1/2 accent palette — `#0E7C86` (top-set / primary series), `#3FBFC9` (all-set-avg / secondary series). Hypertrophy series uses `.lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))`; strength series uses `.lineStyle(StrokeStyle(lineWidth: 2))`. No new colors.
- PR banner copy is direct and second-person, no exclamation points: "Weight PR · 102.5 kg × 5" — single line, no "Congrats!", no emoji.
- "Why this weight?" disclosure (Phase 3) and the PR banner (Phase 6) must not visually compete — banner sits in a dedicated top slot, disclosure sits inline per row.
- CSV export filename is dated, not user-named — `fitbod-export-2026-05-22.csv`. Reduces decision fatigue.
- Backup restore flow always writes a side file of the current store before destructive overwrite — the user can manually recover if a restore is regretted (no automated rollback UI in v1, but the file is there).
- Empty state copy is actionable, not apologetic — "Log 2 sessions to see your trend" not "No data yet".
- ISO-8601 in UTC for ALL export timestamps. The user's local timezone is irrelevant for data ownership; UTC makes the file self-describing.

</specifics>

<deferred>
## Deferred Ideas

- **Automated/scheduled backups** — auto-write a backup to iCloud Drive on a schedule. v2.
- **Cross-device transfer beyond `.fitbodbackup`** — CloudKit sync is explicitly out-of-scope per PROJECT.md. Backup file is the v1 transfer mechanism.
- **Per-muscle PR records** — "best e1RM contribution to chest from a single set" — interesting but adds storage with low payoff. v2.
- **Velocity-based progress** — no VBT hardware in v1 per PROJECT.md. v2+.
- **Animated chart entry / scrubber overlay** — visual polish that doesn't change information density. Defer until usage shows a need.
- **Body-silhouette muscle heatmap** — Phase 5 owns the per-muscle volume model and the heatmap (PROJECT.md "Charting Decision" table says heatmap uses SwiftUI `Canvas`, not Swift Charts). Phase 6 does not draw it.
- **Weekly recap auto-surface** — Phase 5 owns the recap composition. Phase 6 may link to it from Progress tab, but does not own the surface.
- **Plateau-stall flag on exercise cards** — Phase 5 owns the signal (PROG-06). Phase 6 ProgressHomeView will read the signal if it exists, but does not compute it.
- **Custom export presets (date-ranged, exercise-filtered)** — v1 ships all-data exports only. v2 can add filtered exports.
- **PR confetti / celebratory animation** — match the project voice: direct, no exclamation points. No confetti.
- **Backwards-compatible schema migration on restore** — v1 restore requires exact schema-version match. Once the schema starts versioning past v2 in production, planner adds a migration layer keyed off `manifest.schemaVersion`. Not in this phase.

</deferred>

---

*Phase: 6-Progress Views, Export & Polish*
*Context gathered: 2026-05-22*
