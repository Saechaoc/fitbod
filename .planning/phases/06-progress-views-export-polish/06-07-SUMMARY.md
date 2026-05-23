---
phase: 06
plan: 07
slug: prs-comparison-and-banner
status: complete
completed: 2026-05-23
wave: 4
type: execute
requirements: ["PROG-05", "PROG-07", "PROG-08"]
depends_on: ["06-02", "06-04", "06-05"]
tech_stack:
  added: []
  patterns:
    - "@Observable session-scoped detector cache (InSessionPRState) — Pattern 3 view-root mount via .safeAreaInset(edge: .top)"
    - "SessionFactory.seedPRTable per-exercise loop (RESEARCH Pitfall 6 LOCKED v1 path) — bounded by routine.exercises.count ~6–12"
    - "Outer/inner @Query split for ExercisePRsView with Scope enum (.forExercise(UUID) / .allExercises)"
    - "Δ rendering with U+2212 minus sign (NOT hyphen) + accentColor/secondaryLabel/tertiaryLabel color rules"
    - "Placeholder destination type (PRsRouteDestination) — v1 lacks CompletedSessionView, documented as v2 follow-up"
key_files:
  created:
    - fitbod/Sessions/InSessionPRState.swift
    - fitbod/Sessions/InSessionPRBanner.swift
    - fitbod/Progress/ExercisePRsView.swift
    - fitbod/Progress/SessionComparisonView.swift
    - fitbodTests/Phase6/InSessionPRStateTests.swift
    - fitbodTests/Phase6/PRsAndComparisonCopyTests.swift
  modified:
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/Sessions/SessionLoggerView.swift
decisions:
  - "Banner mount via .safeAreaInset(edge: .top, spacing: 0) at the SessionLoggerView root — RESEARCH Pattern 3 LOCKED. Never inside scroll content (anti-pattern: layout shift on appear/disappear). The banner sits ABOVE the existing Phase 3 BumpBanner and Phase 4 toolbar without competing for vertical space."
  - "SessionFactory.seedPRTable per-exercise loop is the LOCKED v1 path (NOT a fallback). Realistic routines hold 6–12 SessionExercises = 6–12 single-keyed fetches at session start; this deliberately avoids the SwiftData macro risk of cross-relationship predicates like `entry.sessionExercise?.exercise?.id` inside a single FetchDescriptor."
  - "ExercisePRsView top-3 history (NOT just current best) computed via post-fetch sort over @Query<SetEntry> results. PRDetector.PRTable holds ONE PRRecord per slot (the current best); the view needs history for the user-visible 'top 3 per bucket' contract. Acceptable at v1 single-user scale per CONTEXT D-12 ('computed on-demand from SetEntry history; NOT denormalized')."
  - "Δ rendering uses U+2212 (true minus sign) instead of hyphen U+002D. Negative Δs render in Color(.secondaryLabel) NOT systemRed — UI-SPEC item 27 deliberately rejects red-as-bad framing because every set is a logged session."
  - "PR row tap → placeholder destination Text('Session of {date}'). v1 has no CompletedSessionView; PRsRouteDestination is a public Hashable type so 06-08 ProgressHomeView can attach the same .navigationDestination via the .placeholderPRsDestination() View extension."
  - "@Observable InSessionPRState marks the dismissTask field @ObservationIgnored — Task<Void, Never>? is not Observation-tracked storage and triggers a warning otherwise."
  - "wasManualOverride does NOT suppress PR detection (CONTEXT D-17). PRDetector.check is the gatekeeper and never reads that field; an honest higher-weight set is a real PR regardless of how the user entered the value."
metrics:
  duration_minutes: ~14
  tasks_completed: 4
  files_created: 6
  files_modified: 2
  commits: 4
---

# Phase 6 Plan 06-07: PRs + Comparison + In-Session Banner Summary

Ship the three PR/comparison surfaces in one plan: `ExercisePRsView` (PROG-05), `SessionComparisonView` (PROG-07), and `InSessionPRBanner` + `InSessionPRState` (PROG-08). Adds `SessionFactory.seedPRTable` and mounts the banner via `.safeAreaInset(edge: .top)` per RESEARCH Pattern 3.

## Overview

This plan concentrates all three downstream consumers of `PRDetector` (the PR list view + the in-session banner) and `SessionComparator` (the side-by-side comparison view) in one wave. The `SessionLoggerView` integration is the highest-risk touchpoint — the banner mount is via `.safeAreaInset(edge: .top, spacing: 0)` per RESEARCH Pattern 3 to prevent layout shift when the banner appears/disappears between sets.

