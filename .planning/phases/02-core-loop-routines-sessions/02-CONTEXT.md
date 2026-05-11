# Phase 2: Core Loop (Routines + Sessions) - Context

**Gathered:** 2026-05-11
**Status:** Ready for planning
**Mode:** Auto-generated via `/gsd-autonomous` smart-discuss (recommended options auto-selected based on PROJECT.md, REQUIREMENTS.md, CONTEXT/UI-SPEC of Phase 1, and the research dossier in `.planning/research/`)

<canonical_refs>
## Canonical References

MANDATORY reads for researcher and planner:
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` (this phase covers ROUTINE-01..09 + SESS-01..11 — 20 requirements)
- `.planning/research/SUMMARY.md` (top-leverage decisions; especially the snapshot pattern)
- `.planning/research/ARCHITECTURE.md` (Routine/RoutineExercise vs Session/SessionExercise entity split; `SessionFactory.start(...)` snapshot)
- `.planning/research/FEATURES.md` (routine builder UX details; rest timer behavior; intent-split history)
- `.planning/research/PITFALLS.md` (#1 template/instance — verified mitigated in Phase 1; #4 rest timer accuracy is the load-bearing pitfall for THIS phase)
- `.planning/ROADMAP.md` (Phase 2 success criteria — 6 must-be-true items)
- `.planning/phases/01-foundation-exercise-library/01-UI-SPEC.md` (carry-forward design tokens: accent color, 8pt spacing, typography, copywriting style)
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` (Phase 1 decisions; the `ExerciseLibraryView` is reusable as an embedded picker per its Specifics section)
- `.planning/phases/01-foundation-exercise-library/*-SUMMARY.md` (what exists already — RootView with TabView, Session/SessionExercise/SetEntry entities, etc.)
</canonical_refs>

<domain>
## Phase Boundary

This phase delivers the **minimum lovable product** — the user can build a routine end-to-end and log a workout against it:

