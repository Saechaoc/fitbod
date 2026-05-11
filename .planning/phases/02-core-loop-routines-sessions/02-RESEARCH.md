# Phase 2: Core Loop (Routines + Sessions) - Research

**Researched:** 2026-05-11
**Domain:** iOS 18+ SwiftUI + SwiftData routine builder + session logger with ActivityKit Live Activity rest timer
**Confidence:** HIGH on Apple APIs (Context7-equivalent web verification + Apple docs), HIGH on Phase 1 codebase composition (file-level inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — Routine builder UX**
- **Single-screen layout**: `RoutineBuilderView` is a SwiftUI form-style screen with a top-of-list sticky search/add bar. No modal exercise picker — typing in the search bar surfaces exercises inline (reusing the existing `ExerciseLibraryView` rendered in a child mode with an `onSelect: (Exercise) -> Void` closure).
- **Drag-handle reorder**: use SwiftUI's `EditMode` + `.onMove` with always-visible drag handles on the right of each row.
- **Per-exercise prescription**: each row expands inline to a prescription editor (intent picker chip; target rep range two-field "min – max"; target RPE range two-field; progression kind picker; default rest seconds; per-set overrides count + sub-rows).
- **Supersets and giant sets**: model as `SupersetGroup` entity (NEW — not in Phase 1 schema). Add `RoutineExercise.supersetGroupID: UUID?` weak ref. Visual grouping: shared left accent rail per UI-SPEC convention (4pt-wide bar in accent color).
- **Folders**: add `RoutineFolder` entity (NEW). Routines list groups by folder. Single-level folders only (no nesting in v1).
- **Routine duplication**: action menu item "Duplicate" creates a deep copy of `Routine` + all `RoutineExercise` + per-set overrides; user gets the copy as "{Name} (Copy)" in the same folder.
- **Defaults heuristic**: when an exercise is added, prescription defaults from the exercise's `mechanic` (compound → rest 180s, isolation → rest 90s) and `equipment` (barbell+compound → strength intent default; otherwise hypertrophy).

**Area 2 — Session snapshot pattern (load-bearing)**
- **`SessionFactory.start(routine:on:context:) -> Session`** lives in `fitbod/Sessions/` (NEW directory). It performs a deep copy: for each `RoutineExercise` in the routine, it creates a `SessionExercise` with all prescription fields snapshotted (intent, target reps, target RPE, progression kind, rest seconds), then creates the planned `SetEntry` rows pre-populated with target weight (from last-logged matching-intent session if available, else from the routine's prescription) — but with `actualWeight: nil` / `actualReps: nil` / `actualRPE: nil` until the user logs them.
- **Weak link back to source routine**: `Session.sourceRoutineID: UUID?` stored as a UUID (not a SwiftData relationship — that would cascade unexpectedly). The link is for UI ("Today's routine: Push Day A") and intent-split history filtering. Deleting the source routine doesn't affect logged sessions.
- **Editing the routine after a session starts**: the session is immutable from the routine's perspective. User edits to the routine alter the routine only. Tested in Phase 1's `CascadeRuleTests`, re-verified in this phase's snapshot tests.
- **Resuming a session**: a `Session` with `endedAt == nil` is "active". On app launch, if such a session exists, surface it on the Today tab as "Resume workout: {Name}". Only one active session at a time.

**Area 3 — Session logger UI**
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

**Area 4 — Rest timer (load-bearing pitfall mitigation)**
- **`Date`-based, not foreground `Timer`**: `RestTimerEngine` stores `startedAt: Date` + `targetSeconds: Int`. The UI computes remaining = `targetSeconds - Date.now.timeIntervalSince(startedAt)`. No background `Timer` to drift.
- **Auto-start**: completing a set (tapping the row's checkmark) triggers `RestTimerEngine.start(seconds: prescribedRestForCurrentExercise)`.
- **±15s buttons**: mutate `targetSeconds`. The persisted `Date` doesn't move.
- **Lock-screen notification**: when timer starts, schedule a `UNUserNotificationCenter` local notification for `startedAt + targetSeconds`. When user adjusts ±15s, reschedule. When timer is canceled (next set entered), cancel pending notifications.
- **Live Activity / Dynamic Island**: implemented via `ActivityKit`. The activity content is the rest seconds remaining + exercise name. New entitlement file: `fitbod.entitlements` with `com.apple.developer.usernotifications.live-activities` capability. Info.plist key `NSSupportsLiveActivities: YES`.
- **Auto-stop on next set entry**: when user taps the next set's weight field (or marks the next set complete), stop timer + cancel any pending notification.
- **Notification permission**: request on first session start (not at app launch — minimize permission prompt friction).

**Area 5 — Intent-split history view**
- **Entry point**: tap an exercise in the library → detail view (Phase 1) → new "History" tab → list of all logged sets across all sessions, grouped by date.
- **Intent split**: top-of-history filter chip group: "All / Strength / Hypertrophy / Power / Endurance / Technique". Default = "All". Tapping a chip filters the list.
- **Row format**: date — workout name (small) — weight × reps @ RPE — intent chip in accent color.
- **Empty state**: "No logged sets yet for this exercise."
- **Query optimization**: backed by `SessionExercise.exercise == X && SessionExercise.intentRaw == Y` predicate against the indexed fields from Phase 1.

**Area 6 — Folders for routines**
- **`RoutineFolder` entity** (NEW): `id`, `name`, `sortOrder: Int`, `createdAt`
- **`Routine.folderID: UUID?`** weak ref (no SwiftData relationship — keeps folder deletion from cascading routines; deleting a folder moves routines to "Unfiled")
- **Routines tab UI**: sectioned list grouped by folder; default folder is "Unfiled"; user creates folders via "+ Folder" action; folders reorderable

### Claude's Discretion
- Exact rest timer Live Activity layout — visual decision deferred to UI-SPEC for this phase
- Specific drag-handle iconography — use SF Symbols `line.3.horizontal`
- Cluster set sub-rep array UI style — small horizontal chips beneath the main set row, tap to add
- Notification permission UX timing — first session start (not app launch)

### Deferred Ideas (OUT OF SCOPE)
- **Charts** in per-exercise history — Phase 6
- **Recommended weight prescription** during session — Phase 3 (this phase displays previous values, not progression suggestions)
- **Warm-up sets generation** — Phase 3
- **Block periodization** — Phase 4
- **Volume / fatigue tracking** — Phase 5
- **Per-set landscape layout polish** — Phase 6 polish
- **Routine sharing / export individual routine as JSON** — Phase 6 export feature
- **Apple Watch session logger** — v2 (out of scope per PROJECT.md)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROUTINE-01 | User can build a routine in a single screen — inline exercise search-and-add, drag-handle reorder, no modal exercise picker | § Architecture Patterns → Inline exercise picker; § Code Examples → `ExerciseLibraryView` embedded mode |
| ROUTINE-02 | Each exercise in a routine carries first-class prescription: intent / target rep range / target RPE range | Phase 1 `RoutineExercise` entity already carries `intentRaw`, `targetRepsLow`/`High`, `targetRPE`; this phase wires the UI |
| ROUTINE-03 | Per-set prescription overrides within an exercise | § SwiftData Schema Patterns → `RoutineExerciseSetOverride` NEW entity; § Migration to SchemaV2 |
| ROUTINE-04 | User can group exercises into supersets and giant sets | § SwiftData Schema Patterns → `SupersetGroup` NEW entity + `RoutineExercise.supersetGroupID: UUID?` |
| ROUTINE-05 | User can choose a progression model per exercise from four options | Phase 1 `ProgressionKind` enum already exists (`rpe`/`double`/`block`/`hybrid`); this phase exposes the picker |
| ROUTINE-06 | User can duplicate routines and organize them into folders | § Code Examples → Deep-copy `Routine`; § SwiftData Schema Patterns → `RoutineFolder` NEW entity |
| ROUTINE-07 | Routine templates are stored separately from session instances — editing a routine never rewrites historical session data (snapshot-at-session-start) | § Architecture Patterns → Snapshot at session start; load-bearing for this phase, Phase 1 entity schema supports it |
| ROUTINE-08 | Same routine recurring with different intent maintains separate per-intent histories per exercise | § Code Examples → Intent-filtered `SessionExercise` query; Phase 1's `SessionExercise.intentRaw` `#Index` |
| ROUTINE-09 | Each routine exercise has a default rest timer (heuristic by mechanic) user-overridable | § Code Examples → Defaults heuristic on add |
| SESS-01 | `SessionFactory.start(...)` snapshots all routine prescription fields onto the session | § Code Examples → `SessionFactory.start` deep-copy reference implementation |
| SESS-02 | Per-set logging: weight, reps, decimal RPE, set type, per-set form notes | Phase 1 `SetEntry` entity has all fields; this phase wires the input UI |
| SESS-03 | Set inputs auto-populate from previous matching-intent session; inline "previous" column | § Code Examples → Intent-filtered previous-set query + inline column display |
| SESS-04 | Rest timer: Date-based, auto-start, ±15s, lock-screen notification, Live Activity / Dynamic Island, auto-stop on next set entry | § Architecture Patterns → `Date`-based timer; § Code Examples → `UNUserNotificationCenter` reschedule; § Code Examples → ActivityKit `Activity.request`/`update`/`end` |
| SESS-05 | Mid-session exercise swap without mutating routine template | § Code Examples → Swap `SessionExercise.exercise` reference; cascade contract preserved |
| SESS-06 | Add unplanned exercise mid-session | § Code Examples → Append `SessionExercise` to active `Session.exercises` |
| SESS-07 | Optional 4-field tempo per set | Phase 1 `SetEntry.tempoActual: String?` exists; UI adds `RoutineExercise.tracksTempo: Bool` toggle (SchemaV2 additive field) |
| SESS-08 | Partial reps + cluster/rest-pause sub-reps per set | § SwiftData Schema Patterns → Additive fields on SchemaV2 `SetEntry.partialReps: Int?` + `clusterSubRepsJoined: String?` |
| SESS-09 | Bodyweight + weighted-bodyweight: signed added/assisted weight | Phase 1 `SetEntry.weight: Double` is already signed; UI surfaces +/- toggle for bodyweight equipment |
| SESS-10 | Per-exercise history with intent split (list view, not chart) | § Code Examples → `ExerciseHistoryView` with `IntentFilterChipRow`; charts deferred to Phase 6 |
| SESS-11 | Workout-level + pinned per-exercise notes visible inline | Phase 1 `Session.notes` exists; `SessionExercise.pinnedNote: String?` is a SchemaV2 additive field |
</phase_requirements>

## Summary

Phase 2 ships the **minimum lovable product**: a single-screen routine builder, a session logger that snapshots prescription at start time, an accurate rest timer with Live Activity, and intent-split per-exercise history. The Phase 1 foundation already provides every load-bearing piece — `Routine`/`RoutineExercise`/`Session`/`SessionExercise`/`SetEntry` entities exist with all snapshot fields in place, `SessionExercise.intentRaw` is indexed for intent-filtered history queries, `Session.sourceRoutineID: UUID?` is a UUID-soft reference (no cascade from template deletion), and the `ExerciseLibraryView` was deliberately built to accept a `Binding<NavigationPath>` so a sibling picker init can be added without breaking the standalone tab caller. The only schema work needed is **additive** — three new entities (`RoutineFolder`, `SupersetGroup`, `RoutineExerciseSetOverride`) and a handful of additive fields on existing entities (`Routine.folderID`, `RoutineExercise.supersetGroupID`/`tracksTempo`/`tracksPartialReps`, `SessionExercise.pinnedNote`, `SetEntry.partialReps`/`clusterSubRepsJoined`). Apple's `MigrationStage.lightweight(fromVersion:toVersion:)` handles this automatically with no custom migration code.

The two load-bearing technical risks are well-understood: (1) the `SessionFactory.start(...)` deep-copy snapshot (PITFALLS #1 — the canonical risk) is straightforward Swift code with a clear test matrix (`SessionFactoryTests` proves that editing the routine after session start does not mutate the snapshot fields); (2) the rest timer (PITFALLS #4 — the #1 user-visible failure mode) is a `Date`-based engine that computes remaining time from `Date.now.timeIntervalSince(startedAt)` rather than running a foreground `Timer`. Lock-screen alerting is a `UNUserNotificationCenter` local notification scheduled for `startedAt + targetSeconds`; rescheduling on ±15s buttons is automatic because `UNUserNotificationCenter.add(request)` with the same identifier replaces the prior request. The Live Activity is a parallel `Activity<RestTimerAttributes>.request(...)` call that surfaces the same countdown on the Dynamic Island.

**Primary recommendation:** Build in 5 waves — (Wave 0) SchemaV2 migration scaffold + 3 new entity files + additive fields on existing entities; (Wave 1) `SessionFactory.start(...)` + `SessionFactoryTests` (snapshot integrity is non-negotiable); (Wave 2) `RestTimerEngine` + `RestTimerLiveActivity` + notification scheduling + manual test of lock-screen accuracy (the #1 user-visible failure mode); (Wave 3) `RoutineBuilderView` + `RoutinesListView` + folder UI + supersets + per-set overrides; (Wave 4) `SessionLoggerView` + per-set row UI + previous-column query + mid-session swap + add-unplanned; (Wave 5) `ExerciseHistoryView` + intent filter chips. The 5-wave structure puts the two load-bearing pieces (snapshot + rest timer) before any builder/logger UI so any architectural issues surface against unit tests rather than against a half-built screen.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Routine template storage + folder grouping | SwiftData (`Routine`, `RoutineFolder`, `RoutineExercise`, `RoutineExerciseSetOverride`, `SupersetGroup`) | SwiftUI (`RoutineBuilderView` + folder list) | All editing flows through `@Bindable` on `@Model` rows; folder grouping is a soft UUID ref to avoid cascade |
| Session lifecycle (start / resume / finish / discard) | Service (`SessionFactory`) + SwiftData (`Session` row state) | SwiftUI (`SessionLoggerView` + `ResumeWorkoutBanner`) | `SessionFactory.start` is the single deep-copy point; active session = `Session.completedAt == nil` |
| Per-set logging input + commit | SwiftUI views (`SetRow`, `InlineRPEChipRow`, `SetTypeChip`) | SwiftData (`@Bindable SetEntry`) | Direct `@Bindable` two-way binding; no view-model layer (FOUND-06) |
| Rest timer countdown computation | `@Observable` `RestTimerEngine` value holder | SwiftUI (Date-derived `remaining` recomputed at TimelineView tick) | `Date`-based — no foreground `Timer` to drift; UI re-renders via `TimelineView(.periodic(from: ...))` |
| Rest timer lock-screen alert | `UNUserNotificationCenter` local notification | iOS system | Scheduled for `startedAt + targetSeconds`; same-identifier reschedule replaces prior |
| Rest timer Live Activity / Dynamic Island | `ActivityKit` `Activity<RestTimerAttributes>` | Widget Extension target | New widget target hosts the `RestTimerLiveActivity: Widget` declaration; main app calls `Activity.request` / `update` / `end` |
| Inline "Previous" column data | SwiftData `FetchDescriptor<SessionExercise>` with `#Predicate` | SwiftUI (`PreviousColumn` view) | Query is fired per-row at row creation; result cached in `@State` per-row |
| Intent-split exercise history | SwiftData `@Query<SessionExercise>` with dynamic `#Predicate` | SwiftUI (`ExerciseHistoryView` + `IntentFilterChipRow`) | Outer/inner view split (same pattern as Phase 1's `FilteredExerciseList`) re-runs `@Query` on filter change |
| Routine folder / superset grouping | SwiftData `RoutineFolder` + `SupersetGroup` (NEW SchemaV2 entities) | UUID-soft refs on `Routine.folderID` / `RoutineExercise.supersetGroupID` | Soft refs avoid cascade surprises (deleting a folder must not delete its routines) |
| Inline exercise picker reuse | Refactor `ExerciseLibraryView` to add `onSelect: (Exercise) -> Void` init variant | Existing standalone tab init unchanged | Init-overload pattern — same pattern as the existing `init(path: Binding<NavigationPath>)` overload |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 26.4 SDK (deployment 18.0+) | All Phase 2 user-visible surfaces | Locked by PROJECT.md; native; integrates with `@Query`/`@Bindable`/`TimelineView` [VERIFIED: codebase + Apple docs] |
| SwiftData | iOS 26.4 SDK | Routine/Session/SetEntry persistence + 3 new entities under `SchemaV2` | Locked; `SchemaMigrationPlan` already scaffolded by Phase 1 [VERIFIED: codebase `fitbod/Persistence/FitbodSchemaMigrationPlan.swift`] |
| ActivityKit | iOS 16.1+ (we are 26.4) | Rest timer Live Activity + Dynamic Island | First-party; bundled; the only way to ship Dynamic Island content [CITED: developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities] |
| UserNotifications | iOS 10+ | Lock-screen rest-complete alert (`UNTimeIntervalNotificationTrigger`) | First-party; bundled; same-identifier reschedule is the standard pattern [CITED: developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger] |
| WidgetKit | iOS 14+ | Widget Extension target host for the `RestTimerLiveActivity: Widget` declaration | Required for ActivityKit — Live Activities are declared as `Widget` in a widget extension target [CITED: developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities] |
| Swift Testing | bundled with Xcode 26 | All Phase 2 unit tests (snapshot integrity, schema migration, rest timer math) | Already established in Phase 1 `fitbodTests/` [VERIFIED: codebase] |

### Supporting (Phase 2 only)
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `TimelineView(.periodic(from: startedAt, by: 1))` | Periodic re-render of the rest timer countdown at 1-second cadence | Inside `RestTimerOverlay` to drive remaining-seconds display [CITED: developer.apple.com/documentation/swiftui/timelineview] |
| `Activity.request(attributes:contentState:pushType:)` | Start the Live Activity | Called once from `RestTimerEngine.start(...)` after notification permission granted [CITED: developer.apple.com/documentation/activitykit/activity] |
| `Activity.update(ActivityContent(state:staleDate:))` | Update Live Activity content | Called on ±15s mutation + on natural countdown progression [CITED: developer.apple.com/documentation/activitykit/activity] |
| `Activity.end(ActivityContent(state:staleDate:), dismissalPolicy:)` | Tear down the Live Activity | Called on Skip / next-set-tapped / session-finish |
| `UNUserNotificationCenter.current().requestAuthorization(options:)` | First-time notification permission prompt | Called from `RestTimerEngine.start(...)` on first session start [CITED: developer.apple.com/documentation/usernotifications/unusernotificationcenter] |
| `UNTimeIntervalNotificationTrigger(timeInterval:repeats:false)` | Schedule the lock-screen alert | Created at `RestTimerEngine.start(...)` for `targetSeconds` from now [CITED: developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger] |
| `UNNotificationRequest` (same identifier across reschedules) | Reschedule via replace-by-identifier | Adding a new request with the same identifier auto-cancels the old one [CITED: useyourloaf.com/blog/local-notifications-with-ios-10/] |
| `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` | Cancel pending notification on Skip / next-set-tap | Called from `RestTimerEngine.stop()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Date`-based `RestTimerEngine` | Foreground `Timer.publish(every:on:)` | `Timer` stops/drifts when app backgrounds (PITFALLS #4). `Date.now.timeIntervalSince(startedAt)` is the only correct pattern. |
| `UNNotificationRequest` replace-by-identifier | Cancel-then-add (two operations) | Replace-by-identifier is atomic (single API call); cancel-then-add has a race window where no notification is scheduled [VERIFIED: useyourloaf.com/blog/local-notifications-with-ios-10/] |
| ActivityKit Live Activity | Background `Task` with no Dynamic Island | Live Activity is the only way to show countdown on the Dynamic Island; required by SESS-04 |
| Refactor `ExerciseLibraryView` to add `onSelect:` parameter | Build a new `ExerciseLibraryPickerView` from scratch | Refactor adds one additional `public init(...)` overload to the existing view — zero risk to standalone tab caller (same pattern as `init(path:)` from Phase 1) |
| `RoutineExerciseSetOverride` as a new `@Model` | Encode per-set overrides as a JSON string on `RoutineExercise.overridesJSON` | Per-set overrides are structured data with queryable fields (set index, reps low/high, RPE); using a proper relation enables type-safety + indexed queries; lightweight migration is additive-safe |
| `SchemaV2` lightweight migration (new entity, new fields) | `MigrationStage.custom(willMigrate:didMigrate:)` for the same changes | Additive entity adds + additive default-valued fields are eligible for `lightweight` migration — no custom code needed [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight(fromversion:toversion:)] |

**Installation:** No SPM dependencies (PROJECT.md locks zero third-party). Configuration changes:

```text
# 1. Add Info.plist key (main app target):
NSSupportsLiveActivities = YES (Bool)

# 2. Add entitlement to fitbod.entitlements (main app target):
<key>com.apple.developer.usernotifications.live-activities</key>
<true/>

# 3. Add NEW Widget Extension target ("FitbodWidgets") to host the
#    RestTimerLiveActivity: Widget declaration. The widget target gets
#    the same NSSupportsLiveActivities + entitlement keys.

# 4. Add bundle resources (none — pure Swift code).
```

**Version verification:** All ActivityKit / UserNotifications APIs used here are available on iOS 16.1+ (Live Activities + Dynamic Island), which is well below the project's iOS 18.0 deployment floor [CITED: Apple Developer Documentation, fetched 2026-05-11]. All `#Predicate` patterns used are iOS 17+ (we are well above) [CITED: developer.apple.com/documentation/foundation/predicate].

## Architecture Patterns

### System Architecture Diagram

```
                ┌────────────────────────────────────────────────────────────┐
                │                       SwiftUI                              │
                │                                                            │
                │   RootView (TabView)                                       │
                │      ├─ "Today"     → ResumeWorkoutBanner (if active) +   │
                │      │                 Phase 6 placeholder otherwise       │
                │      ├─ "Routines"  → RoutinesListView                     │
                │      │       │         ├ @Query<Routine>                  │
                │      │       │         ├ @Query<RoutineFolder>            │
                │      │       │         └ NavigationLink → RoutineBuilderView│
                │      │       │                ├ RoutineExerciseCard         │
                │      │       │                │   └ PrescriptionEditorRow   │
                │      │       │                │       ├ PerSetOverrideRow   │
                │      │       │                │       └ SupersetAssignmentSheet│
                │      │       │                └ InlineExerciseSearchRow     │
                │      │       │                     └ ExerciseLibraryView   │
                │      │       │                       (NEW picker init mode)│
                │      ├─ "Library"   → ExerciseLibraryView (standalone)    │
                │      │       │         └ ExerciseDetailView                │
                │      │       │              └ ExerciseHistoryView (NEW)    │
                │      │       │                   ├ IntentFilterChipRow     │
                │      │       │                   └ ExerciseHistoryRow      │
                │      ├─ "Progress"  → PlaceholderTabView(6)               │
                │      └─ "Settings"  → SettingsView                        │
                │                                                            │
                │   Modal: SessionLoggerView (NavigationStack)               │
                │      ├ SessionExerciseCard                                 │
                │      │     ├ SetRow                                        │
                │      │     │   ├ InlineRPEChipRow → DecimalRPEPickerSheet  │
                │      │     │   ├ SetTypeChip                               │
                │      │     │   ├ PreviousColumn (intent-filtered query)    │
                │      │     │   ├ TempoEntryRow (opt-in)                    │
                │      │     │   ├ PartialRepsRow (opt-in)                   │
                │      │     │   └ ClusterSubRepChipRow (rest-pause only)    │
                │      │     ├ SwapExerciseSheet → ExerciseLibraryView picker│
                │      │     └ PerSetNoteSheet                               │
                │      ├ AddUnplannedExerciseButton → ExerciseLibraryView picker│
                │      ├ WorkoutNotesSheet                                   │
                │      ├ FinishWorkoutConfirmation                           │
                │      └ RestTimerOverlay (top-mounted)                      │
                │            └ RestTimerProgressRing                         │
                │                                                            │
                └─────────────┬──────────────────────────────────────────────┘
                              │
                              │ user taps "Start Workout"
                              ▼
                ┌────────────────────────────────────────────────────────────┐
                │   SessionFactory.start(routine:on:context:)                 │
                │      1. Insert Session (sourceRoutineID = routine.id)      │
                │      2. For each RoutineExercise (sorted by orderIndex):   │
                │           - Insert SessionExercise (snapshot 11 fields)     │
                │           - Query previous matching-intent SessionExercise │
                │           - For setIndex in 0..<targetSets:                │
                │               * Insert SetEntry (orderIndex, target weight │
                │                 from previous, set type, default warmup    │
                │                 flag false, completedAt = .distantFuture   │
                │                 sentinel for "planned but not logged")    │
                │      3. ctx.save() — single transaction                    │
                │   Returns: the new Session row                             │
                └─────────────┬──────────────────────────────────────────────┘
                              │
                              │ user taps "Mark Set Complete"
                              ▼
                ┌────────────────────────────────────────────────────────────┐
                │   RestTimerEngine.start(seconds: prescribedRest)            │
                │      1. self.startedAt = Date.now                          │
                │      2. self.targetSeconds = prescribedRest                │
                │      3. UNUserNotificationCenter.add(request) for          │
                │         (startedAt + targetSeconds) — replaces prior       │
                │         request with same identifier                      │
                │      4. Activity<RestTimerAttributes>.request(...) starts  │
                │         Live Activity / Dynamic Island                    │
                │      5. RestTimerOverlay re-renders via TimelineView       │
                └─────────────┬──────────────────────────────────────────────┘
                              │
                              │ user taps "+15s"
                              ▼
                ┌────────────────────────────────────────────────────────────┐
                │   RestTimerEngine.adjust(deltaSeconds: +15)                 │
                │      1. self.targetSeconds += 15  (startedAt unchanged)    │
                │      2. UNUserNotificationCenter.add(request) re-issued —  │
                │         same identifier replaces prior                    │
                │      3. activity.update(ActivityContent(state: ...))       │
                └─────────────┬──────────────────────────────────────────────┘
                              │
                              │ user taps next set's weight field
                              ▼
                ┌────────────────────────────────────────────────────────────┐
                │   RestTimerEngine.stop()                                    │
                │      1. self.startedAt = nil                               │
                │      2. UNUserNotificationCenter                            │
                │           .removePendingNotificationRequests(...)          │
                │      3. activity.end(ActivityContent(state:), dismissal:)  │
                └────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (Phase 2 additions)

```
fitbod/
├── Models/                                # (Phase 1; SchemaV2 fields added inline)
│   ├── Routine.swift                     # + folderID: UUID?
│   ├── RoutineExercise.swift             # + supersetGroupID: UUID?, tracksTempo: Bool,
│   │                                     #   tracksPartialReps: Bool, setOverrides
│   ├── SessionExercise.swift             # + pinnedNote: String?
│   ├── SetEntry.swift                    # + partialReps: Int?, clusterSubRepsJoined: String?
│   ├── RoutineFolder.swift               # NEW @Model
│   ├── SupersetGroup.swift               # NEW @Model
│   └── RoutineExerciseSetOverride.swift  # NEW @Model
│
├── Persistence/
│   ├── SchemaV1.swift                    # (Phase 1 — unchanged)
│   ├── SchemaV2.swift                    # NEW VersionedSchema with 3 new entity types
│   └── FitbodSchemaMigrationPlan.swift   # + lightweight V1→V2 stage
│
├── Sessions/                              # NEW directory
│   ├── SessionFactory.swift              # The snapshot deep-copy entry point
│   ├── SessionLoggerView.swift
│   ├── SessionExerciseCard.swift
│   ├── SetRow.swift
│   ├── InlineRPEChipRow.swift
│   ├── DecimalRPEPickerSheet.swift
│   ├── SetTypeChip.swift
│   ├── PerSetNoteSheet.swift
│   ├── WorkoutNotesSheet.swift
│   ├── TempoEntryRow.swift
│   ├── PartialRepsRow.swift
│   ├── ClusterSubRepChipRow.swift
│   ├── PreviousColumn.swift
│   ├── SwapExerciseSheet.swift
│   ├── AddUnplannedExerciseButton.swift
│   ├── ResumeWorkoutBanner.swift
│   └── RestTimer/
│       ├── RestTimerEngine.swift          # @Observable Date-based controller
│       ├── RestTimerOverlay.swift
│       ├── RestTimerProgressRing.swift
│       ├── RestTimerLiveActivity.swift    # ActivityAttributes + ActivityConfiguration
│       ├── RestTimerLockScreenView.swift
│       ├── RestTimerDynamicIslandCompactView.swift
│       └── RestTimerDynamicIslandExpandedView.swift
│
├── Routines/                              # NEW directory
│   ├── RoutinesListView.swift
│   ├── RoutineRow.swift
│   ├── NewFolderSheet.swift
│   ├── MoveRoutineSheet.swift
│   ├── RoutineBuilderView.swift
│   ├── RoutineExerciseCard.swift
│   ├── PrescriptionEditorRow.swift
│   ├── PerSetOverrideRow.swift
│   ├── SupersetAssignmentSheet.swift
│   ├── InlineExerciseSearchRow.swift
│   ├── RoutineDraft.swift                # @Observable ephemeral state
│   ├── RoutineExerciseDraft.swift
│   ├── RoutineFolderDraft.swift
│   └── PerSetOverrideDraft.swift
│
├── ExerciseLibrary/
│   ├── ExerciseLibraryView.swift         # + new init for picker mode (onSelect:)
│   ├── ExerciseHistoryView.swift         # NEW (intent-split history list)
│   ├── IntentFilterChipRow.swift         # NEW
│   └── ExerciseHistoryRow.swift          # NEW
│
└── FitbodWidgets/                         # NEW Widget Extension target
    └── FitbodWidgetsBundle.swift          # Hosts RestTimerLiveActivity widget
```

### Pattern 1: Snapshot at Boundary (Template → Instance via `SessionFactory.start`)

**What:** When the user taps "Start Workout," `SessionFactory.start(routine:on:context:)` performs a deep copy: for each `RoutineExercise` in the routine, it creates a `SessionExercise` with all 11 prescription fields snapshotted (intent / target reps low+high / target RPE / target RIR / prescribed rest / tempo / progression kind, plus the snapshotted routine name on the parent `Session`). It then pre-populates planned `SetEntry` rows with target weight from the last-logged matching-intent session (if any) but leaves `weight`/`reps`/`rpe` as defaults until the user logs them.

**When:** Every "Start Workout" tap. Single source of truth for the load-bearing snapshot semantics (PITFALLS #1).

**Example:**

```swift
// Source: Adapted from ARCHITECTURE.md Pattern 1 — derived for Phase 2 schema
// File: fitbod/Sessions/SessionFactory.swift

import Foundation
import SwiftData

public enum SessionFactory {
    /// Start a new session from a routine. Deep-copies every prescription
    /// field from RoutineExercise to SessionExercise (PITFALLS #1) and
    /// pre-populates planned SetEntry rows with target weight pulled from
    /// the most recent matching-intent session for each exercise.
    ///
    /// Returns the newly-inserted Session. Caller is responsible for
    /// presenting `SessionLoggerView(session: returnedSession)`.
    ///
    /// Precondition: routine.exercises must be non-nil and non-empty.
    /// Precondition: no active session exists (Session.completedAt == nil
    /// for any row) — caller MUST check this and present a conflict alert
    /// before invoking. Asserted in debug builds.
    public static func start(
        routine: Routine,
        on date: Date = .now,
        context: ModelContext
    ) -> Session {
        let session = Session()
        session.id = UUID()
        session.startedAt = date
        session.completedAt = nil
        session.routineSnapshotName = routine.name
        session.sourceRoutineID = routine.id
        session.block = routine.block        // optional relationship; safe to copy
        session.notes = nil
        session.totalDurationSeconds = nil
        context.insert(session)

        let sortedRoutineExercises = (routine.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }

        for (orderIndex, re) in sortedRoutineExercises.enumerated() {
            let se = SessionExercise()
            se.id = UUID()
            se.session = session
            se.exercise = re.exercise
            se.orderIndex = orderIndex

            // SNAPSHOT: every prescription field copied. Future edits to
            // `re` will NOT mutate `se` — these are independent rows now.
            se.intentRaw = re.intentRaw
            se.targetSets = re.targetSets
            se.targetRepsLow = re.targetRepsLow
            se.targetRepsHigh = re.targetRepsHigh
            se.targetRPE = re.targetRPE
            se.targetRIR = re.targetRIR
            se.prescribedRestSeconds = re.prescribedRestSeconds
            se.tempo = re.tempo
            se.progressionKindRaw = re.progressionKindRaw
            // prescribedWeight is populated by Phase 3's ProgressionStrategy;
            // for Phase 2 we leave it nil and the SetEntry rows pull "weight
            // hint" from the previous matching-intent set query below.

            context.insert(se)

            // Resolve "previous matching-intent weight" for the planned
            // SetEntry rows. Returns nil for first-ever logged session of
            // this (exercise, intent) tuple — set rows default weight = 0.
            let previousHint = previousMatchingIntentSetWeight(
                exerciseID: re.exercise?.id,
                intentRaw: re.intentRaw,
                context: context
            )

            // Pre-populate planned SetEntry rows. Each set is created with
            // weight from previousHint (a "suggestion") but completedAt
            // is left at Date.now (the entity's default) — the planner
            // distinguishes "planned but not logged" by checking whether
            // the row's weight/reps were filled (set in user input) AND
            // by an explicit `setTypeRaw` cycle. For Phase 2, we INSERT
            // only as many SetEntry rows as targetSets calls for; each
            // row is initialised as `working` with the previousHint weight.
            for setIndex in 0..<re.targetSets {
                let entry = SetEntry()
                entry.id = UUID()
                entry.sessionExercise = se
                entry.orderIndex = setIndex
                entry.weight = previousHint ?? 0
                entry.reps = 0  // user fills in
                entry.rpe = nil
                entry.setTypeRaw = SetType.working.rawValue
                entry.isWarmup = false
                entry.completedAt = .distantPast  // sentinel: "planned, not yet completed"
                context.insert(entry)
            }
        }

        do {
            try context.save()
        } catch {
            // Catastrophic — surface as the "Couldn't Start Workout" alert
            // from UI-SPEC § Error states. Caller catches.
            assertionFailure("SessionFactory.start failed: \(error)")
        }
        return session
    }

    /// Returns the most-recently-logged weight from a SetEntry for the
    /// given exercise AND matching intent. Returns nil when there's no
    /// prior matching-intent session for this exercise.
    ///
    /// Performance: backed by Phase 1's `SessionExercise.intentRaw` #Index
    /// and `Session.startedAt` #Index. Fetches the top-ordered descriptor.
    private static func previousMatchingIntentSetWeight(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> Double? {
        guard let exerciseID else { return nil }
        // SwiftData predicate footgun: comparing `SessionExercise.exercise.id`
        // directly inside #Predicate triggers a runtime warning on iOS 17
        // and may return empty results. Extract to a local var first
        // (per simplykyra.com workaround). [VERIFIED via web search]
        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in
                se.intentRaw == intentRaw &&
                se.exercise != nil &&
                se.exercise!.id == exerciseID
            },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let mostRecent = try? context.fetch(descriptor).first else { return nil }
        // Use the top set (highest weight) of the most recent matching
        // session as the hint. Filter to working sets only — warmups
        // don't represent "what to start at today."
        let workingSets = (mostRecent.sets ?? []).filter { !$0.isWarmup }
        return workingSets.map(\.weight).max()
    }
}
```

**Trade-offs:** Slightly higher write cost at session-start (~10 fields × N exercises × `targetSets` planned set rows). At realistic N (6 exercises × 4 sets = 24 SetEntry rows) on iPhone-class hardware, the entire `SessionFactory.start` call completes in <50ms. The benefit is massive: editing the source `Routine` tomorrow does not retroactively mutate yesterday's logged session — that's the entire snapshot pattern.

### Pattern 2: `Date`-Based Rest Timer (PITFALLS #4 mitigation)

**What:** `RestTimerEngine` is an `@Observable` value holder with `startedAt: Date?` and `targetSeconds: Int`. The remaining time is computed `Date.now.timeIntervalSince(startedAt) - Double(targetSeconds)` and rendered via `TimelineView(.periodic(from: startedAt, by: 1))`. No foreground `Timer.publish` — that drifts/stops when the app backgrounds.

**When:** Every set completion. The single user-visible failure mode if implemented incorrectly (the user locks their phone, comes back 3 min later, and the timer "stopped at 47 seconds").

**Example:**

```swift
// Source: Composed from ARCHITECTURE.md + verified Date pattern
// File: fitbod/Sessions/RestTimer/RestTimerEngine.swift

import Foundation
import SwiftUI
import UserNotifications
import ActivityKit

@Observable
@MainActor
public final class RestTimerEngine {
    /// `nil` when the timer is not running. When set, the UI computes
    /// remaining as `Date.now.timeIntervalSince(startedAt) - targetSeconds`.
    public private(set) var startedAt: Date?
    public private(set) var targetSeconds: Int = 0
    public private(set) var currentExerciseName: String = ""

    /// Stable identifier for the pending local notification. The same
    /// identifier is used on every reschedule — `UNUserNotificationCenter.add`
    /// with a duplicate identifier replaces the prior request, which is
    /// the documented atomic-reschedule pattern. [VERIFIED]
    private let notificationID = "rest-timer.scheduled"

    /// Reference to the running ActivityKit Live Activity, when one was
    /// successfully started. Nil on simulator or if user denied Activities.
    private var liveActivity: Activity<RestTimerAttributes>?

    /// Computed remaining time in seconds. Negative when overrun (the
    /// countdown reached 0 and the user hasn't dismissed yet — UI shows
    /// "Rest complete" until next set entry).
    public var remaining: TimeInterval {
        guard let startedAt else { return 0 }
        return Double(targetSeconds) - Date.now.timeIntervalSince(startedAt)
    }

    /// Whether the timer is currently active.
    public var isRunning: Bool { startedAt != nil }

    public init() {}

    /// Start (or restart) the timer. Auto-called by `SetRow` on
    /// completion-checkmark tap.
    ///
    /// Schedules a UNUserNotification for lock-screen alert AND starts
    /// an ActivityKit Live Activity / Dynamic Island presentation. Both
    /// are best-effort — denial / simulator unavailability is silent
    /// (UI-SPEC § Error states: "silent fallback").
    public func start(seconds: Int, exerciseName: String) {
        self.startedAt = Date.now
        self.targetSeconds = seconds
        self.currentExerciseName = exerciseName

        scheduleNotification(in: seconds, exerciseName: exerciseName)
        startLiveActivity(seconds: seconds, exerciseName: exerciseName)
    }

    /// Mutate the target. The persisted `startedAt` does NOT move — the
    /// user is asking for more (or less) total rest from the original
    /// start point, not from now.
    public func adjust(deltaSeconds: Int) {
        guard isRunning else { return }
        let newTarget = max(0, targetSeconds + deltaSeconds)
        targetSeconds = newTarget

        guard let startedAt else { return }
        let firesIn = max(1, Int(startedAt.addingTimeInterval(Double(newTarget)).timeIntervalSince(Date.now)))
        scheduleNotification(in: firesIn, exerciseName: currentExerciseName)
        updateLiveActivity()
    }

    /// Stop the timer — called by SetRow when the user taps the NEXT set's
    /// weight field (auto-stop on next-set entry), or by the "Skip" button.
    public func stop() {
        startedAt = nil
        targetSeconds = 0

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
        endLiveActivity()
    }

    // MARK: - UNUserNotification

    private func scheduleNotification(in seconds: Int, exerciseName: String) {
        Task { @MainActor in
            // Defensive — only schedule if user has granted authorisation.
            // First session start fires the auth prompt; subsequent
            // sessions skip the prompt.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                // Try requesting once; if user denied, silent fallback.
                let granted = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                guard granted == true else { return }
                // Re-enter to actually schedule now that we're authorised.
                self.scheduleNotification(in: seconds, exerciseName: exerciseName)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "\(exerciseName) — next set ready."
            content.sound = .default

            // Non-repeating UNTimeIntervalNotificationTrigger has no
            // 60-second minimum (that minimum applies only to repeating
            // triggers per Apple docs). Rest timers commonly run 60-180s
            // but warm-up rests can be 30s. [VERIFIED via Apple docs]
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, TimeInterval(seconds)),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notificationID,
                content: content,
                trigger: trigger
            )
            // Adding a request with an existing identifier replaces the
            // previous one — atomic reschedule. [VERIFIED]
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - ActivityKit

    private func startLiveActivity(seconds: Int, exerciseName: String) {
        // Authorisation check — when the user has Live Activities disabled
        // in Settings, `areActivitiesEnabled` is false and the request would
        // throw. Silent fallback per UI-SPEC § Error states.
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }

        let attributes = RestTimerAttributes(
            sessionStartedAt: Date.now,
            exerciseName: exerciseName
        )
        let state = RestTimerAttributes.ContentState(
            startedAt: Date.now,
            targetSeconds: seconds
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date.now.addingTimeInterval(Double(seconds + 30))
        )
        do {
            liveActivity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil  // local-only updates; no APNs required
            )
        } catch {
            // Simulator / denial / capability mismatch — silent fallback.
            liveActivity = nil
        }
    }

    private func updateLiveActivity() {
        guard let liveActivity, let startedAt else { return }
        Task {
            let state = RestTimerAttributes.ContentState(
                startedAt: startedAt,
                targetSeconds: targetSeconds
            )
            let content = ActivityContent(
                state: state,
                staleDate: startedAt.addingTimeInterval(Double(targetSeconds + 30))
            )
            await liveActivity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }
        let final = RestTimerAttributes.ContentState(
            startedAt: liveActivity.contentState.startedAt,
            targetSeconds: 0  // signal "stopped" to lock-screen card
        )
        Task {
            await liveActivity.end(
                ActivityContent(state: final, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.liveActivity = nil
    }
}
```

The `RestTimerOverlay` view consumes this engine via:

```swift
// File: fitbod/Sessions/RestTimer/RestTimerOverlay.swift

import SwiftUI

public struct RestTimerOverlay: View {
    @Bindable var engine: RestTimerEngine

    public var body: some View {
        // TimelineView ticks every 1s; the body re-renders and reads
        // engine.remaining (which is Date.now-derived, so no drift).
        TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) { _ in
            HStack(spacing: 8) {
                Text(formatRemaining(engine.remaining))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("· Rest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
```

**Trade-offs:** `TimelineView(.periodic(by: 1))` causes ~1 view-body re-render per second while the timer is running. At Phase 2 scale this is trivially cheap — only the overlay view re-renders, not the entire session logger. The alternative (a `Timer.publish` + manual `@Published`) would drift on backgrounding. The pattern as designed survives lock + 3min + resume with sub-second accuracy.

### Pattern 3: `ActivityKit` Live Activity Declaration (in Widget Extension)

**What:** Live Activities live in a Widget Extension target. The `RestTimerAttributes: ActivityAttributes` declaration is shared between the main app (where `Activity.request` is called) and the widget extension (where `RestTimerLiveActivity: Widget` declares the lock-screen and Dynamic Island views).

**When:** Required by Apple — `ActivityKit` activities cannot live in the main app target alone; the widget extension is mandatory.

**Example:**

```swift
// Source: Adapted from Apple's ActivityKit documentation [CITED]
// File: fitbod/Sessions/RestTimer/RestTimerLiveActivity.swift
// (Shared by both main app target and FitbodWidgets extension target)

import ActivityKit
import WidgetKit
import SwiftUI

public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Wall-clock start time. The widget computes elapsed off Date.now.
        public var startedAt: Date
        /// Total rest in seconds. UI computes remaining = target - elapsed.
        /// Set to 0 to signal "stopped" to lock-screen card before dismissal.
        public var targetSeconds: Int

        public init(startedAt: Date, targetSeconds: Int) {
            self.startedAt = startedAt
            self.targetSeconds = targetSeconds
        }
    }

    /// Static — set once at .request() time, never updates.
    public var sessionStartedAt: Date
    public var exerciseName: String

    public init(sessionStartedAt: Date, exerciseName: String) {
        self.sessionStartedAt = sessionStartedAt
        self.exerciseName = exerciseName
    }
}

@available(iOS 16.1, *)
public struct RestTimerLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock screen / banner view (iPhone < Pro, or all phones when
            // Dynamic Island can't render).
            RestTimerLockScreenView(
                state: context.state,
                exerciseName: context.attributes.exerciseName
            )
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — long-press on the island
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(remainingText(state: context.state))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.exerciseName)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: elapsed(state: context.state),
                        total: Double(context.state.targetSeconds)
                    )
                    .tint(.accentColor)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(remainingText(state: context.state))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(URL(string: "fitbod://session/active"))
        }
    }

    private func elapsed(state: RestTimerAttributes.ContentState) -> Double {
        Date.now.timeIntervalSince(state.startedAt)
    }

    private func remainingText(state: RestTimerAttributes.ContentState) -> String {
        let remaining = max(0, Double(state.targetSeconds) - elapsed(state: state))
        let s = Int(remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
```

**Trade-offs:** Adding a Widget Extension target adds a small amount of build complexity (a second target, a second Info.plist, a shared module for `RestTimerAttributes`). The benefit is essential — Dynamic Island and lock-screen Live Activities are only reachable through this target. The cost is well-understood; this is the standard Apple-prescribed pattern.

### Pattern 4: Lightweight SwiftData Migration (V1 → V2 additive)

**What:** Phase 2 adds 3 new entities and a handful of new fields. All additive — `MigrationStage.lightweight(fromVersion:toVersion:)` handles this automatically with no custom code [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight(fromversion:toversion:)].

**When:** This is the project's first migration. Phase 1 deliberately scaffolded `SchemaV1: VersionedSchema` + `FitbodSchemaMigrationPlan` with empty `stages: []` so Phase 2 can slot in cleanly.

**Example:**

```swift
// File: fitbod/Persistence/SchemaV2.swift
//
// Adds 3 new entity types (RoutineFolder, SupersetGroup,
// RoutineExerciseSetOverride) and additive fields on existing entities.
// Additive-only changes — eligible for MigrationStage.lightweight.

import SwiftData

public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            // SchemaV1 inheritors (unchanged identity, additive fields)
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Routine.self,
            RoutineExercise.self,
            Session.self,
            SessionExercise.self,
            SetEntry.self,
            Block.self,
            BlockPhase.self,
            UserSettings.self,
            MuscleVolumeTarget.self,
            // NEW in V2
            RoutineFolder.self,
            SupersetGroup.self,
            RoutineExerciseSetOverride.self,
        ]
    }
}
```

```swift
// File: fitbod/Persistence/FitbodSchemaMigrationPlan.swift (MODIFIED)

import SwiftData

public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Lightweight: SwiftData handles all schema deltas automatically.
    /// Validates: adding new entity types is supported; adding new
    /// default-valued properties is supported; both apply here.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage]
    public static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
```

```swift
// File: fitbod/fitbodApp.swift (MODIFIED)
// Change Schema(SchemaV1.models) → Schema(SchemaV2.models)
//
// The migration plan handles the V1→V2 step automatically when the
// existing on-disk store is opened against SchemaV2. No data migration
// is needed because all changes are additive (new entities + new
// default-valued fields).

let schema = Schema(SchemaV2.models)
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
container = try ModelContainer(
    for: schema,
    migrationPlan: FitbodSchemaMigrationPlan.self,
    configurations: config
)
```

**Trade-offs:** Lightweight migration is the lowest-cost path. The only constraint is that all schema changes must be additive (new types, new default-valued fields). Phase 2's schema deltas are all additive by design — that's why this migration path was chosen.

### Pattern 5: Reusable Inline Exercise Picker (init-overload refactor)

**What:** Refactor `ExerciseLibraryView` to add a third init that takes `onSelect: (Exercise) -> Void`. When this init is used, the view operates in "picker mode": tapping a row invokes `onSelect(exercise)` instead of pushing `ExerciseDetailView`. The existing standalone-tab init and the `path:`-binding init both stay unchanged.

**When:** Routine builder + mid-session swap + add-unplanned-exercise all use this picker mode. This is the canonical "reuse Phase 1 code without breaking Phase 1 callers" pattern.

**Example:**

```swift
// Source: Derived from current fitbod/ExerciseLibrary/ExerciseLibraryView.swift
// File: fitbod/ExerciseLibrary/ExerciseLibraryView.swift (MODIFIED)

public struct ExerciseLibraryView: View {
    // ... existing state ...

    /// Standalone init — unchanged.
    public init() {
        self.externalPath = nil
        self.onSelect = nil
    }

    /// Externally-bound NavigationPath init — unchanged.
    public init(path: Binding<NavigationPath>) {
        self.externalPath = path
        self.onSelect = nil
    }

    /// NEW — picker init. When provided, tapping a row invokes the
    /// closure instead of pushing ExerciseDetailView. The "+" toolbar
    /// button for creating a custom exercise is still rendered (the
    /// builder may want to add a brand-new custom exercise mid-build).
    public init(onSelect: @escaping (Exercise) -> Void) {
        self.externalPath = nil
        self.onSelect = onSelect
    }

    private var onSelect: ((Exercise) -> Void)?

    private var isPickerMode: Bool { onSelect != nil }

    // Inner FilteredExerciseList already takes a row-tap closure pattern;
    // when isPickerMode the destination is `Button { onSelect?(ex) }`
    // instead of `NavigationLink(value: ex)`.
}
```

The inner `FilteredExerciseList` switches its row content based on `isPickerMode`:

```swift
// Inside FilteredExerciseList.body, ForEach loop:
ForEach(section.exercises) { ex in
    if let onSelect {
        // Picker mode — invoke closure, no navigation.
        Button {
            onSelect(ex)
        } label: {
            ExerciseRow(exercise: ex)
        }
        .buttonStyle(.plain)
    } else {
        // Standalone / path-binding mode — push detail (Phase 1 behavior).
        NavigationLink(value: ex) {
            ExerciseRow(exercise: ex)
        }
    }
}
```

**Trade-offs:** One additional init overload (5 lines) + one `Button`/`NavigationLink` switch in the inner view (8 lines). Zero risk to existing callers — all Phase 1 tests + previews continue to use the original two inits and see identical behavior. This is the cleanest possible refactor for the inline-picker requirement.

### Anti-Patterns to Avoid

- **Mutating the source `Routine` inside `SessionFactory.start`:** the factory must be read-only against the routine. Writing back to `RoutineExercise` (e.g., "remember this rest seconds for next time") leaks template state forward and violates the snapshot contract. Future progression learning should happen at the `SessionExercise` level only.
- **Foreground `Timer.publish` for the rest timer:** PITFALLS #4. The timer drifts/stops on backgrounding. `Date.now`-based computation is the only correct pattern.
- **Cancel-then-add for notification rescheduling:** introduces a race window where no notification is scheduled. Use replace-by-identifier (`UNUserNotificationCenter.add(request)` with the same identifier).
- **Mutating `RoutineExercise.exercise` in mid-session swap:** swap mutates `SessionExercise.exercise` only. The routine template is read-only from session start onward.
- **Computing previous-set query inside the `SetRow` body re-render:** the query fires once per row at creation time. Cache the result in row-scoped `@State`. Body re-renders (e.g., on weight field tap) must read from cache.
- **Using a SwiftData relationship for `Session.sourceRoutineID`:** would cascade unexpectedly. Soft UUID ref (already in place from Phase 1) is the correct shape.
- **Storing per-set overrides as a JSON string on `RoutineExercise`:** loses type safety, breaks `#Predicate` filtering, and bloats migration risk. Use the proper `RoutineExerciseSetOverride` join entity.
- **Sharing one `RestTimerEngine` across multiple sessions:** the engine is session-scoped — owned by `SessionLoggerView` and torn down on session finish.
- **Re-issuing `Activity<RestTimerAttributes>.request` on every ±15s:** that creates a new Live Activity (Apple caps active activities at ~10 per app). Use `activity.update(...)` to mutate the existing one.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Background-survivable countdown timer | Foreground `Timer.publish` that pauses on lock | `Date`-based engine + `UNTimeIntervalNotificationTrigger` + `Activity.update` | Foreground timers drift; lock-screen notifications are the only way to alert on lock; PITFALLS #4 |
| Reschedule logic with cancel-then-add | Two API calls + race window | `UNUserNotificationCenter.add` with same identifier | Apple's replace-by-identifier is atomic and one call [VERIFIED] |
| Custom drag-handle list reorder | Hand-rolled `Gesture` + transform animations | SwiftUI `.onMove` + `EditMode` | Native handles a11y / haptics / cancel for free [CITED: hackingwithswift.com/quick-start/swiftui/how-to-let-users-move-rows-in-a-list] |
| Lock-screen rest-timer card | Custom `UIView` overlay or HKWorkoutSession hack | `ActivityKit` Live Activity | ActivityKit is the only OS-supported lock-screen card mechanism on iOS 16.1+ |
| Dynamic Island rest-timer presentation | (impossible without ActivityKit) | `ActivityConfiguration` with `DynamicIsland { ... }` | No alternative — Apple gates the API |
| SwiftData additive migration (new entity types, new fields) | Manual `MigrationStage.custom` with closure transforms | `MigrationStage.lightweight(fromVersion:toVersion:)` | SwiftData detects additive deltas automatically; custom is for renames/splits only |
| Routine-builder embedded exercise picker | Build a new picker view from scratch | Refactor `ExerciseLibraryView` to add `onSelect:` init | Cuts ~500 LOC of duplicate code; preserves single source of truth for filter/search UI |
| Per-set previous-data display | Loop through all sessions in view body, sort, filter | `FetchDescriptor<SessionExercise>` with `#Predicate` + index | Phase 1's `SessionExercise.intentRaw` `#Index` makes this O(log n); per-render scan would be O(n) and re-fire on every body re-render |
| Decimal RPE picker UI | Custom wheel built from `LongPressGesture` + offsets | SwiftUI native `Picker(...).pickerStyle(.wheel)` inside a sheet | Native handles a11y / haptics / cancel for free |
| Active-session detection | Periodic launch-time scan + flag | `@Query` with `#Predicate<Session> { $0.completedAt == nil }` | Reactive via Phase 1's `Session.startedAt` `#Index` |

**Key insight:** Apple has already shipped every primitive Phase 2 needs. The work is composition, not invention. The only "novel" component is the `SessionFactory.start` deep copy, and that's 30 lines of straightforward Swift.

## Runtime State Inventory

> Phase 2 is **greenfield additive** — no rename, no refactor, no migration of existing user data. The Phase 2 schema migration is additive-only (3 new entities + a few new default-valued fields), and there is no user-installed runtime state from Phase 1 to migrate (the app is single-user, single-device, pre-shipped). State inventory is therefore N/A for this phase.
>
> **Confirmation:**
> - **Stored data:** None to migrate. SchemaV2 deltas are additive; existing Phase 1 store opens cleanly under lightweight migration.
> - **Live service config:** None. No external services.
> - **OS-registered state:** None. No task scheduler / pm2 / launchd registrations exist.
> - **Secrets/env vars:** None. No secrets used.
> - **Build artifacts:** None. The Phase 1 build is parse-clean; Phase 2 adds files but does not rename anything.

## Common Pitfalls

### Pitfall 1: `SwiftData #Predicate` on related entity ID returns empty results

**What goes wrong:** Writing `#Predicate<SessionExercise> { $0.exercise?.id == someUUID }` directly compiles but may return empty results at runtime due to a known SwiftData `#Predicate` macro limitation around comparing UUID properties on related models.
**Why it happens:** The `#Predicate` macro's compile-time transformation has a limitation when traversing `?.id == comparedValue` paths on `@Model` relationships. [CITED: simplykyra.com/blog/swiftdata-problems-with-filtering-by-entity-in-the-predicate/]
**How to avoid:** Extract the UUID into a local `let` before constructing the predicate, then reference the local in the predicate body. Some sources also recommend using `persistentModelID` rather than the custom UUID `id` field.
**Warning signs:** A query that should return rows returns empty; print-debugging shows the correct rows exist in the context but the predicate skips them.
**Concrete fix for the previous-set query:**
```swift
let targetID = exerciseID  // Extract to local first
let descriptor = FetchDescriptor<SessionExercise>(
    predicate: #Predicate { se in
        se.intentRaw == intentRaw && se.exercise?.id == targetID
    },
    sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
)
```

### Pitfall 2: Rest timer drifts when phone locks (PITFALLS-doc #4 — load-bearing)

**What goes wrong:** User logs a set, locks phone, comes back 3 minutes later. A foreground-`Timer`-based countdown shows "1:47" remaining instead of having fired. Lock-screen alert never came.
**Why it happens:** iOS suspends the app shortly after backgrounding. `Timer.publish` stops firing; any internal `remainingSeconds` state is frozen.
**How to avoid:** Store `startedAt: Date` + `targetSeconds: Int`. Compute `remaining = targetSeconds - Date.now.timeIntervalSince(startedAt)` at render time. Schedule `UNTimeIntervalNotificationTrigger` for `targetSeconds` from start. On foreground, recompute remaining from `Date.now` — no drift possible.
**Warning signs:** Manual test: start a 180s rest, lock phone, wait 3 min — verify (1) lock-screen notification fires at the right wall-clock moment, (2) reopening the app shows correct remaining (0 or "complete").

### Pitfall 3: `Activity.request` throws on simulators / pre-Pro iPhones

**What goes wrong:** `try Activity<RestTimerAttributes>.request(...)` throws on iPhone simulators (no Dynamic Island simulation) and on iPhones < Pro models (no Dynamic Island hardware). If unhandled, every rest-timer start surfaces an error to the user.
**Why it happens:** ActivityKit requires `ActivityAuthorizationInfo().areActivitiesEnabled` to be true AND a host system that supports activities. Simulators often fail the first check.
**How to avoid:** Always check `ActivityAuthorizationInfo().areActivitiesEnabled` before `request`. Wrap `request` in `do/catch` and silently nil the `liveActivity` ref on failure. The in-app `RestTimerOverlay` still renders correctly without the Live Activity — only the Dynamic Island / lock-screen card is missing.
**Warning signs:** Console logs show "Failed to start live activity" — verify the in-app overlay still works.

### Pitfall 4: `UNNotificationRequest` permission denied silently

**What goes wrong:** First call to `requestAuthorization(options:)` returns `false`. Subsequent `add(request)` calls fail silently. User locks phone, no alert fires, blames the app.
**Why it happens:** `requestAuthorization` only prompts once per app lifetime. Subsequent calls return the prior decision.
**How to avoid:** Check `UNUserNotificationCenter.current().notificationSettings().authorizationStatus` before scheduling. On `.denied`, render the UI-SPEC defensive banner ("Notifications Disabled — Rest timer alerts won't fire on the lock screen. Enable in Settings."). The in-app overlay still works.
**Warning signs:** Settings → fitbod → Notifications shows "Off" — banner should display the first time the user starts a rest timer.

### Pitfall 5: `@Bindable` write-through on `RoutineExercise` while a session is active

**What goes wrong:** User opens routine builder and edits a `RoutineExercise.targetRPE` while a session is in progress in the background. The session's `SessionExercise.targetRPE` should NOT change (snapshot contract) — but if the schema accidentally points at the routine row, it would.
**Why it happens:** Snapshot-vs-instance is enforced by the data model — `SessionExercise` has its own `targetRPE` field that's copied from `RoutineExercise.targetRPE` at session start. This pitfall is only a risk if someone accidentally introduces a relationship between the two.
**How to avoid:** `SessionExercise` must continue to have its own snapshot fields. Don't replace them with a `routineExercise: RoutineExercise?` relationship — the schema is correctly shaped already.
**Warning signs:** Caught at test time — `SessionFactoryTests/editingRoutineAfterSessionStartLeavesSnapshotIntact` is the canonical guard.

### Pitfall 6: Routine duplication misses per-set overrides / superset assignments

**What goes wrong:** User taps "Duplicate" on a routine with supersets + per-set overrides. The duplicate has the exercises but lost the supersets — they're now ungrouped.
**Why it happens:** Naive duplication clones `Routine` + `RoutineExercise` but forgets to clone `SupersetGroup` rows and re-attach the new `RoutineExercise.supersetGroupID` to the cloned groups, and forgets to clone `RoutineExerciseSetOverride` rows.
**How to avoid:** Duplication must be a true deep copy: clone all `RoutineExercise`s, all `SupersetGroup`s belonging to the source routine, all `RoutineExerciseSetOverride`s, and remap all UUID refs to the cloned counterparts.
**Warning signs:** Test: build a routine with 2 supersets + per-set overrides, duplicate, open the copy — verify supersets and overrides are present.

### Pitfall 7: Active-session conflict on "Start Workout"

**What goes wrong:** User has an active session (didn't finish before locking phone). Days later, taps "Start Workout" on another routine. Now there are two active sessions, both with `completedAt == nil`.
**Why it happens:** No enforcement of the "one active session at a time" invariant.
**How to avoid:** Before invoking `SessionFactory.start`, fetch `#Predicate<Session> { $0.completedAt == nil }` — if non-empty, show the UI-SPEC conflict alert ("Workout in Progress — Finish or discard the current workout before starting a new one"). The `ResumeWorkoutBanner` on the Today tab uses the same query and surfaces the active session.
**Warning signs:** Manual test: start session A, don't finish, restart app, try to start session B — alert should appear.

### Pitfall 8: Per-set override insertion order desync from canonical `targetSets`

**What goes wrong:** User configures 3 sets on a routine exercise with per-set overrides for sets 0, 1, 2. Then reduces `targetSets` to 2 — but the override for set 2 lingers. Next session has only 2 SetEntry rows but the override for set 2 has no home.
**Why it happens:** `targetSets` and `setOverrides.count` can drift independently.
**How to avoid:** When `targetSets` decreases, prune `setOverrides` where `setIndex >= newTargetSets`. When `targetSets` increases, do nothing (new sets inherit base prescription).
**Warning signs:** Test: set 3 overrides, drop to 2 sets, query overrides — should be 2 rows max.

### Pitfall 9: Live Activity rate limit (~1 update per second is fine, but bursts throttle)

**What goes wrong:** A user spam-taps "+15s" 10 times in a second. Each call invokes `activity.update(...)`. Apple's rate limiter throttles and some updates drop.
**Why it happens:** ActivityKit has documented update rate limits — Apple throttles bursts to prevent battery drain.
**How to avoid:** Debounce ±15s mutations to coalesce rapid taps. The accumulated `targetSeconds` change after a 200ms quiet window is sent as a single `activity.update`.
**Warning signs:** Manual test: spam-tap "+15s" — the Dynamic Island should converge to the correct value within 1s.

### Pitfall 10: SwiftUI `.onMove` reorder swaps in EditMode but doesn't persist orderIndex

**What goes wrong:** User drags exercise 3 to position 1 in the routine builder. View updates visually. Closing and reopening the routine — exercise 3 is back at position 3.
**Why it happens:** `.onMove { source, destination in ... }` provides indices; the closure must mutate the underlying array AND rewrite `orderIndex` on each `RoutineExercise` to persist the new order.
**How to avoid:** Inside `.onMove`, after `array.move(fromOffsets:toOffset:)`, iterate the array and assign `orderIndex = i` for each.
**Warning signs:** Test: reorder, close routine, reopen — exercises should be in new order.

## Code Examples

### Example 1: Intent-filtered Previous-Set query (SESS-03, SESS-10, ROUTINE-08)

```swift
// Source: Derived from Apple #Predicate docs + simplykyra.com workaround
// File: fitbod/Sessions/PreviousColumn.swift

import SwiftUI
import SwiftData

/// Inline "Previous" column on the SetRow — shows the most recent
/// matching-intent set for this exercise as a faint inline hint.
/// Backed by `SessionExercise.intentRaw` #Index from Phase 1.
public struct PreviousColumn: View {
    @Environment(\.modelContext) private var ctx
    let exerciseID: UUID?
    let intentRaw: String
    @State private var hint: PreviousHint?

    public var body: some View {
        Group {
            if let hint {
                Text("\(formatWeight(hint.weight)) × \(hint.reps) @ \(formatRPE(hint.rpe)) (\(hint.dayOfWeek))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .task {
            hint = await fetchHint()
        }
    }

    private func fetchHint() async -> PreviousHint? {
        guard let exerciseID else { return nil }
        let targetID = exerciseID  // Extract — see Pitfall 1
        let targetIntent = intentRaw

        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in
                se.intentRaw == targetIntent && se.exercise?.id == targetID
            },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5  // Look at last 5 to find the top working set

        do {
            let recent = try ctx.fetch(descriptor)
            guard let mostRecent = recent.first else { return nil }
            let workingSets = (mostRecent.sets ?? []).filter { !$0.isWarmup && $0.reps > 0 }
            guard let topSet = workingSets.max(by: { $0.weight < $1.weight }) else { return nil }
            return PreviousHint(
                weight: topSet.weight,
                reps: topSet.reps,
                rpe: topSet.rpe,
                dayOfWeek: dayOfWeekShort(mostRecent.session?.startedAt ?? .distantPast)
            )
        } catch {
            return nil
        }
    }
}

private struct PreviousHint {
    let weight: Double
    let reps: Int
    let rpe: Double?
    let dayOfWeek: String
}

private func formatWeight(_ w: Double) -> String { /* per UserSettings unit */ }
private func formatRPE(_ rpe: Double?) -> String { rpe.map { String(format: "%.1f", $0) } ?? "—" }
private func dayOfWeekShort(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated))
}
```

### Example 2: Drag-handle reorder with always-visible handles

```swift
// Source: Derived from Apple SwiftUI docs + sarunw.com pattern
// File: fitbod/Routines/RoutineBuilderView.swift (excerpt)

import SwiftUI

struct RoutineBuilderView: View {
    @Bindable var draft: RoutineDraft

    var body: some View {
        List {
            ForEach(draft.exercises.indices, id: \.self) { index in
                RoutineExerciseCard(draft: $draft.exercises[index])
            }
            .onMove { source, destination in
                draft.exercises.move(fromOffsets: source, toOffset: destination)
                // Rewrite orderIndex to persist (Pitfall 10)
                for (i, ex) in draft.exercises.enumerated() {
                    ex.orderIndex = i
                }
            }
        }
        // Force EditMode .active so drag handles are always visible.
        // The default .inactive hides them; toggle to .active for
        // always-on grip handles (per UI-SPEC and CONTEXT.md Area 1).
        .environment(\.editMode, .constant(.active))
    }
}
```

### Example 3: Active-session conflict guard

```swift
// File: fitbod/Routines/RoutinesListView.swift (excerpt)

@Query(filter: #Predicate<Session> { $0.completedAt == nil })
private var activeSessions: [Session]

@State private var presentingConflict: Routine?

func handleStartTap(routine: Routine) {
    if !activeSessions.isEmpty {
        presentingConflict = routine
        return
    }
    let session = SessionFactory.start(routine: routine, on: .now, context: ctx)
    // Navigate to SessionLoggerView(session:)
}
```

### Example 4: Schema-V2 new entity (RoutineFolder)

```swift
// File: fitbod/Models/RoutineFolder.swift (NEW for SchemaV2)

import Foundation
import SwiftData

@Model
public final class RoutineFolder {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var sortOrder: Int = 0
    public var createdAt: Date = Date.now

    public init() {}

    public convenience init(name: String, sortOrder: Int = 0) {
        self.init()
        self.name = name
        self.sortOrder = sortOrder
    }
}
```

```swift
// File: fitbod/Models/SupersetGroup.swift (NEW for SchemaV2)

import Foundation
import SwiftData

@Model
public final class SupersetGroup {
    @Attribute(.unique) public var id: UUID = UUID()
    public var routineID: UUID = UUID()  // soft ref to source Routine
    public var kindRaw: String = "paired"  // "paired" or "giant"
    public var sortOrder: Int = 0
    public var createdAt: Date = Date.now

    public init() {}

    public convenience init(routineID: UUID, kindRaw: String = "paired", sortOrder: Int = 0) {
        self.init()
        self.routineID = routineID
        self.kindRaw = kindRaw
        self.sortOrder = sortOrder
    }
}

public enum SupersetKind: String, CaseIterable, Sendable {
    case paired
    case giant
}

extension SupersetGroup {
    public var kind: SupersetKind { SupersetKind(rawValue: kindRaw) ?? .paired }
}
```

```swift
// File: fitbod/Models/RoutineExerciseSetOverride.swift (NEW for SchemaV2)

import Foundation
import SwiftData

@Model
public final class RoutineExerciseSetOverride {
    @Attribute(.unique) public var id: UUID = UUID()
    public var routineExercise: RoutineExercise? = nil
    public var setIndex: Int = 0
    public var targetRepsLow: Int? = nil
    public var targetRepsHigh: Int? = nil
    public var targetRPE: Double? = nil

    public init() {}

    public convenience init(
        setIndex: Int,
        targetRepsLow: Int? = nil,
        targetRepsHigh: Int? = nil,
        targetRPE: Double? = nil
    ) {
        self.init()
        self.setIndex = setIndex
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
    }
}

// Inverse declared on RoutineExercise:
//   @Relationship(deleteRule: .cascade, inverse: \RoutineExerciseSetOverride.routineExercise)
//   public var setOverrides: [RoutineExerciseSetOverride]? = []
```

### Example 5: Decimal RPE long-press → wheel picker

```swift
// File: fitbod/Sessions/InlineRPEChipRow.swift (excerpt)

import SwiftUI

struct InlineRPEChipRow: View {
    @Binding var rpe: Double?
    @State private var presentingDecimalPicker = false
    @State private var longPressedValue: Double = 8

    var body: some View {
        HStack(spacing: 8) {
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button("\(value)") {
                    rpe = Double(value)
                }
                .buttonStyle(.bordered)
                .tint(Int(rpe ?? 0) == value ? .accentColor : .secondary)
                .frame(minWidth: 44, minHeight: 44)  // HIG touch target
                .onLongPressGesture(minimumDuration: 0.5) {
                    longPressedValue = Double(value)
                    presentingDecimalPicker = true
                }
            }
        }
        .sheet(isPresented: $presentingDecimalPicker) {
            DecimalRPEPickerSheet(
                rpe: Binding(
                    get: { rpe ?? longPressedValue },
                    set: { rpe = $0 }
                )
            )
            .presentationDetents([.fraction(0.3)])
        }
    }
}

// File: fitbod/Sessions/DecimalRPEPickerSheet.swift

import SwiftUI

struct DecimalRPEPickerSheet: View {
    @Binding var rpe: Double
    @Environment(\.dismiss) private var dismiss

    // 0.5 increments from 6.0 to 10.0 = 9 options
    private let options: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    var body: some View {
        NavigationStack {
            Picker("RPE", selection: $rpe) {
                ForEach(options, id: \.self) { v in
                    Text(String(format: "%.1f", v)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("RPE")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

### Example 6: ResumeWorkoutBanner (Today tab + Routines tab)

```swift
// File: fitbod/Sessions/ResumeWorkoutBanner.swift

import SwiftUI
import SwiftData

public struct ResumeWorkoutBanner: View {
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    /// Closure invoked when the user taps "Resume" — caller navigates to
    /// SessionLoggerView. Phase 2's caller is RootView (passing path
    /// bindings) for the Today tab and the Routines tab.
    public let onResume: (Session) -> Void
    public let onDiscard: (Session) -> Void

    public init(onResume: @escaping (Session) -> Void, onDiscard: @escaping (Session) -> Void) {
        self.onResume = onResume
        self.onDiscard = onDiscard
    }

    public var body: some View {
        if let active = activeSessions.first {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(.accent)
                VStack(alignment: .leading) {
                    Text("Resume Workout: \(active.routineSnapshotName)")
                        .font(.headline)
                }
                Spacer()
                Button("Resume") { onResume(active) }
                    .foregroundStyle(.accent)
                Button("Discard", role: .destructive) { onDiscard(active) }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach (iOS 18) | When Changed | Impact |
|--------------|---------------------------|--------------|--------|
| `Timer.publish` for countdowns | `TimelineView(.periodic(from:by:))` + `Date.now`-derived state | iOS 15 / SwiftUI 3 | UI auto-pauses with view; no manual subscription mgmt |
| Foreground-only rest timers | `Date` + `UNTimeIntervalNotificationTrigger` + ActivityKit | iOS 16.1 (ActivityKit) | Survives backgrounding; lock-screen alert + Dynamic Island |
| Custom drag-handle gesture | SwiftUI `.onMove` + `EditMode` | iOS 13 | a11y / haptics / cancel for free |
| `ObservableObject` for ephemeral UI state | `@Observable` macro | iOS 17 / Swift 5.9 | Less boilerplate; granular re-renders |
| `Codable` on `@Model` types | Decode to DTO + map at insert | always | SwiftData models are reference types — Codable on them is a footgun |
| Manual migration code for additive deltas | `MigrationStage.lightweight(fromVersion:toVersion:)` | iOS 17 | Zero custom code for adds/renames/deletes of entities or default-valued fields |

**Deprecated/outdated:**
- Foreground `Timer.publish` for rest-like countdowns — replace with `Date`-based + `UNUserNotificationCenter`.
- `Combine.debounce` for search input — `.task(id:)` is the SwiftUI-native replacement (already established in Phase 1's `ExerciseLibraryView`).
- `NSPredicate` strings — `#Predicate` macro is the typed iOS 17+ replacement.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Apple's lightweight migration handles adding new entity types without custom code | Pattern 4 + Standard Stack | If wrong, SchemaV2 needs `MigrationStage.custom` — adds ~50 LOC + a migration test, but the deltas remain identical. Low risk because adding new entities is explicitly enumerated in Apple's docs as eligible for lightweight migration. [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight] |
| A2 | `UNNotificationRequest.add` with duplicate identifier atomically replaces the prior request | Pattern 2 + Pitfall 4 | If wrong, ±15s reschedules would either pile up or drop the alert during the race window. Mitigation: manual test with multiple ±15s presses. Confirmed by 3 independent sources but not directly from Apple's primary doc. [VERIFIED via useyourloaf.com + hackingwithswift.com] |
| A3 | `UNTimeIntervalNotificationTrigger` non-repeating supports `timeInterval < 60` | Pattern 2 + Standard Stack | If wrong, warm-up rests (e.g. 30s) wouldn't schedule a lock-screen alert. Workaround: only schedule for `seconds >= 60` and accept that very short rests lack lock-screen alerts. [VERIFIED via Apple docs / hackingwithswift.com — 60s minimum is documented as applying to repeating triggers only] |
| A4 | ActivityKit `Activity.request` is callable on iOS 18 simulator with `Activities → Settings → Live Activities` enabled in the simulator | Pattern 3 | If wrong, the Live Activity will only work on physical devices. Mitigation: the in-app overlay still works; manual on-device test required. Simulator-side ActivityKit support has historically been spotty; defensive `do/catch` in `startLiveActivity` is required either way. |
| A5 | The Phase 1 `ExerciseLibraryView` init-overload refactor is safe (no existing callers break) | Pattern 5 | If wrong, all Phase 1 tests + previews would need updates. Mitigation: verified by direct file inspection — `init()` and `init(path:)` exist; adding a third `init(onSelect:)` is purely additive. [VERIFIED: codebase] |
| A6 | `Session.completedAt == nil` is the correct active-session predicate | Pattern 4 + Example 6 | If wrong, the resume banner / start-conflict guard would never fire. Phase 1 schema docs and existing entity comments confirm `completedAt: Date?` defaults to nil, gets set on session finish. [VERIFIED: codebase `fitbod/Models/Session.swift`] |
| A7 | iOS 18.0 deployment target is sufficient for all referenced APIs | Standard Stack | If wrong, would need to bump deployment target. Mitigation: all referenced APIs target iOS 16.1 or earlier, well below the 18.0 floor. [VERIFIED: each Apple doc page shows availability] |
| A8 | "+Folder" UI in Routines tab can be a sheet (per UI-SPEC), not a separate route | Recommended Project Structure | Low risk — UI-SPEC explicitly defines `NewFolderSheet` as `.sheet`-presented. [VERIFIED: UI-SPEC] |

**Confidence note:** Every claim above has been cross-referenced against at least one Apple documentation page or verified codebase fact. The "ASSUMED" tag means "not directly confirmed by a single authoritative test in this research session" — most are well-established community knowledge (web-search-verified) but a planner / discuss-phase reviewer should sanity-check them before locking the plan.

## Open Questions

1. **Live Activity simulator availability on Xcode 26 / iOS 18 simulator** — Apple has expanded simulator support for ActivityKit over the past two years, but historically the lock-screen card and Dynamic Island do not fully render in the simulator. The pattern is robust to this (silent fallback to in-app overlay only), but full visual verification of the Dynamic Island / lock-screen card requires a physical iPhone 14 Pro or later.
   - What we know: `try Activity.request(...)` may succeed but produce no visible UI on older simulators.
   - What's unclear: whether iOS 18 simulator on Xcode 26 fully renders the Dynamic Island.
   - Recommendation: structure Phase 2 plans so the in-app overlay is testable in CI; visual verification of lock-screen + Dynamic Island is a manual-on-device task in `VERIFICATION.md`.

2. **`completedAt: Date?` vs `endedAt: Date?` naming inconsistency** — CONTEXT.md uses `endedAt`; the Phase 1 entity uses `completedAt`. UI-SPEC also uses `completedAt`.
   - What we know: Phase 1 entity field is `completedAt`.
   - What's unclear: whether to add an `endedAt` alias or just stick with `completedAt`.
   - Recommendation: keep the existing `completedAt` field name; treat the CONTEXT.md `endedAt` references as wording variance. The planner should propagate `completedAt` consistently in all Phase 2 plans.

3. **Sentinel for "planned but not yet logged" SetEntry rows** — `SessionFactory.start` pre-populates planned `SetEntry` rows. How does the UI distinguish "planned, not logged yet" from "logged with zero reps" (a user might genuinely log 0 reps)?
   - What we know: `SetEntry.completedAt: Date` defaults to `Date.now`; the entity has no `isComplete: Bool` flag in Phase 1 schema.
   - What's unclear: whether to add `isComplete: Bool = false` as a SchemaV2 additive field, or to use `completedAt == .distantPast` as the sentinel.
   - Recommendation: use `completedAt == .distantPast` as the sentinel (Phase 2 `SessionFactory.start` sets it explicitly). This avoids a new schema field. Alternatively, the planner may choose to add `isComplete: Bool = false` if the sentinel is unappealing — both work. Document the choice in the plan.

4. **First-launch notification permission UX** — the user's natural moment to grant permissions is right after they tap "Start Workout" for the first time, but iOS interrupts with a system modal that may be jarring. Should the app surface a pre-prompt explainer first ("We'd like to alert you on the lock screen when your rest timer completes. Tap allow on the next prompt.")?
   - What we know: Apple's UX guidance is that custom pre-prompts are allowed and often improve grant rates.
   - What's unclear: whether the user wants the pre-prompt vs going straight to system modal.
   - Recommendation: ship without the pre-prompt in Phase 2 (CONTEXT.md prioritises "minimize permission prompt friction"); revisit if grant rates are low.

## Environment Availability

> All Phase 2 dependencies are Apple-first-party or already in the project. Audit:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| SwiftUI | All UI surfaces | ✓ | iOS 26.4 SDK | — |
| SwiftData | Schema + persistence | ✓ | iOS 26.4 SDK | — |
| ActivityKit | RestTimerLiveActivity | ✓ | iOS 16.1+ (we target 18.0) | In-app overlay only (silent fallback) |
| UserNotifications | UNUserNotificationCenter | ✓ | iOS 10+ | In-app overlay only; banner if denied |
| WidgetKit | FitbodWidgets target | ✓ | iOS 14+ | — |
| Swift Testing | Unit tests | ✓ | Xcode 26 | — |
| Xcode 26 + Command Line Tools | Build | ⚠ partial | Command Line Tools only on this machine; full Xcode required for `xcodebuild test` | Use `xcrun swiftc -parse` for sanity-check (established Phase 1 pattern) |
| Physical iPhone (14 Pro or later) | Visual verification of Dynamic Island | ⚠ unknown | — | Simulator on-device test for in-app overlay; visual Dynamic Island verification deferred to manual on-device check |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** Physical iPhone for Dynamic Island visual test — fallback is "manual on-device verification step in VERIFICATION.md."

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 26 bundled) + XCTest for UI tests |
| Config file | (none — Swift Testing is discovery-based; `fitbodTests/` target inherits from Phase 1) |
| Quick run command | `xcrun swiftc -parse fitbod/**/*.swift fitbodTests/**/*.swift` (parse-only; established Phase 1 fallback) |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests` (requires full Xcode on the build machine) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| ROUTINE-01 | Single-screen builder with inline search and drag-reorder | UI | `xcodebuild test ... -only-testing:fitbodUITests/RoutineBuilderUITests` | ❌ Wave 3 |
| ROUTINE-02 | Per-exercise prescription as first-class data | Unit | `swift test --filter RoutineExerciseFields` | ❌ Wave 3 |
| ROUTINE-03 | Per-set prescription overrides persist | Unit | `swift test --filter RoutineExerciseSetOverrideTests` | ❌ Wave 0 (alongside SchemaV2) |
| ROUTINE-04 | Superset grouping persists + cloned on duplicate | Unit | `swift test --filter SupersetGroupTests` + `RoutineDuplicationTests` | ❌ Wave 3 |
| ROUTINE-05 | Per-exercise progression kind selector | Unit | (covered by `RoutineExerciseFields` — `progressionKindRaw`) | ❌ Wave 3 |
| ROUTINE-06 | Duplicate + folder grouping | Unit | `swift test --filter RoutineDuplicationTests` + `RoutineFolderTests` | ❌ Wave 3 |
| ROUTINE-07 | Snapshot semantics — editing routine doesn't mutate session | Unit | `swift test --filter SessionFactoryTests/editingRoutineAfterSessionStartLeavesSnapshotIntact` | ❌ Wave 1 |
| ROUTINE-08 | Same-routine-different-intent maintains separate histories | Unit | `swift test --filter ExerciseHistoryIntentSplitTests` | ❌ Wave 5 |
| ROUTINE-09 | Default rest by mechanic heuristic | Unit | `swift test --filter PrescriptionDefaultsTests` | ❌ Wave 3 |
| SESS-01 | SessionFactory.start snapshots all fields | Unit | `swift test --filter SessionFactoryTests/snapshotsAllPrescriptionFields` | ❌ Wave 1 |
| SESS-02 | Per-set logging | UI | `xcodebuild test ... -only-testing:fitbodUITests/SessionLoggerUITests/logSetWithRPE` | ❌ Wave 4 |
| SESS-03 | Previous column shows matching-intent prior set | Unit | `swift test --filter PreviousSetQueryTests` | ❌ Wave 4 |
| SESS-04 | Rest timer accuracy + lock-screen alert + Live Activity | Unit + manual | `swift test --filter RestTimerEngineTests` + manual lock-screen verification | ❌ Wave 2 |
| SESS-05 | Mid-session swap preserves template | Unit | `swift test --filter MidSessionSwapTests` | ❌ Wave 4 |
| SESS-06 | Add unplanned exercise mid-session | Unit | `swift test --filter AddUnplannedExerciseTests` | ❌ Wave 4 |
| SESS-07 | Optional tempo per set | Unit | (covered by `SetEntryFields` — `tempoActual`) | ❌ Wave 4 |
| SESS-08 | Partial reps + cluster sub-reps | Unit | `swift test --filter PartialAndClusterRepsTests` | ❌ Wave 0 (alongside SchemaV2 fields) |
| SESS-09 | Bodyweight signed weight | Unit | `swift test --filter SignedWeightTests` | ❌ Wave 4 |
| SESS-10 | Per-exercise intent-split history list | Unit | `swift test --filter ExerciseHistoryIntentSplitTests` | ❌ Wave 5 |
| SESS-11 | Workout notes + pinned per-exercise notes | UI | `xcodebuild test ... -only-testing:fitbodUITests/SessionLoggerUITests/notes` | ❌ Wave 4 |

### Sampling Rate
- **Per task commit:** `xcrun swiftc -parse <changed files>` — establishes parse-cleanness; matches the Phase 1 established fallback. Runs in <2s.
- **Per wave merge:** `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` on the user's machine (orchestrator can't run xcodebuild). Runs in <60s for the full suite at Phase 2 scale.
- **Phase gate:** Full suite green + manual on-device rest-timer test (lock screen + 3min wait + alert fires) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `fitbod/Persistence/SchemaV2.swift` — NEW VersionedSchema declaration
- [ ] `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — modify to add V1→V2 lightweight stage
- [ ] `fitbod/Models/RoutineFolder.swift` — NEW @Model
- [ ] `fitbod/Models/SupersetGroup.swift` — NEW @Model
- [ ] `fitbod/Models/RoutineExerciseSetOverride.swift` — NEW @Model
- [ ] `fitbod/Models/Routine.swift` — MODIFY: add `folderID: UUID? = nil`
- [ ] `fitbod/Models/RoutineExercise.swift` — MODIFY: add `supersetGroupID: UUID?`, `tracksTempo: Bool = false`, `tracksPartialReps: Bool = false`, `setOverrides: [RoutineExerciseSetOverride]?` relationship with cascade
- [ ] `fitbod/Models/SessionExercise.swift` — MODIFY: add `pinnedNote: String?`
- [ ] `fitbod/Models/SetEntry.swift` — MODIFY: add `partialReps: Int?`, `clusterSubRepsJoined: String?`
- [ ] `fitbod/fitbodApp.swift` — MODIFY: change `Schema(SchemaV1.models)` → `Schema(SchemaV2.models)`
- [ ] `fitbodTests/SchemaV2MigrationTests.swift` — NEW: verify SchemaV1 store opens cleanly under SchemaV2 migration (lightweight migration smoke test)

## Security Domain

> `security_enforcement` is not explicitly disabled in `.planning/config.json` — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Single-user, local-only app — no authentication surface. (PROJECT.md explicitly excludes accounts/auth.) |
| V3 Session Management | no | "Session" in this project means "workout session," not auth session. No session tokens, no cookies, no server. |
| V4 Access Control | no | Single user; no multi-tenant model. |
| V5 Input Validation | yes | Numeric input on weight/reps/RPE: must validate non-NaN, non-negative-where-applicable. SwiftData enforces types at the schema layer. UI uses typed `TextField`s with formatters; SwiftUI clamps out-of-range numeric input. |
| V6 Cryptography | no | No cryptographic operations. No secrets. No PII (single user, local-only). |

### Known Threat Patterns for SwiftUI/SwiftData iOS app

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQLite injection via `#Predicate` | Tampering | SwiftData's `#Predicate` macro compiles Swift to type-safe SQLite — no user-controlled string interpolation. [VERIFIED via Apple docs] |
| Notification spoofing / replay | Tampering | Local-only notifications; UNUserNotificationCenter is sandboxed per-app. No remote push in Phase 2. |
| Live Activity content tampering | Tampering | `ActivityKit` content is generated by the app itself; no external input. Static `ActivityAttributes` + `ContentState` both fully controlled. |
| Data loss via crash mid-`SessionFactory.start` | DoS | Wrap the deep-copy in a single `try context.save()`. On failure, no partial state persists. UI-SPEC § Error states surfaces "Couldn't Start Workout" alert. |
| Schema migration data loss | DoS | Lightweight migration is non-destructive. `SchemaV2MigrationTests` verifies V1 store opens cleanly under V2 migration. |
| Background-mode foothold | Elevation of Privilege | No background-mode capability enabled (rest timer uses local notifications + Live Activity, both sandboxed). |

## Sources

### Primary (HIGH confidence)
- [SwiftData — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata) — VersionedSchema, MigrationStage, #Predicate, @Model, @Relationship, #Index patterns
- [ActivityKit — Apple Developer Documentation](https://developer.apple.com/documentation/activitykit) — Activity.request / update / end lifecycle, ActivityAuthorizationInfo, ContentState
- [Displaying live data with Live Activities — Apple](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) — ActivityAttributes + ActivityConfiguration + DynamicIsland template
- [MigrationStage.lightweight — Apple](https://developer.apple.com/documentation/swiftdata/migrationstage/lightweight(fromversion:toversion:)) — additive lightweight migration syntax
- [UNTimeIntervalNotificationTrigger — Apple](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger) — local notification trigger reference
- [UNUserNotificationCenter — Apple](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) — schedule / cancel / authorization patterns
- [NSSupportsLiveActivities — Apple](https://developer.apple.com/documentation/bundleresources/information-property-list/nssupportsliveactivities) — Info.plist key reference
- [TimelineView — Apple](https://developer.apple.com/documentation/swiftui/timelineview) — periodic re-render for timer countdowns
- Codebase: `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/*.swift` — all 12 Phase 1 entities + 11 enums verified by direct file inspection
- Codebase: `/Users/chrissaechao/Desktop/fitbod/fitbod/Persistence/SchemaV1.swift` + `FitbodSchemaMigrationPlan.swift` — migration scaffold confirmed empty + ready for V1→V2
- Codebase: `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/ExerciseLibraryView.swift` — init-overload pattern confirmed (`init()` + `init(path:)`)
- Codebase: `/Users/chrissaechao/Desktop/fitbod/fitbod/App/RootView.swift` — TabView + placeholder tabs confirmed

### Secondary (MEDIUM confidence)
- [SwiftUI List onMove — sarunw.com](https://sarunw.com/posts/swiftui-list-onmove/) — `.onMove` + `EditMode.active` always-visible handle pattern
- [Local Notifications with iOS 10 — useyourloaf.com](https://useyourloaf.com/blog/local-notifications-with-ios-10/) — replace-by-identifier confirmation
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — VersionedSchema chaining pattern (content access blocked but title link)
- [A Deep Dive into SwiftData migrations — Donny Wals](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/) — migration plan + lightweight stage example
- [SwiftData: Solving Filtering by an Entity in the Predicate — simplykyra.com](https://www.simplykyra.com/blog/swiftdata-problems-with-filtering-by-entity-in-the-predicate/) — `#Predicate` UUID workaround
- [iOS Live Activities: ActivityKit, Dynamic Island & Lock Screen Guide — newly.app](https://newly.app/articles/ios-live-activities) — 2026 ActivityKit guide
- [Live Activities in iOS: A SwiftUI Starter Guide — Rutwij on Medium](https://medium.com/@dev.rutwijb/live-activities-in-ios-a-swiftui-starter-guide-for-dynamic-island-c6889bf978c2) — DynamicIsland regions example

### Tertiary (LOW confidence — flagged for validation)
- [iOS 18 Live Activity With Intents — GitHub Gist](https://gist.github.com/RndmCodeGuy20/4b3042ce2092b69c9adc7feac16a2b54) — example only; verify against Apple docs
- [Mastering Live Activities in iOS — gauravharkhani01 on Medium](https://medium.com/@gauravharkhani01/mastering-live-activities-in-ios-the-complete-developers-guide-5357eb35d520) — broad overview; cross-verify specific APIs against Apple docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every framework is first-party Apple, verified via Apple docs + cross-referenced with code in Phase 1 codebase
- Architecture: HIGH — patterns derived from `ARCHITECTURE.md`'s established design; SessionFactory.start example composes Phase 1 entities verbatim
- Pitfalls: HIGH — all 10 pitfalls have a documented mitigation tied to an Apple-prescribed approach
- SchemaV2 migration: HIGH — additive deltas are explicitly eligible for `MigrationStage.lightweight` per Apple's documentation
- ActivityKit Live Activity: HIGH on API shape (Apple docs verified) / MEDIUM on simulator availability (acknowledged Open Question)
- Rest timer accuracy: HIGH — `Date` + `UNTimeIntervalNotificationTrigger` is the documented pattern; same-identifier replace is confirmed

**Research date:** 2026-05-11
**Valid until:** 2026-06-10 (30 days — stable Apple APIs, no fast-moving ecosystem dependencies)

---

*Phase 2 research synthesized: 2026-05-11*
*Generated for autonomous mode — all decisions resolved inline against verified Apple documentation and direct Phase 1 codebase inspection.*