The PR table is seeded ONCE at session start via `SessionFactory.seedPRTable(for:context:)` and held in `@Observable InSessionPRState` so every set commit triggers a single in-memory `PRDetector.check(set:against:)` call — no per-set SwiftData queries.

## Implementation

### Task 1 — InSessionPRState + InSessionPRBanner + SessionFactory.seedPRTable + SessionLoggerView mount

**`fitbod/Sessions/InSessionPRState.swift`** (105 lines)
- `public struct InSessionPRBannerContent: Sendable, Equatable` — kinds: [PRKind] (canonical PRKind.allCases order weight→reps→volume→e1RM), weight: Double, reps: Int
- `@Observable public final class InSessionPRState` with `prTable: PRTable` + `currentBanner: InSessionPRBannerContent?` + `@ObservationIgnored dismissTask: Task<Void, Never>?`
- `@MainActor observeSave(set:)` — runs `PRDetector.check(set:against:)`; on hits builds banner with PRKind.allCases-ordered chips + fires `UINotificationFeedbackGenerator(.success)` + schedules 5s dismiss Task (cancelled on next save / tap); on no-hits-but-prior-banner-present clears banner ("D-15 next save with no PRs replaces prior banner")
- `@MainActor dismiss()` — clears banner + cancels task

**`fitbod/Sessions/InSessionPRBanner.swift`** (115 lines)
- `public struct InSessionPRBanner: View` with `@Bindable state: InSessionPRState`
- Branches on `state.currentBanner`: nil → EmptyView; non-nil → capsule with chips separated by `Text(" · ")` middot in `.body` Color.accentColor + `.caption` sub-line "{weight} kg × {reps}" in `.secondaryLabel`
- 44pt min-height; `Color.accentColor.opacity(0.15)` fill; 1pt `Color.accentColor.opacity(0.3)` border via `RoundedRectangle(cornerRadius: 22)` overlay; UI-SPEC item 25 verbatim
- 16pt horizontal padding + 8pt vertical padding inside the capsule + 16pt outer horizontal padding
- `.onTapGesture { state.dismiss() }`
- `.accessibilityElement(children: .combine)` + label "{count} personal records: {labels joined}" + hint "Double-tap to dismiss" + `.isButton` trait (UI-SPEC item 621)
- `@Environment(\.accessibilityReduceMotion)` gates `.move(edge: .top).combined(with: .opacity)` → `.opacity` only when reduce-motion is on; `.smooth(duration: 0.18)` cap per D-35

**`fitbod/Sessions/SessionFactory.swift`** (extension appended, +44 lines)
```swift
@MainActor
public static func seedPRTable(for session: Session, context: ModelContext) async -> PRTable
```
- Per-exercise loop LOCKED per RESEARCH Pitfall 6 (bounded by routine.exercises.count ~6–12 single-keyed fetches)
- Each iteration: local-let `targetID` capture before #Predicate per Pitfall 3; descriptor predicate `entry.isComplete && !entry.isWarmup && entry.sessionExercise?.exercise?.id == targetID` sorted by completedAt; aggregates results
- Final call: `PRDetector.buildTable(from: aggregated)`

**`fitbod/Sessions/SessionLoggerView.swift`** (modified, +14 lines)
- New `@State private var prState = InSessionPRState()`
- `.safeAreaInset(edge: .top, spacing: 0) { InSessionPRBanner(state: prState) }` modifier on body root (sits OUTSIDE the existing alerts/sheets)
- `.task { prState.prTable = await SessionFactory.seedPRTable(for: session, context: ctx) }` for session-start seeding
- `commitSet(...)` adds `prState.observeSave(set: entry)` AFTER `ctx.save()` (so the committed state is what PRDetector reads)

### Task 2 — ExercisePRsView (4 sections × 3 buckets + intent picker)

