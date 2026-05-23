---
phase: 06
plan: 08
slug: progress-tab-home
status: complete
completed: 2026-05-23
wave: 5
type: execute
requirements: ["PROG-01", "PROG-04", "PROG-05", "PROG-07"]
depends_on: ["06-05", "06-06", "06-07"]
tech_stack:
  added: []
  patterns:
    - "Tab-owned NavigationStack via @Binding NavigationPath (matches LibraryTabHost pattern)"
    - "Route enums (Hashable, Sendable) using UUID keys instead of @Model classes for clean Hashable conformance"
    - "List.insetGrouped with section-per-purpose layout (Recent / Trends / Compare)"
    - ".placeholderPRsDestination() View extension attaches the 06-07 PR row tap stub"
key_files:
  created:
    - fitbod/Progress/ProgressHomeView.swift
  modified:
    - fitbod/App/RootView.swift
decisions:
  - "Route enums use UUID (NOT Exercise / Session @Model classes). @Model classes conform to Hashable in iOS 18 but with identity semantics that can confuse NavigationStack path equality. UUID keys are value-typed and unambiguous; the destination handler re-fetches the @Model via the in-context @Query."
  - "ProgressHomeView's NavigationStack is parameterized on a @Binding path supplied from RootView (mirrors LibraryTabHost) so the tabSelection setter can clear it on tab re-tap. The internal NavigationStack(path: $path) is the per-tab owner per PROJECT.md 'never wrap TabView in a parent NavigationStack'."
  - "Recent section dedupes SessionExercise rows by exercise.id keeping the most-recent (Pitfall 1: optional-relationship sort doesn't traverse cleanly in @Query, so the sort runs in Swift post-fetch). Caps at top 10 per UI-SPEC."
  - "Tab icon adjudication #3 — `chart.line.uptrend.xyaxis` per UI-SPEC § Asset Contract. Replaces the Phase 1 placeholder `chart.xyaxis.line` (which has a 'data trending down' visual connotation)."
  - "Trends section is ALWAYS visible (not gated on empty state) — the row sub-labels surface 'Log a workout' / 'Browse PRs across {N} exercises' as their own micro-empty-states. Reduces section flicker."
  - "Compare section is anchored on the SINGLE most-recent completed Session — not 'sessions with a comparable prior'. The actual prior-matching happens inside SessionComparator during the SessionComparisonView render, so the home row pushes optimistically; the destination view shows its own 'no comparable session' empty state if no prior matches."
metrics:
  duration_minutes: ~6
  tasks_completed: 2
  files_created: 1
  files_modified: 1
  commits: 2
---

# Phase 6 Plan 06-08: ProgressHomeView + RootView Tab Wiring Summary

Wire the Progress tab — ProgressHomeView (the tab root) consumes all four Wave 2 views via `navigationDestination`, and RootView swaps in the real tab body. Locks PATTERNS adjudication #3 (`chart.line.uptrend.xyaxis`) at the tab icon level.

## Overview

This plan is the integration moment for Phase 6 — everything Wave 2/3/4 built only becomes user-visible after this wire-up. Tapping the Progress tab now lands on a single-column List with three sections (Recent / Trends / Compare); every Wave 2 destination is reachable from there with one tap.

The tab-bar icon is updated to `chart.line.uptrend.xyaxis` per the UI-SPEC asset contract — replacing the Phase 1 placeholder `chart.xyaxis.line` which had a faint "data trending down" connotation.

## Implementation

### Task 1 — `ProgressHomeView`

**`fitbod/Progress/ProgressHomeView.swift`** (291 lines)

**Route enums:**
- `public enum ExerciseProgressRoute: Hashable, Sendable { .progress(UUID); .prs(UUID) }`
- `public enum ProgressHomeRoute: Hashable, Sendable { .weeklyTonnage; .allPRs; .sessionComparison(UUID) }`

UUID keys (NOT @Model classes) — value-typed Hashable conformance is unambiguous and the destination handlers re-fetch the @Model via in-context @Query lookups.

**ProgressHomeView body:**
- `public struct ProgressHomeView: View` with `@Binding path: NavigationPath` + `@Query<SessionExercise>` (sorted by orderIndex) + `@Query<Session>(filter: #Predicate { $0.completedAt != nil }, sort: \.startedAt, order: .reverse)` + `@Query<Exercise>`.
- `NavigationStack(path: $path)` wraps `List` `.listStyle(.insetGrouped)` with three sections.
- `.navigationTitle("Progress")` verbatim.
- `.navigationDestination(for: ExerciseProgressRoute.self)` and `.navigationDestination(for: ProgressHomeRoute.self)` cover all Wave 2 surface destinations.
- `.placeholderPRsDestination()` View extension (from 06-07) attaches the PR row tap placeholder.