1. **Routine builder** — single-screen builder with inline exercise search (reusing Phase 1's `ExerciseLibraryView` as an embedded picker), drag-handle reorder, per-exercise prescription (intent / target rep range / target RPE / progression kind / rest), supersets and giant sets, per-set prescription overrides, folders + duplication
2. **Session lifecycle** — `SessionFactory.start(routine:on:)` snapshots prescription fields from `RoutineExercise` to `SessionExercise` (and per-set targets to new `SetEntry` rows pre-populated as "planned"), so subsequent routine edits never alter logged sessions
3. **Session logger UI** — per-set inputs (weight, reps, decimal RPE, set type, per-set notes, optional 4-field tempo, partial reps, cluster sub-reps); inline "previous" column showing prior matching-intent set; mid-session swap/add exercises; workout-level + pinned per-exercise notes
4. **Rest timer** — `Date`-based, auto-starts on set completion, ±15s buttons, locked-screen `UNUserNotification`, Live Activity / Dynamic Island while running, auto-stops on next set entry
5. **Per-exercise history with intent split** — list view (no charts yet — charts land Phase 6); strength and hypertrophy series shown as distinct streams, filtered by `intent`

In scope: ROUTINE-01..09 + SESS-01..11 (20 requirements).
Out of scope: smart prescription / progression (Phase 3), warm-up generation (Phase 3), periodization blocks (Phase 4), volume/fatigue (Phase 5), charts (Phase 6).
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Routine builder UX

- **Single-screen layout**: `RoutineBuilderView` is a SwiftUI form-style screen with a top-of-list sticky search/add bar. No modal exercise picker — typing in the search bar surfaces exercises inline (reusing the existing `ExerciseLibraryView` rendered in a child mode with an `onSelect: (Exercise) -> Void` closure).
- **Drag-handle reorder**: use SwiftUI's `EditMode` + `.onMove` with always-visible drag handles on the right of each row.
- **Per-exercise prescription**: each row expands inline to a prescription editor (intent picker chip; target rep range two-field "min – max"; target RPE range two-field; progression kind picker; default rest seconds; per-set overrides count + sub-rows).
- **Supersets and giant sets**: model as `SupersetGroup` entity (NEW — not in Phase 1 schema). Add `RoutineExercise.supersetGroupID: UUID?` weak ref. Visual grouping: shared left accent rail per UI-SPEC convention (4pt-wide bar in accent color).
- **Folders**: add `RoutineFolder` entity (NEW). Routines list groups by folder. Single-level folders only (no nesting in v1).
- **Routine duplication**: action menu item "Duplicate" creates a deep copy of `Routine` + all `RoutineExercise` + per-set overrides; user gets the copy as "{Name} (Copy)" in the same folder.
- **Defaults heuristic**: when an exercise is added, prescription defaults from the exercise's `mechanic` (compound → rest 180s, isolation → rest 90s) and `equipment` (barbell+compound → strength intent default; otherwise hypertrophy).

### Area 2 — Session snapshot pattern (load-bearing)

- **`SessionFactory.start(routine:on:context:) -> Session`** lives in `fitbod/Sessions/` (NEW directory). It performs a deep copy: for each `RoutineExercise` in the routine, it creates a `SessionExercise` with all prescription fields snapshotted (intent, target reps, target RPE, progression kind, rest seconds), then creates the planned `SetEntry` rows pre-populated with target weight (from last-logged matching-intent session if available, else from the routine's prescription) — but with `actualWeight: nil` / `actualReps: nil` / `actualRPE: nil` until the user logs them.
- **Weak link back to source routine**: `Session.sourceRoutineID: UUID?` stored as a UUID (not a SwiftData relationship — that would cascade unexpectedly). The link is for UI ("Today's routine: Push Day A") and intent-split history filtering. Deleting the source routine doesn't affect logged sessions.
- **Editing the routine after a session starts**: the session is immutable from the routine's perspective. User edits to the routine alter the routine only. Tested in Phase 1's `CascadeRuleTests`, re-verified in this phase's snapshot tests.
- **Resuming a session**: a `Session` with `endedAt == nil` is "active". On app launch, if such a session exists, surface it on the Today tab as "Resume workout: {Name}". Only one active session at a time.

### Area 3 — Session logger UI

- **Layout**: top header with workout title (from snapshotted routine name) + elapsed timer + rest timer overlay. Body is a vertical list of exercises; each exercise expands to show prescribed + actual columns.
- **Per-set row**: weight | reps | RPE | set-type chip | notes button. Tappable RPE: row of 5 chips (RPE 6/7/8/9/10) with long-press for decimal RPE (8.5). Decimal RPE entry pattern: long-press opens a small picker wheel for tenths.
- **Inline "Previous" column**: positioned between prescribed and actual columns. Shows weight × reps × RPE from the most recent **matching-intent** logged set for this exercise. Query uses Phase 1's `Exercise.primaryMuscleSlugsJoined` indexed field plus the new `SessionExercise.intentRaw` index for performance.
- **Auto-populate**: when user taps weight or reps cell on an empty row, prefill with previous-matching-intent values. User taps confirm to keep, or types to override.
- **Set type chip**: tap cycles through `working` → `warmup` → `drop` → `failure` → `restPause` → `working`. Long-press opens menu for direct choice.
- **Tempo entry**: optional row beneath set inputs, 4 small numeric fields "ecc / bot / con / top" with a "+" toggle to show/hide globally per exercise.
- **Partial reps**: optional second rep field labeled "partial" — small font, only renders if user enables for the exercise.
- **Cluster / rest-pause**: sub-rep array for rest-pause set type. UI: tap to add a sub-rep, each sub-rep is a small chip showing rep count.
- **Mid-session swap**: long-press exercise → "Swap exercise…" → opens `ExerciseLibraryView` picker → replaces this `SessionExercise` with a new one targeting the chosen exercise. Original prescription fields copied where applicable (intent, rep range), weight reset to prior-matching-intent value if any.
- **Add unplanned exercise**: "+" button at bottom of session → picker → appends to the session (not the routine template).

### Area 4 — Rest timer (load-bearing pitfall mitigation)

- **`Date`-based, not foreground `Timer`**: `RestTimerEngine` stores `startedAt: Date` + `targetSeconds: Int`. The UI computes remaining = `targetSeconds - Date.now.timeIntervalSince(startedAt)`. No background `Timer` to drift.
- **Auto-start**: completing a set (tapping the row's checkmark) triggers `RestTimerEngine.start(seconds: prescribedRestForCurrentExercise)`.
- **±15s buttons**: mutate `targetSeconds`. The persisted `Date` doesn't move.
- **Lock-screen notification**: when timer starts, schedule a `UNUserNotificationCenter` local notification for `startedAt + targetSeconds`. When user adjusts ±15s, reschedule. When timer is canceled (next set entered), cancel pending notifications.
- **Live Activity / Dynamic Island**: implemented via `ActivityKit`. The activity content is the rest seconds remaining + exercise name. New entitlement file: `fitbod.entitlements` with `com.apple.developer.activitykit` capability. Info.plist key `NSSupportsLiveActivities: YES`.
- **Auto-stop on next set entry**: when user taps the next set's weight field (or marks the next set complete), stop timer + cancel any pending notification.
- **Notification permission**: request on first session start (not at app launch — minimize permission prompt friction).

### Area 5 — Intent-split history view

- **Entry point**: tap an exercise in the library → detail view (Phase 1) → new "History" tab → list of all logged sets across all sessions, grouped by date.
- **Intent split**: top-of-history filter chip group: "All / Strength / Hypertrophy / Power / Endurance / Technique". Default = "All". Tapping a chip filters the list.
- **Row format**: date — workout name (small) — weight × reps @ RPE — intent chip in accent color.
- **Empty state**: "No logged sets yet for this exercise."
- **Query optimization**: backed by `SessionExercise.exercise == X && SessionExercise.intentRaw == Y` predicate against the indexed fields from Phase 1.

### Area 6 — Folders for routines

- **`RoutineFolder` entity** (NEW): `id`, `name`, `sortOrder: Int`, `createdAt`
- **`Routine.folderID: UUID?`** weak ref (no SwiftData relationship — keeps folder deletion from cascading routines; deleting a folder moves routines to "Unfiled")
- **Routines tab UI**: sectioned list grouped by folder; default folder is "Unfiled"; user creates folders via "+ Folder" action; folders reorderable

### Claude's Discretion

- Exact rest timer Live Activity layout — visual decision deferred to UI-SPEC for this phase
- Specific drag-handle iconography — use SF Symbols `line.3.horizontal`
- Cluster set sub-rep array UI style — small horizontal chips beneath the main set row, tap to add
- Notification permission UX timing — first session start (not app launch)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 1)

- `ExerciseLibraryView` — supports embedded mode via `onSelect:` closure (Phase 1's `init(path:)` overload can be adapted)
- All 12 `@Model` entities exist; Session/SessionExercise/SetEntry already have snapshot fields
- `UserSettings` for global settings
- `PreviewModelContainer.make()` for previews
- `FilterState` pattern for `@Observable` ephemeral state (NOT to be used for SwiftData mirroring)
- UI-SPEC tokens: accent `#0E7C86`/`#3FBFC9`, 4/8/12/16/24/32/48pt spacing, semantic typography
- Test conventions: Swift Testing for units, `.serialized` trait for `UserDefaults`-touching suites

### Established Patterns

- MV-VM-lite (no parallel ViewModel wrapping `@Query`)
- `@Observable` for ephemeral UI state, never for SwiftData mirroring
- Enums persisted as `*Raw: String`
- `#Index` on hot query paths
- `@ModelActor` reserved for bulk ops only (none needed in this phase)
- `Date`-based timers, never foreground `Timer`
- Verbatim UI-SPEC copywriting
- Atomic per-plan commits

### Integration Points

- `RootView.swift` (Phase 1) — has placeholder Today/Routines tabs that this phase fills
- `Session.sourceRoutineID` already exists on the entity
- `SessionExercise.intentRaw` is indexed; intent-split history relies on this

</code_context>

<specifics>
## Specific Ideas

- Session logger should support **landscape orientation** for users who prefer a wider layout — defer if time-pressed, but the spacing scale already supports it.
- Tempo entry should be **opt-in per exercise** — don't clutter the UI for users who don't track tempo for every lift. Setting lives on `RoutineExercise.tracksTempo: Bool`.
- "Previous" column copy from Hevy is gold: show `"175 × 8 @ 8 (last Mon)"` — date hint helps the user judge currency.
- Lock-screen Live Activity should show: exercise name + rest seconds remaining + a tiny progress bar. Tapping opens the session.
- Routine builder should support **batch operations** later (multi-select, copy-set-across-exercises) — defer to v1.x, but keep the model open to it.
- When the user pulls down to refresh in the session logger, nothing happens (no pull-to-refresh) — intentional, list is reactive.

</specifics>

<deferred>
## Deferred Ideas

- **Charts** in per-exercise history — Phase 6
- **Recommended weight prescription** during session — Phase 3 (this phase displays previous values, not progression suggestions)
- **Warm-up sets generation** — Phase 3
- **Block periodization** — Phase 4
- **Volume / fatigue tracking** — Phase 5
- **Per-set landscape layout polish** — Phase 6 polish
- **Routine sharing / export individual routine as JSON** — Phase 6 export feature
- **Apple Watch session logger** — v2 (out of scope per PROJECT.md)

</deferred>