**`fitbod/Progress/ExercisePRsView.swift`** (315 lines)
- `public enum ExercisePRsViewScope: Hashable, Sendable { .forExercise(UUID); .allExercises }` — uses UUID (not Exercise) for Hashable
- `public enum ExercisePRsIntentFilter: String, CaseIterable, Sendable { strength; hypertrophy; all }` with `.label` ("Strength" / "Hypertrophy" / "All") + `.matches(intent:)` predicate
- `public struct ExercisePRsView: View` — outer view owns `@State intentFilter: ExercisePRsIntentFilter = .all` + scope param. Header is `.pickerStyle(.segmented)` over IntentFilter cases. Nav title "Personal Records" (UI-SPEC verbatim).
- `private struct PRsHost: View` — inner view holds `@Query<SetEntry>` predicate-narrowed to scope. `.forExercise(id)` filters on `entry.sessionExercise?.exercise?.id == targetID` (local-let UUID capture). `.allExercises` filters only on isComplete && !isWarmup. Intent filter applied via Swift post-filter on `entry.sessionExercise?.session?.intentRaw` (Pitfall 1 — multi-level optional chain forbidden inside #Predicate).
- 4 `Section` blocks (Weight / Reps / Volume / e1RM). Each renders rep buckets via `bucketBlock(kind:bucket:sets:)`. e1RM section omits `.highRep` (PROG-02 / D-04 suppression) and appends "Suppressed for reps above 10." caption (UI-SPEC verbatim).
- Each bucket lists top 3 PRs via post-fetch sort by the kind's PR criterion (weight desc / reps desc / weight×reps desc / OneRepMax desc).
- Row format per UI-SPEC verbatim:
  - Weight: `{weight} kg × {reps} @ RPE {rpe}`
  - Reps: `{reps} reps @ {weight} kg, RPE {rpe}`
  - Volume: `{tonnage} kg single-set ({weight} × {reps})`
  - e1RM: `{e1rm} kg e1RM ({weight} × {reps})`
- Row chevron `chevron.right` in `Color.accentColor`; trailing date in `.caption .secondaryLabel`
- Bucket labels use EN-dash `–` (UI-SPEC verbatim, NOT hyphen)
- Empty state: "No PRs yet" / "Complete a working set to set your first record." (UI-SPEC verbatim)
- `public enum PRsRouteDestination: Hashable, Sendable { .session(date:setEntryID:) }` — placeholder destination
- `public extension View { func placeholderPRsDestination() -> some View }` — wires `.navigationDestination(for: PRsRouteDestination.self)` → `Text("Session of {date}")` stub

### Task 3 — SessionComparisonView (3-column diff)

**`fitbod/Progress/SessionComparisonView.swift`** (261 lines)
- `public struct SessionComparisonView: View` with `let anchorSession: Session` + `@Environment(\.modelContext) private var ctx` + `@State private var rows: [SessionComparisonRow] = []` + `@State didLoad: Bool`
- `.task { rows = SessionComparator.compare(current: anchorSession, context: ctx); didLoad = true }` populates rows on appear
- Column-header row above the List: anchor date | "Δ" | first-prior date (or "—" when no prior). All `.caption .secondaryLabel`.
- Per-row body branches:
  - Both top sets present → exercise name (.caption .secondaryLabel) above a 3-column HStack with weight cells (~35% each) + central Δ stack showing weight Δ + reps Δ + e1RM Δ
  - `lastWeekTopSet == nil` → single-cell "{exercise name} — no prior data" (.body .secondaryLabel)
- Δ rendering rules (UI-SPEC item 27):
  - positive Δ → `+{abs} {unit}` Color.accentColor .headline
  - negative Δ → `−{abs} {unit}` Color(.secondaryLabel) .headline using **U+2212** (NOT hyphen U+002D)
  - zero Δ → "—" em-dash Color(.tertiaryLabel) .headline
  - nil → same em-dash treatment
- Per-side weight cells: `{weight} kg × {reps}` `.body` + optional `e1RM {N} kg` `.caption .secondaryLabel`
- Empty state: "No comparable session" / "Log this routine again next week to compare." (UI-SPEC verbatim)
- Nav title: "This week vs last week" (UI-SPEC verbatim)

### Task 4 — Tests

**`fitbodTests/Phase6/InSessionPRStateTests.swift`** (115 lines, 3 @Test funcs, `.serialized`)
- `emptyOnInit` — fresh state has nil banner + empty prTable
- `multiPRCanonicalOrder` — first 110×5 working set seeds banner.kinds in canonical PRKind.allCases order `[.weight, .reps, .volume, .e1RM]`; banner.weight == 110, banner.reps == 5
- `nextSaveNoPRClearsBanner` — D-15: first 110×5 save populates banner; second 80×5 save (strictly worse on every PR criterion) clears the prior banner

Each test acquires fresh in-memory SchemaV6 ModelContainer via `InMemoryContainer.makeCurrent()` so the `SetEntry → SessionExercise → Session → Exercise` relationship chain resolves inside `PRDetector.check`.

**`fitbodTests/Phase6/PRsAndComparisonCopyTests.swift`** (75 lines, 1 @Test)
- `verbatimCopy` reads three source files via `#filePath` ascent and `#expect(source.contains(...))` for every UI-SPEC verbatim string (see commit message for the full inventory)

### Verification

- `xcodebuild build` → **BUILD SUCCEEDED** after each task
- `xcodebuild test -only-testing:fitbodTests/InSessionPRStateTests` → 3/3 @Test **PASS**
- `xcodebuild test -only-testing:fitbodTests/PRsAndComparisonCopyTests` → 1/1 @Test **PASS**

### Deviations from Plan

**1. [Rule 1 - @Observable warning] `dismissTask` marked `@ObservationIgnored`**
- **Found during:** Task 1 InSessionPRState definition
- **Issue:** `Task<Void, Never>?` storage inside `@Observable` class without `@ObservationIgnored` triggers a Swift warning about non-Observation-tracked storage.
- **Fix:** Added `@ObservationIgnored` attribute to the `dismissTask` property declaration.
- **Files modified:** fitbod/Sessions/InSessionPRState.swift
- **Commit:** ab5c53e

**2. [Rule 1 - SessionLoggerView empty-string fallback] `Text("Session of {date}")` placeholder destination**
- **Found during:** Task 2 ExercisePRsView row tap wiring
- **Issue:** Plan called for "NavigationLink to a placeholder destination" but did not document where the placeholder lives. PRsRouteDestination must be referenced by both ExercisePRsView (06-07) and ProgressHomeView (06-08) without circular dependencies.
- **Fix:** Declared `public enum PRsRouteDestination` + `public extension View { func placeholderPRsDestination() }` at file scope in ExercisePRsView.swift so 06-08 ProgressHomeView can attach the same destination via the View extension.
- **Files modified:** fitbod/Progress/ExercisePRsView.swift
- **Commit:** e856add

### Known Stubs

**`PRsRouteDestination` placeholder destination** — `Text("Session of {date}")` stub stands in for the not-yet-implemented `CompletedSessionView`. The plan explicitly documents this as a v2 follow-up entry point (CONTEXT D-24 → "Compare to last week" entry from the completed-session screen) — there is no completed-session screen in v1, so D-24 is partially deferred. The Progress-tab "This week vs last week" home card (06-08) is the v1 entry point.

## Deferred Items

- **Open Question 2 — `SessionExercise.exerciseSnapshotName: String?`:** Deferred. v1 emits empty-string for nil-exercise rows per 06-09's convention. PR rows render exercise name via `session.exercise?.name ?? ""`.
- **CONTEXT D-24 — Completed-session-screen entry point:** Deferred. v1 has no completed-session screen (SessionLoggerView dismisses on Finish, no post-session summary). The Progress-tab "This week vs last week" home card in 06-08 is the v1 entry point.
- **PRsRouteDestination → real session detail:** Placeholder text destination. Real session-detail navigation deferred to v2 when CompletedSessionView ships.

## Commit SHAs

- **`ab5c53e`** — `feat(06-07): InSessionPRState + InSessionPRBanner + .safeAreaInset mount`
- **`e856add`** — `feat(06-07): ExercisePRsView — 4 sections × 3 buckets + intent picker`
- **`bbf66bd`** — `feat(06-07): SessionComparisonView — 3-column per-exercise Δ diff`
- **`24bb43f`** — `test(06-07): InSessionPRStateTests + PRsAndComparisonCopyTests`

## Self-Check: PASSED

Files exist:
- FOUND: fitbod/Sessions/InSessionPRState.swift
- FOUND: fitbod/Sessions/InSessionPRBanner.swift
- FOUND: fitbod/Progress/ExercisePRsView.swift
- FOUND: fitbod/Progress/SessionComparisonView.swift
- FOUND: fitbodTests/Phase6/InSessionPRStateTests.swift
- FOUND: fitbodTests/Phase6/PRsAndComparisonCopyTests.swift

Modified:
- FOUND: fitbod/Sessions/SessionFactory.swift (seedPRTable extension)
- FOUND: fitbod/Sessions/SessionLoggerView.swift (.safeAreaInset mount + .task + observeSave wire)

Commits exist:
- FOUND: ab5c53e
- FOUND: e856add
- FOUND: bbf66bd
- FOUND: 24bb43f

.safeAreaInset mount confirmed:
- FOUND: `.safeAreaInset(edge: .top, spacing: 0)` in fitbod/Sessions/SessionLoggerView.swift
- FOUND: `seedPRTable` extension in fitbod/Sessions/SessionFactory.swift