**Section 1 — "Recent":**
- `recentExercisesCondensed` computed property: filters SessionExercise rows whose parent session has a completedAt; sorts by session.startedAt desc (Swift post-fetch — Pitfall 1: @Query sort doesn't traverse optional relationships well); dedupes by exercise.id keeping first; caps at 10.
- Per-row: `NavigationLink(value: ExerciseProgressRoute.progress(ex.id))` with exercise.name (.body) + sub-label "{N} sessions · last logged {relative}" (.caption .secondaryLabel) using `.relative(presentation: .named)`.
- Empty state: "No history yet" / "Log a session to start seeing your progress." (UI-SPEC verbatim).

**Section 2 — "Trends":** (always visible)
- Row "Weekly Tonnage" + sub-label "{kg} kg this week" or fallback "Log a workout to see this week's tonnage." → `ProgressHomeRoute.weeklyTonnage`.
- Row "Personal Records" + sub-label "Browse PRs across {N} exercises" → `ProgressHomeRoute.allPRs`.

**Section 3 — "Compare":**
- Anchored on `completedSessions.first` (most-recent completed Session).
- Row "This week vs last week" + sub-label "Compare to a routine you've logged twice." → `ProgressHomeRoute.sessionComparison(session.id)`.
- Empty state when no completed sessions: "No comparable session yet" / "Log a routine twice to compare." (UI-SPEC verbatim).

### Task 2 — `RootView` edits

**`fitbod/App/RootView.swift`** (modified, +25 / -4 lines)
- New `@State private var progressPath = NavigationPath()` alongside `libraryPath`.
- `tabSelection` setter switch updated — `.progress` gets its own case `progressPath = NavigationPath()` for pop-to-root on tab re-tap; remaining `.today / .routines / .settings` stay no-op.
- `PlaceholderTabView(phaseNumber: 6)` replaced with `ProgressTabHost(path: $progressPath)` inside the `TabView`. Tab icon updated to `chart.line.uptrend.xyaxis` per UI-SPEC § Asset Contract + PATTERNS adjudication #3.
- New `private struct ProgressTabHost: View { @Binding var path: NavigationPath; var body: some View { ProgressHomeView(path: $path) } }` near `LibraryTabHost` — one-line wrapper symmetric with the other tab hosts.

### Verification

- `xcodebuild build` → **BUILD SUCCEEDED** after each task
- `xcodebuild test -only-testing:fitbodTests` → **630 test invocations PASS, 0 failures** across the full Phase 1–6 suite
- `grep -n 'PlaceholderTabView(phaseNumber: 6)' fitbod/App/RootView.swift` → no matches (placeholder removed)
- `grep -n 'chart.line.uptrend.xyaxis' fitbod/App/RootView.swift` → confirmed line 201
- `grep -n 'ProgressTabHost\|progressPath' fitbod/App/RootView.swift` → 4 occurrences (state decl, tab-selection setter, TabView entry, struct decl)

### Deviations from Plan

None. Plan executed exactly as written. Minor sub-label phrasing chosen at Claude's discretion ("Compare to a routine you've logged twice." / "Browse PRs across {N} exercises") since the plan's `"{matched-exercise-count} exercises matched"` would require running SessionComparator on the home view — too eager for v1; the destination view does the matching.

### Known Stubs

None. The placeholder PR row tap destination is documented in 06-07's SUMMARY (deferred to v2 when CompletedSessionView ships) and is wired here via the `.placeholderPRsDestination()` extension.

## Deferred Items

- **Tab pop-to-root on Progress tab re-tap with deep state:** Currently clears NavigationPath only. If future flows accumulate sheet/modal state, additional cleanup may need to attach to the same re-tap branch.
- **Trends sub-label real-time refresh:** The "Weekly Tonnage" sub-label is computed at view render time from `completedSessions`. It will re-compute on @Query invalidation but does not actively poll.

## Commit SHAs

- **`c334f57`** — `feat(06-08): ProgressHomeView — three sections + navigationDestinations`
- **`6ff7cc0`** — `feat(06-08): RootView Progress tab wiring — replaces PlaceholderTabView`

## Self-Check: PASSED

Files exist:
- FOUND: fitbod/Progress/ProgressHomeView.swift

Modified:
- FOUND: fitbod/App/RootView.swift (progressPath @State + tabSelection case + ProgressTabHost replacement)

Commits exist:
- FOUND: c334f57
- FOUND: 6ff7cc0

Tab wiring confirmed:
- FOUND: `chart.line.uptrend.xyaxis` in RootView.swift (line 201)
- FOUND: `ProgressTabHost(path: $progressPath)` in RootView.swift (line 199)
- FOUND: `ProgressHomeView(path: $path)` inside ProgressTabHost
- ABSENT: `PlaceholderTabView(phaseNumber: 6)` (placeholder removed)

Test suite:
- All 630 Phase 1–6 test invocations PASS (0 failures)
